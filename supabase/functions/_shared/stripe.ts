// Stripe Connect (Express) helpers.
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { env } from "./env.ts";

export const stripe = () =>
  new Stripe(env("STRIPE_SECRET_KEY"), { apiVersion: "2024-06-20", httpClient: Stripe.createFetchHttpClient() });

/** Express account + hosted onboarding link. */
export async function createExpressOnboarding(args: { email: string; country: string; businessName: string; returnUrl: string; refreshUrl: string; existingAccountId?: string }) {
  const s = stripe();
  const accountId =
    args.existingAccountId ??
    (
      await s.accounts.create({
        type: "express",
        country: args.country,
        email: args.email,
        business_profile: { name: args.businessName, product_description: "Invoicing" },
        capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
      })
    ).id;
  const link = await s.accountLinks.create({
    account: accountId,
    type: "account_onboarding",
    return_url: args.returnUrl,
    refresh_url: args.refreshUrl,
  });
  return { accountId, url: link.url };
}

export async function accountEnabled(accountId: string): Promise<boolean> {
  const a = await stripe().accounts.retrieve(accountId);
  return Boolean(a.charges_enabled && a.payouts_enabled);
}

/** Destination charge: money lands on the connected account, platform keeps the application fee. */
export async function createCheckout(args: {
  amountMinor: number;
  currency: string;
  description: string;
  connectedAccountId: string;
  platformFeeMinor: number;
  payToken: string;
  successUrl: string;
  cancelUrl: string;
  customerEmail?: string;
}) {
  return stripe().checkout.sessions.create({
    mode: "payment",
    line_items: [{ quantity: 1, price_data: { currency: args.currency.toLowerCase(), unit_amount: args.amountMinor, product_data: { name: args.description } } }],
    payment_intent_data: {
      application_fee_amount: args.platformFeeMinor,
      transfer_data: { destination: args.connectedAccountId },
      metadata: { pay_token: args.payToken },
    },
    metadata: { pay_token: args.payToken },
    customer_email: args.customerEmail,
    success_url: args.successUrl,
    cancel_url: args.cancelUrl,
  });
}

export async function parseWebhook(rawBody: string, signature: string | null) {
  if (!signature) throw new Error("missing stripe-signature");
  return stripe().webhooks.constructEventAsync(rawBody, signature, env("STRIPE_WEBHOOK_SECRET"), undefined, Stripe.createSubtleCryptoProvider());
}
