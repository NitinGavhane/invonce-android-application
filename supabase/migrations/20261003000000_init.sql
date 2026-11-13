-- Invonce - Postgres schema for Supabase
-- Apply with `supabase db push` or paste into the SQL editor. See supabase/README.md.

create extension if not exists pgcrypto;

-- --- Enums ------------------------------------------------------------------
create type invoice_kind   as enum ('invoice', 'estimate');
create type invoice_status as enum ('draft', 'sent', 'unpaid', 'overdue', 'paid', 'accepted', 'voided');
create type payment_method as enum ('card', 'cash', 'check', 'bank_transfer', 'other');
create type event_type     as enum ('created', 'sent', 'viewed', 'reminded', 'paid', 'accepted');

-- --- Tables -----------------------------------------------------------------
create table businesses (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references auth.users (id) on delete cascade,
  name          text not null default '',
  email         text,
  phone         text,
  address       text,
  website       text,
  tax_id        text,
  logo_path     text,
  currency      char(3) not null default 'USD',
  tax_rate      numeric(5,4) not null default 0.1000,
  due_days      int not null default 14,
  plan          text not null default 'free',
  invoice_seq   int not null default 0,
  estimate_seq  int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index businesses_owner_idx on businesses (owner_id);

create table clients (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  name        text not null,
  email       text,
  phone       text,
  address     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index clients_business_idx on clients (business_id, name);

create table items (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  name        text not null,
  kind        text not null default 'service' check (kind in ('service', 'product')),
  unit        text not null default 'flat',
  price       numeric(12,2),              -- null = percentage / custom
  price_label text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index items_business_idx on items (business_id, name);

create table invoices (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  client_id   uuid not null references clients (id) on delete restrict,
  kind        invoice_kind not null default 'invoice',
  number      text not null,
  status      invoice_status not null default 'draft',
  issued_on   date not null default current_date,
  due_on      date not null,
  discount    numeric(12,2) not null default 0,
  tax_rate    numeric(5,4) not null default 0,
  notes       text,
  template    text not null default 'daylit',
  pdf_path    text,
  paid_on     date,
  voided_at   timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (business_id, number)
);
create index invoices_business_idx on invoices (business_id, issued_on desc);
create index invoices_client_idx on invoices (client_id);

create table invoice_items (
  id         uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices (id) on delete cascade,
  name       text not null,
  qty        numeric(10,2) not null default 1,
  rate       numeric(12,2) not null,
  position   int not null default 0
);
create index invoice_items_invoice_idx on invoice_items (invoice_id, position);

create table payments (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  invoice_id  uuid not null references invoices (id) on delete cascade,
  amount      numeric(12,2) not null check (amount > 0),
  method      payment_method not null default 'other',
  paid_on     date not null default current_date,
  reference   text,
  note        text,
  created_at  timestamptz not null default now()
);
create index payments_invoice_idx on payments (invoice_id);

create table expenses (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references businesses (id) on delete cascade,
  name         text not null,
  category     text not null default 'Other',
  amount       numeric(12,2) not null,
  spent_on     date not null default current_date,
  receipt_path text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index expenses_business_idx on expenses (business_id, spent_on desc);

-- Activity log: sent / viewed (read receipts) / paid ...
create table invoice_events (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  invoice_id  uuid not null references invoices (id) on delete cascade,
  type        event_type not null,
  at          timestamptz not null default now(),
  meta        jsonb not null default '{}'::jsonb
);
create index invoice_events_invoice_idx on invoice_events (invoice_id, at desc);

-- --- Helpers ----------------------------------------------------------------
create or replace function my_business_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from businesses where owner_id = auth.uid()
$$;

create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger businesses_touch before update on businesses for each row execute function touch_updated_at();
create trigger clients_touch    before update on clients    for each row execute function touch_updated_at();
create trigger items_touch      before update on items      for each row execute function touch_updated_at();
create trigger invoices_touch   before update on invoices   for each row execute function touch_updated_at();
create trigger expenses_touch   before update on expenses   for each row execute function touch_updated_at();

-- Every new auth user gets a business row.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into businesses (owner_id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'business_name', ''), new.email);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function handle_new_user();

-- Computed totals per invoice (RLS of the base tables applies via security_invoker).
create or replace view invoice_totals with (security_invoker = true) as
select
  i.id,
  i.business_id,
  coalesce(sum(ii.qty * ii.rate), 0)::numeric(12,2)                                        as subtotal,
  ((coalesce(sum(ii.qty * ii.rate), 0) - i.discount) * i.tax_rate)::numeric(12,2)         as tax,
  (coalesce(sum(ii.qty * ii.rate), 0) - i.discount
     + (coalesce(sum(ii.qty * ii.rate), 0) - i.discount) * i.tax_rate)::numeric(12,2)     as total,
  coalesce((select sum(p.amount) from payments p where p.invoice_id = i.id), 0)::numeric(12,2) as paid
from invoices i
left join invoice_items ii on ii.invoice_id = i.id
group by i.id;

-- --- RPCs -------------------------------------------------------------------
-- INV-0001 / EST-0001 per business, atomically.
create or replace function next_document_number(p_kind invoice_kind) returns text
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_kind = 'invoice' then
    update businesses set invoice_seq = invoice_seq + 1 where id = my_business_id() returning invoice_seq into n;
    return 'INV-' || lpad(n::text, 4, '0');
  else
    update businesses set estimate_seq = estimate_seq + 1 where id = my_business_id() returning estimate_seq into n;
    return 'EST-' || lpad(n::text, 4, '0');
  end if;
end $$;

-- p = { client_id, kind, status?, issued_on, due_on, discount, tax_rate, notes?, items: [{name, qty, rate}] }
create or replace function create_invoice(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_kind invoice_kind := coalesce((p ->> 'kind')::invoice_kind, 'invoice');
  v_biz uuid := my_business_id();
begin
  if v_biz is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from clients where id = (p ->> 'client_id')::uuid and business_id = v_biz) then
    raise exception 'client not found';
  end if;

  insert into invoices (business_id, client_id, kind, number, status, issued_on, due_on, discount, tax_rate, notes)
  values (
    v_biz,
    (p ->> 'client_id')::uuid,
    v_kind,
    next_document_number(v_kind),
    coalesce((p ->> 'status')::invoice_status, (case when v_kind = 'invoice' then 'unpaid' else 'draft' end)::invoice_status),
    coalesce((p ->> 'issued_on')::date, current_date),
    coalesce((p ->> 'due_on')::date, current_date + 14),
    coalesce((p ->> 'discount')::numeric, 0),
    coalesce((p ->> 'tax_rate')::numeric, 0),
    p ->> 'notes'
  ) returning id into v_id;

  insert into invoice_items (invoice_id, name, qty, rate, position)
  select v_id, it ->> 'name', coalesce((it ->> 'qty')::numeric, 1), (it ->> 'rate')::numeric, ord - 1
  from jsonb_array_elements(coalesce(p -> 'items', '[]'::jsonb)) with ordinality as t(it, ord);

  insert into invoice_events (business_id, invoice_id, type) values (v_biz, v_id, 'created');
  return v_id;
end $$;

-- Records a (partial or full) payment; marks the invoice paid once the balance hits zero.
create or replace function record_payment(
  p_invoice uuid, p_amount numeric, p_method payment_method default 'other',
  p_reference text default null, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_biz uuid := my_business_id();
  v_total numeric; v_paid numeric;
begin
  if not exists (select 1 from invoices where id = p_invoice and business_id = v_biz) then
    raise exception 'invoice not found';
  end if;
  insert into payments (business_id, invoice_id, amount, method, reference, note)
  values (v_biz, p_invoice, p_amount, p_method, p_reference, p_note);

  select total, paid into v_total, v_paid from invoice_totals where id = p_invoice;
  if v_paid >= v_total then
    update invoices set status = 'paid', paid_on = current_date where id = p_invoice;
    insert into invoice_events (business_id, invoice_id, type, meta)
    values (v_biz, p_invoice, 'paid', jsonb_build_object('amount', p_amount, 'method', p_method));
  end if;
end $$;

-- Nightly: flip unpaid invoices past due to overdue (call from a cron / edge function).
create or replace function mark_overdue() returns int
language sql security definer set search_path = public as $$
  with u as (
    update invoices set status = 'overdue'
    where status = 'unpaid' and due_on < current_date returning 1
  ) select count(*)::int from u
$$;

-- --- Row-level security -----------------------------------------------------
alter table businesses     enable row level security;
alter table clients        enable row level security;
alter table items          enable row level security;
alter table invoices       enable row level security;
alter table invoice_items  enable row level security;
alter table payments       enable row level security;
alter table expenses       enable row level security;
alter table invoice_events enable row level security;

create policy "own business"  on businesses     for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "own clients"   on clients        for all using (business_id = my_business_id()) with check (business_id = my_business_id());
create policy "own items"     on items          for all using (business_id = my_business_id()) with check (business_id = my_business_id());
create policy "own invoices"  on invoices       for all using (business_id = my_business_id()) with check (business_id = my_business_id());
create policy "own payments"  on payments       for all using (business_id = my_business_id()) with check (business_id = my_business_id());
create policy "own expenses"  on expenses       for all using (business_id = my_business_id()) with check (business_id = my_business_id());
create policy "own events"    on invoice_events for all using (business_id = my_business_id()) with check (business_id = my_business_id());
create policy "own invoice items" on invoice_items for all
  using  (exists (select 1 from invoices i where i.id = invoice_id and i.business_id = my_business_id()))
  with check (exists (select 1 from invoices i where i.id = invoice_id and i.business_id = my_business_id()));

-- --- Storage buckets (logos, receipt photos, generated PDFs) ----------------
insert into storage.buckets (id, name, public) values
  ('logos', 'logos', false), ('receipts', 'receipts', false), ('pdfs', 'pdfs', false)
on conflict (id) do nothing;

-- Files live under <business_id>/... so the first folder segment gates access.
create policy "own files read"   on storage.objects for select using ((storage.foldername(name))[1] = my_business_id()::text);
create policy "own files write"  on storage.objects for insert with check ((storage.foldername(name))[1] = my_business_id()::text);
create policy "own files update" on storage.objects for update using ((storage.foldername(name))[1] = my_business_id()::text);
create policy "own files delete" on storage.objects for delete using ((storage.foldername(name))[1] = my_business_id()::text);
