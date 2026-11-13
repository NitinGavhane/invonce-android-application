-- Fix: COALESCE(invoice_status, text) type mismatch in create_invoice (42804).
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
