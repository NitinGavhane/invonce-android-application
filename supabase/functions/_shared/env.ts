// Shared helpers for the Invonce Edge Functions (Deno / TypeScript).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export const env = (name: string, fallback?: string): string => {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined) throw new Error(`Missing env ${name}`);
  return v;
};

/** Service-role client: bypasses RLS. Only ever used server-side. */
export const adminClient = () =>
  createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });

/** Client acting as the calling user (for functions invoked from the app). */
export const userClient = (req: Request) =>
  createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false },
  });

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...cors, ...headers } });

export const html = (body: string, status = 200) =>
  new Response(body, { status, headers: { "content-type": "text/html; charset=utf-8", ...cors } });

/** Minor-unit helper: 12.34 USD → 1234; INR same; JPY/KRW have 0 decimals. */
export const toMinor = (amount: number, currency: string) => {
  const zero = ["JPY", "KRW", "VND", "CLP"].includes(currency.toUpperCase());
  return Math.round(amount * (zero ? 1 : 100));
};
export const fromMinor = (minor: number, currency: string) => {
  const zero = ["JPY", "KRW", "VND", "CLP"].includes(currency.toUpperCase());
  return zero ? minor : minor / 100;
};

export const providerFor = (country: string) => (country.toUpperCase() === "IN" ? "razorpay" : "stripe");

/** Base URL of the public pay page (this project's invoice-page function). */
export const payBaseUrl = () => env("PAY_BASE_URL", `${env("SUPABASE_URL")}/functions/v1/invoice-page`);
