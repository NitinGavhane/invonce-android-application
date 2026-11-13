// POST /create-checkout  { token }   (public — the payer is not signed in)
//   Stripe   → { provider:'stripe', url }                       redirect to Stripe Checkout
//   Razorpay → { provider:'razorpay', orderId, keyId, amount, currency, name, description }  for Checkout.js
import { adminClient, cors, env, fromMinor, json, payBaseUrl, toMinor } from "../_shared/env.ts";
import { createOrder } from "../_shared/razorpay.ts";
import { createCheckout } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { token } = await req.json();
    if (!token) return json({ error: "token required" }, 400);

    const admin = adminClient();
    const { data: inv, error } = await admin.rpc("public_invoice", { p_token: token });
    if (error || !inv) return json({ error: "invoice not found" }, 404);
    if (!inv.business.payments_enabled) return json({ error: "This business has not enabled online payments yet." }, 409);
    if (inv.balance <= 0) return json({ error: "This invoice is already paid." }, 409);

    const { data: row } = await admin.from("invoices").select("id, business_id, number").eq("pay_token", token).single();
    const { data: biz } = await admin.from("businesses").select("payment_provider, payment_account_id, name").eq("id", row!.business_id).single();

    const currency = String(inv.currency).toUpperCase();
    const amountMinor = toMinor(Number(inv.balance), currency);
    const { data: feeMinor } = await admin.rpc("platform_fee_for", { p_business: row!.business_id, p_amount_minor: amountMinor });
    const platformFeeMinor = Number(feeMinor ?? 0);
    const description = `${inv.number} · ${biz!.name}`;

    if (biz!.payment_provider === "razorpay") {
      const order = await createOrder({
        amountMinor,
        currency,
        receipt: inv.number,
        notes: { pay_token: token, invoice: inv.number },
        linkedAccountId: biz!.payment_account_id!,
        platformFeeMinor,
      });
      await admin.rpc("begin_online_payment", {
        p_token: token, p_provider: "razorpay", p_provider_ref: order.id, p_amount: Number(inv.balance), p_currency: currency,
        p_platform_fee: fromMinor(platformFeeMinor, currency),
      });
      return json({ provider: "razorpay", orderId: order.id, keyId: env("RAZORPAY_KEY_ID"), amount: amountMinor, currency, name: biz!.name, description });
    }

    const base = payBaseUrl();
    const session = await createCheckout({
      amountMinor,
      currency,
      description,
      connectedAccountId: biz!.payment_account_id!,
      platformFeeMinor,
      payToken: token,
      successUrl: `${base}/${token}?paid=1`,
      cancelUrl: `${base}/${token}`,
    });
    await admin.rpc("begin_online_payment", {
      p_token: token, p_provider: "stripe", p_provider_ref: session.id, p_amount: Number(inv.balance), p_currency: currency,
      p_platform_fee: fromMinor(platformFeeMinor, currency),
    });
    return json({ provider: "stripe", url: session.url });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
