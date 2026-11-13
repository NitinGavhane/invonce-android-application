// POST /connect-onboard  (called from the app, as the signed-in user)
//   Stripe:   { }                              → { provider:'stripe', url }   (open in browser, then call again with { check:true })
//   Razorpay: { razorpay: RazorpayOnboarding } → { provider:'razorpay', accountId, status }
//   Any:      { check: true }                  → { provider, enabled, status }
import { adminClient, cors, json, providerFor, userClient } from "../_shared/env.ts";
import { createLinkedAccount, linkedAccountStatus, RazorpayOnboarding } from "../_shared/razorpay.ts";
import { accountEnabled, createExpressOnboarding } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const user = userClient(req);
    const { data: auth } = await user.auth.getUser();
    if (!auth?.user) return json({ error: "not signed in" }, 401);

    const admin = adminClient();
    const { data: biz, error } = await admin.from("businesses").select("*").eq("owner_id", auth.user.id).single();
    if (error || !biz) return json({ error: "no business" }, 404);

    const body = await req.json().catch(() => ({}));
    const provider = biz.payment_provider ?? providerFor(biz.country ?? "US");

    // ── Status check ───────────────────────────────────────────────────────
    if (body.check) {
      if (!biz.payment_account_id) return json({ provider, enabled: false, status: "not_connected" });
      let enabled = false;
      let status = "pending";
      if (provider === "stripe") {
        enabled = await accountEnabled(biz.payment_account_id);
        status = enabled ? "active" : "onboarding";
      } else {
        status = await linkedAccountStatus(biz.payment_account_id);
        enabled = status === "activated";
      }
      await admin.rpc("set_payment_account", { p_business: biz.id, p_provider: provider, p_account_id: biz.payment_account_id, p_enabled: enabled });
      return json({ provider, enabled, status });
    }

    // ── Razorpay Route (India): KYC details come from the app's form ───────
    if (provider === "razorpay") {
      const o = body.razorpay as RazorpayOnboarding | undefined;
      if (!o) return json({ error: "razorpay onboarding details required" }, 400);
      const { accountId } = await createLinkedAccount(o);
      await admin.rpc("set_payment_account", { p_business: biz.id, p_provider: "razorpay", p_account_id: accountId, p_enabled: false });
      return json({ provider: "razorpay", accountId, status: "under_review" });
    }

    // ── Stripe Connect Express: hosted onboarding ──────────────────────────
    // Web app: come back to the page that started it. Mobile: CONNECT_RETURN_URL (your site or a deep link).
    const origin = req.headers.get("origin") ?? Deno.env.get("CONNECT_RETURN_URL") ?? "https://invonce.app";
    const { accountId, url } = await createExpressOnboarding({
      email: biz.email || auth.user.email!,
      country: biz.country ?? "US",
      businessName: biz.name || "Invonce business",
      returnUrl: `${origin}/?connect=return`,
      refreshUrl: `${origin}/?connect=refresh`,
      existingAccountId: biz.payment_account_id ?? undefined,
    });
    await admin.rpc("set_payment_account", { p_business: biz.id, p_provider: "stripe", p_account_id: accountId, p_enabled: false });
    return json({ provider: "stripe", url });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
