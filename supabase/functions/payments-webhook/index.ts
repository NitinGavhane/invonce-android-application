// POST /payments-webhook?provider=stripe | razorpay   (called by the gateways; no user auth)
// Verifies the signature, then applies the payment idempotently via apply_online_payment().
import { adminClient, fromMinor, json } from "../_shared/env.ts";
import { verifyWebhook } from "../_shared/razorpay.ts";
import { parseWebhook } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  const provider = new URL(req.url).searchParams.get("provider");
  const raw = await req.text();
  const admin = adminClient();

  try {
    if (provider === "stripe") {
      const event = await parseWebhook(raw, req.headers.get("stripe-signature"));
      if (event.type === "checkout.session.completed") {
        const s = event.data.object as {
          id: string; payment_intent: string | null; amount_total: number | null; currency: string | null;
          metadata: Record<string, string> | null; payment_status: string;
        };
        const token = s.metadata?.pay_token;
        if (token && s.payment_status === "paid" && s.amount_total != null) {
          const currency = (s.currency ?? "usd").toUpperCase();
          const { data: fee } = await admin.from("online_payments").select("platform_fee").eq("provider", "stripe").eq("provider_ref", s.id).maybeSingle();
          await admin.rpc("apply_online_payment", {
            p_token: token, p_provider: "stripe", p_provider_ref: s.id, p_payment_ref: s.payment_intent,
            p_amount: fromMinor(s.amount_total, currency), p_currency: currency,
            p_platform_fee: fee?.platform_fee ?? 0, p_processor_fee: null, p_raw: s,
          });
        }
      }
      return json({ received: true });
    }

    if (provider === "razorpay") {
      if (!(await verifyWebhook(raw, req.headers.get("x-razorpay-signature")))) return json({ error: "bad signature" }, 400);
      const event = JSON.parse(raw) as { event: string; payload: { payment?: { entity: Record<string, unknown> } } };
      if (event.event === "payment.captured") {
        const p = event.payload.payment!.entity as {
          id: string; order_id: string; amount: number; currency: string; fee?: number; notes?: Record<string, string>;
        };
        const token = p.notes?.pay_token;
        if (token) {
          const { data: fee } = await admin.from("online_payments").select("platform_fee").eq("provider", "razorpay").eq("provider_ref", p.order_id).maybeSingle();
          await admin.rpc("apply_online_payment", {
            p_token: token, p_provider: "razorpay", p_provider_ref: p.order_id, p_payment_ref: p.id,
            p_amount: fromMinor(p.amount, p.currency), p_currency: p.currency,
            p_platform_fee: fee?.platform_fee ?? 0, p_processor_fee: p.fee != null ? fromMinor(p.fee, p.currency) : null, p_raw: p,
          });
        }
      }
      return json({ received: true });
    }

    return json({ error: "unknown provider" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 400);
  }
});
