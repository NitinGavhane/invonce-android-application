// Minimal Razorpay REST client (Route = split payments for India).
import { env } from "./env.ts";

const base = "https://api.razorpay.com";

const auth = () => "Basic " + btoa(`${env("RAZORPAY_KEY_ID")}:${env("RAZORPAY_KEY_SECRET")}`);

export async function rz<T = Record<string, unknown>>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(base + path, {
    method,
    headers: { authorization: auth(), "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Razorpay ${method} ${path} → ${res.status}: ${JSON.stringify(data)}`);
  return data as T;
}

export interface RazorpayOnboarding {
  legalName: string;
  displayName: string;
  email: string;
  phone: string; // +91…
  businessType: "individual" | "proprietorship" | "partnership" | "private_limited" | "llp";
  pan: string;
  address: { street1: string; street2?: string; city: string; state: string; postalCode: string };
  bank: { accountNumber: string; ifsc: string; beneficiaryName: string };
}

/** Creates a Route linked account + stakeholder + settlement product. Returns the account id. */
export async function createLinkedAccount(o: RazorpayOnboarding): Promise<{ accountId: string; productId: string }> {
  const account = await rz<{ id: string }>("POST", "/v2/accounts", {
    email: o.email,
    phone: o.phone,
    type: "route",
    legal_business_name: o.legalName,
    business_type: o.businessType,
    customer_facing_business_name: o.displayName,
    profile: {
      category: "services",
      subcategory: "professional_services",
      addresses: {
        registered: {
          street1: o.address.street1,
          street2: o.address.street2 ?? o.address.street1,
          city: o.address.city,
          state: o.address.state,
          postal_code: o.address.postalCode,
          country: "IN",
        },
      },
    },
    legal_info: { pan: o.pan },
  });

  await rz("POST", `/v2/accounts/${account.id}/stakeholders`, {
    name: o.bank.beneficiaryName,
    email: o.email,
    kyc: { pan: o.pan },
  });

  const product = await rz<{ id: string }>("POST", `/v2/accounts/${account.id}/products`, {
    product_name: "route",
    tnc_accepted: true,
  });

  await rz("PATCH", `/v2/accounts/${account.id}/products/${product.id}`, {
    settlements: {
      account_number: o.bank.accountNumber,
      ifsc_code: o.bank.ifsc,
      beneficiary_name: o.bank.beneficiaryName,
    },
    tnc_accepted: true,
  });

  return { accountId: account.id, productId: product.id };
}

/** "activated" once Razorpay has verified KYC; "under_review" / "needs_clarification" meanwhile. */
export async function linkedAccountStatus(accountId: string): Promise<string> {
  const products = await rz<{ items: { product_name: string; activation_status: string }[] }>("GET", `/v2/accounts/${accountId}/products`);
  return products.items.find((p) => p.product_name === "route")?.activation_status ?? "unknown";
}

/** Order with a Route transfer: the business receives amount − fee; the fee stays on the platform account. */
export async function createOrder(args: {
  amountMinor: number;
  currency: string;
  receipt: string;
  notes: Record<string, string>;
  linkedAccountId: string;
  platformFeeMinor: number;
}) {
  return rz<{ id: string; amount: number; currency: string }>("POST", "/v1/orders", {
    amount: args.amountMinor,
    currency: args.currency,
    receipt: args.receipt,
    notes: args.notes,
    transfers: [
      {
        account: args.linkedAccountId,
        amount: args.amountMinor - args.platformFeeMinor,
        currency: args.currency,
        notes: args.notes,
        on_hold: false,
      },
    ],
  });
}

/** Webhook signature: HMAC-SHA256 of the raw body with the webhook secret. */
export async function verifyWebhook(rawBody: string, signature: string | null): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(env("RAZORPAY_WEBHOOK_SECRET")), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return hex === signature;
}
