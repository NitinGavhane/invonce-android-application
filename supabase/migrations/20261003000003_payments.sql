-- Online payments: provider accounts (Stripe Connect / Razorpay Route), pay links,
-- platform fee, regional Pro pricing. Requires 0000_init + 0001 + 0002.

-- ─── Business: country, provider, fee ───────────────────────────────────────
alter table businesses add column if not exists country           char(2) not null default 'US';
alter table businesses add column if not exists payment_provider  text check (payment_provider in ('stripe', 'razorpay'));
alter table businesses add column if not exists payment_account_id text;
alter table businesses add column if not exists payments_enabled  boolean not null default false;
alter table businesses add column if not exists platform_fee_bps  int not null default 100;   -- 1.00 % on Free; Pro pays 0

-- Public pay link token per document.
alter table invoices add column if not exists pay_token text;
update invoices set pay_token = encode(gen_random_bytes(12), 'hex') where pay_token is null;
alter table invoices alter column pay_token set default encode(gen_random_bytes(12), 'hex');
alter table invoices alter column pay_token set not null;
create unique index if not exists invoices_pay_token_idx on invoices (pay_token);

-- Provider → country mapping. India = Razorpay (Stripe Connect is not available there), rest = Stripe.
create or replace function provider_for_country(p_country text) returns text
language sql immutable as $$ select case when upper(p_country) = 'IN' then 'razorpay' else 'stripe' end $$;

-- Fee the platform keeps on an online payment (minor units in = minor units out).
create or replace function platform_fee_for(p_business uuid, p_amount_minor bigint) returns bigint
language sql stable security definer set search_path = public as $$
  select case when b.plan = 'pro' then 0 else (p_amount_minor * b.platform_fee_bps / 10000)::bigint end
  from businesses b where b.id = p_business
$$;

-- ─── Online payments ledger ─────────────────────────────────────────────────
create table if not exists online_payments (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references businesses (id) on delete cascade,
  invoice_id    uuid not null references invoices (id) on delete cascade,
  provider      text not null check (provider in ('stripe', 'razorpay')),
  provider_ref  text not null,                 -- checkout session / order id
  payment_ref   text,                          -- payment intent / payment id
  amount        numeric(12,2) not null,
  currency      char(3) not null,
  platform_fee  numeric(12,2) not null default 0,
  processor_fee numeric(12,2),
  status        text not null default 'created' check (status in ('created', 'paid', 'failed', 'refunded')),
  created_at    timestamptz not null default now(),
  paid_at       timestamptz,
  raw           jsonb not null default '{}'::jsonb,
  unique (provider, provider_ref)
);
create index if not exists online_payments_business_idx on online_payments (business_id, created_at desc);
alter table online_payments enable row level security;
create policy "own online payments" on online_payments for select using (business_id = my_business_id());

-- ─── Regional Pro pricing (display; the stores are the source of truth once IAP is live)
create table if not exists pro_prices (
  country  char(2) primary key,
  currency char(3) not null,
  symbol   text not null,
  monthly  numeric(10,2) not null,
  yearly   numeric(10,2) not null
);
insert into pro_prices (country, currency, symbol, monthly, yearly) values
  ('US', 'USD', '$',   9.99,   69.99),
  ('IN', 'INR', '₹',   499,    2999),
  ('GB', 'GBP', '£',   7.99,   59.99),
  ('EU', 'EUR', '€',   8.99,   64.99),
  ('CA', 'CAD', 'C$',  12.99,  89.99),
  ('AU', 'AUD', 'A$',  14.99,  99.99),
  ('SG', 'SGD', 'S$',  12.99,  89.99),
  ('AE', 'AED', 'AED', 36,     259)
on conflict (country) do nothing;
alter table pro_prices enable row level security;
create policy "prices are public" on pro_prices for select using (true);

create or replace function pro_price_for(p_country text) returns pro_prices
language sql stable security definer set search_path = public as $$
  select * from pro_prices where country = upper(p_country)
  union all
  select * from pro_prices where country = case when upper(p_country) in ('DE','FR','ES','IT','NL','BE','AT','PT','IE','FI') then 'EU' else 'US' end
  limit 1
$$;

-- ─── Public read for the pay page (anon, token-scoped) ──────────────────────
-- Only what the pay page needs. No owner ids, no other documents.
create or replace function public_invoice(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'number', i.number, 'kind', i.kind, 'status', i.status, 'issued_on', i.issued_on, 'due_on', i.due_on,
    'currency', b.currency, 'country', b.country,
    'business', jsonb_build_object('name', b.name, 'email', b.email, 'phone', b.phone, 'address', b.address,
                                   'payments_enabled', b.payments_enabled, 'provider', b.payment_provider),
    'client', jsonb_build_object('name', c.name),
    'items', (select coalesce(jsonb_agg(jsonb_build_object('name', ii.name, 'qty', ii.qty, 'rate', ii.rate) order by ii.position), '[]')
              from invoice_items ii where ii.invoice_id = i.id),
    'subtotal', t.subtotal, 'discount', i.discount, 'tax', t.tax, 'total', t.total, 'paid', t.paid, 'balance', t.total - t.paid
  )
  from invoices i
  join businesses b on b.id = i.business_id
  join clients c on c.id = i.client_id
  join invoice_totals t on t.id = i.id
  where i.pay_token = p_token and i.kind = 'invoice'
$$;

create or replace function mark_invoice_viewed(p_token text) returns void
language plpgsql security definer set search_path = public as $$
declare v_inv invoices%rowtype;
begin
  select * into v_inv from invoices where pay_token = p_token;
  if v_inv.id is null then return; end if;
  -- one "viewed" event per hour at most
  if not exists (select 1 from invoice_events e where e.invoice_id = v_inv.id and e.type = 'viewed' and e.at > now() - interval '1 hour') then
    insert into invoice_events (business_id, invoice_id, type) values (v_inv.business_id, v_inv.id, 'viewed');
  end if;
  if v_inv.status = 'draft' then update invoices set status = 'unpaid' where id = v_inv.id; end if;
end $$;

-- ─── Webhook-side application of a payment (service role only) ─────────────
create or replace function apply_online_payment(
  p_token text, p_provider text, p_provider_ref text, p_payment_ref text,
  p_amount numeric, p_currency text, p_platform_fee numeric, p_processor_fee numeric, p_raw jsonb
) returns void
language plpgsql security definer set search_path = public as $$
declare v_inv invoices%rowtype; v_total numeric; v_paid numeric;
begin
  select * into v_inv from invoices where pay_token = p_token;
  if v_inv.id is null then raise exception 'unknown pay token'; end if;

  insert into online_payments (business_id, invoice_id, provider, provider_ref, payment_ref, amount, currency,
                               platform_fee, processor_fee, status, paid_at, raw)
  values (v_inv.business_id, v_inv.id, p_provider, p_provider_ref, p_payment_ref, p_amount, upper(p_currency),
          coalesce(p_platform_fee, 0), p_processor_fee, 'paid', now(), coalesce(p_raw, '{}'::jsonb))
  on conflict (provider, provider_ref) do nothing;
  if not found then return; end if;   -- webhook retry: already applied

  insert into payments (business_id, invoice_id, amount, method, reference, note)
  values (v_inv.business_id, v_inv.id, p_amount, 'card', p_payment_ref, 'Paid online via ' || p_provider);

  select total, paid into v_total, v_paid from invoice_totals where id = v_inv.id;
  if v_paid >= v_total then
    update invoices set status = 'paid', paid_on = current_date where id = v_inv.id;
  end if;
  insert into invoice_events (business_id, invoice_id, type, meta)
  values (v_inv.business_id, v_inv.id, 'paid', jsonb_build_object('amount', p_amount, 'provider', p_provider, 'online', true));
end $$;

-- Ledger row created at checkout time (so a failed/abandoned checkout is visible too).
create or replace function begin_online_payment(
  p_token text, p_provider text, p_provider_ref text, p_amount numeric, p_currency text, p_platform_fee numeric
) returns void
language sql security definer set search_path = public as $$
  insert into online_payments (business_id, invoice_id, provider, provider_ref, amount, currency, platform_fee, status)
  select i.business_id, i.id, p_provider, p_provider_ref, p_amount, upper(p_currency), coalesce(p_platform_fee, 0), 'created'
  from invoices i where i.pay_token = p_token
  on conflict (provider, provider_ref) do nothing
$$;

-- Provider account bookkeeping, called by the connect function with the service role.
create or replace function set_payment_account(p_business uuid, p_provider text, p_account_id text, p_enabled boolean) returns void
language sql security definer set search_path = public as $$
  update businesses set payment_provider = p_provider, payment_account_id = p_account_id, payments_enabled = p_enabled
  where id = p_business
$$;

-- Owner-facing earnings summary (what the business collected online).
create or replace view online_payment_summary with (security_invoker = true) as
select business_id,
       count(*) filter (where status = 'paid')                          as payments,
       coalesce(sum(amount) filter (where status = 'paid'), 0)          as collected,
       coalesce(sum(platform_fee) filter (where status = 'paid'), 0)    as platform_fees,
       max(paid_at)                                                     as last_paid_at
from online_payments group by business_id;

-- ─── Grants ─────────────────────────────────────────────────────────────────
revoke all on function apply_online_payment(text, text, text, text, numeric, text, numeric, numeric, jsonb) from public, anon, authenticated;
revoke all on function begin_online_payment(text, text, text, numeric, text, numeric) from public, anon, authenticated;
revoke all on function set_payment_account(uuid, text, text, boolean) from public, anon, authenticated;
grant execute on function public_invoice(text) to anon, authenticated;
grant execute on function mark_invoice_viewed(text) to anon, authenticated;
grant execute on function pro_price_for(text) to anon, authenticated;
grant execute on function platform_fee_for(uuid, bigint) to authenticated;
