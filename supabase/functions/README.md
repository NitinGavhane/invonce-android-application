# Invonce Edge Functions — online payments

| Function | Who calls it | What it does |
|---|---|---|
| `connect-onboard` | the app (signed-in user) | Creates the business's **Stripe Express** account + onboarding link, or a **Razorpay Route** linked account from KYC details; `{check:true}` refreshes the enabled status |
| `invoice-page` | the client's browser (public) | The "view & pay" page at `…/invoice-page/<pay_token>`; logs a *viewed* read receipt |
| `create-checkout` | the pay page (public) | Starts Stripe Checkout (destination charge + application fee) or a Razorpay Order with a Route transfer |
| `payments-webhook` | Stripe / Razorpay | Verifies the signature and applies the payment (`apply_online_payment` → invoice paid, receipt event) |

Provider is chosen by `businesses.country`: **IN → Razorpay**, everything else → **Stripe**.
Platform fee: `businesses.platform_fee_bps` (default 100 = 1 %) on Free plans, **0 on Pro** (`platform_fee_for()`).

## 1. Database
Run `supabase/migrations/20261003000003_payments.sql` in the SQL editor (or `supabase db push`).

## 2. Secrets
```bash
supabase secrets set \
  STRIPE_SECRET_KEY=sk_live_or_test_… \
  STRIPE_WEBHOOK_SECRET=whsec_… \
  RAZORPAY_KEY_ID=rzp_live_or_test_… \
  RAZORPAY_KEY_SECRET=… \
  RAZORPAY_WEBHOOK_SECRET=… \
  PAY_BASE_URL=https://<project-ref>.supabase.co/functions/v1/invoice-page \
  CONNECT_RETURN_URL=https://invonce.app        # where Stripe sends mobile users after onboarding (optional)
```
`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.

## 3. Deploy
```bash
supabase functions deploy connect-onboard
supabase functions deploy create-checkout  --no-verify-jwt
supabase functions deploy invoice-page     --no-verify-jwt
supabase functions deploy payments-webhook --no-verify-jwt
```
(`--no-verify-jwt`: those three are reached by payers and gateways, not signed-in users.)

## 4. Gateway dashboards
- **Stripe** → Developers → Webhooks → endpoint `https://<ref>.supabase.co/functions/v1/payments-webhook?provider=stripe`,
  event `checkout.session.completed`. Enable **Connect** (Express) in Settings → Connect; set your platform name/branding.
- **Razorpay** → Settings → Webhooks → `…/payments-webhook?provider=razorpay`, event `payment.captured`, set the secret.
  Enable **Route** on the account (Razorpay enables it on request).

## 5. Test
Stripe test cards: `4242 4242 4242 4242`. Razorpay test mode: any UPI id / test cards from their docs.
Use `supabase functions serve` locally with a `.env` for quick iteration.

## Money flow
- Stripe: the client pays on Stripe Checkout → **destination charge** to the business's Express account → Stripe keeps its fee,
  Invonce keeps `application_fee_amount`, the business receives the rest and Stripe pays out to their bank.
- Razorpay: Order with a **Route transfer** → the business's linked account gets `amount − platform fee`, the fee stays on your
  Razorpay account, Razorpay settles both.
- Both: webhook → `apply_online_payment()` is **idempotent** on `(provider, provider_ref)`, so retries never double-pay.

## Your earnings
```sql
select date_trunc('month', paid_at)::date as month, provider, currency,
       count(*) as payments, sum(amount) as volume, sum(platform_fee) as invonce_fees
from online_payments where status = 'paid' group by 1, 2, 3 order by 1 desc;
```
Cross-check with Stripe Dashboard → Connect → *Collected fees* and Razorpay → Route → *Commission*.
