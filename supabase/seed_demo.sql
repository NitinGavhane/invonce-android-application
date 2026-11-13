-- Optional: seeds the signed-in user's business with the Northwind Studio demo data.
-- Run from the SQL editor *while impersonating a user*, or call `select seed_demo_data();`
-- from the app (it is an RPC). Safe to run once; it no-ops if clients already exist.

create or replace function seed_demo_data() returns void
language plpgsql security definer set search_path = public as $$
declare
  b uuid := my_business_id();
  c_atlas uuid; c_cedar uuid; c_harbor uuid; c_juniper uuid; c_meadow uuid; c_vela uuid;
  inv uuid;
begin
  if b is null then raise exception 'not signed in'; end if;
  if exists (select 1 from clients where business_id = b) then return; end if;

  update businesses set name = 'Northwind Studio', email = 'hello@northwind.co', phone = '(503) 555-0199',
    address = E'1180 NW Glisan St, Suite 300\nPortland, OR 97209', website = 'northwind.co'
  where id = b and name = '';

  insert into clients (business_id, name, email, phone, address) values
    (b, 'Atlas Fitness',    'billing@atlasfit.com',      '(503) 555-0120', '2200 NE Alberta St, Portland, OR 97211') returning id into c_atlas;
  insert into clients (business_id, name, email, phone, address) values
    (b, 'Cedar & Pine Co',  'accounts@cedarpine.co',     '(503) 555-0109', '77 SE Grand Ave, Portland, OR 97214') returning id into c_cedar;
  insert into clients (business_id, name, email, phone, address) values
    (b, 'Harbor & Co',      'accounts@harbor.co',        '(503) 555-0142', '412 Market St, Portland, OR 97204') returning id into c_harbor;
  insert into clients (business_id, name, email, phone, address) values
    (b, 'Juniper Bakery',   'orders@juniperbakery.com',  '(503) 555-0177', '88 SE Division St, Portland, OR 97202') returning id into c_juniper;
  insert into clients (business_id, name, email, phone, address) values
    (b, 'Meadow Interiors', 'hello@meadowinteriors.co',  '(503) 555-0163', '501 N Mississippi Ave, Portland, OR 97227') returning id into c_meadow;
  insert into clients (business_id, name, email, phone, address) values
    (b, 'Vela Marketing',   'ap@velamarketing.com',      '(503) 555-0188', '1020 SW Taylor St, Portland, OR 97205') returning id into c_vela;

  insert into items (business_id, name, kind, unit, price, price_label) values
    (b, 'Website design',        'service', 'flat',         2400, null),
    (b, 'Brand identity system', 'service', 'flat',          900, null),
    (b, 'Consulting',            'service', 'per hour',      150, '/hr'),
    (b, 'Hosting - annual',      'product', 'per year',      680, null),
    (b, 'Logo design',           'service', 'flat',          600, null),
    (b, 'Landing page design',   'service', 'flat',          340, null),
    (b, 'Rush fee',              'service', '25% of total', null, '25%');

  -- Paid history (May → Oct) so Reports has a curve.
  perform create_invoice(jsonb_build_object('client_id', c_cedar,   'issued_on', '2026-05-12', 'due_on', '2026-05-26', 'items', '[{"name":"Brand photography","rate":5600},{"name":"Logo design","rate":600}]'));
  perform create_invoice(jsonb_build_object('client_id', c_atlas,   'issued_on', '2026-06-08', 'due_on', '2026-06-22', 'items', '[{"name":"Website design","rate":4100}]'));
  perform create_invoice(jsonb_build_object('client_id', c_meadow,  'issued_on', '2026-06-20', 'due_on', '2026-07-04', 'items', '[{"name":"Catalog design","rate":3000}]'));
  perform create_invoice(jsonb_build_object('client_id', c_cedar,   'issued_on', '2026-07-10', 'due_on', '2026-07-24', 'items', '[{"name":"Brand identity system","rate":5400}]'));
  perform create_invoice(jsonb_build_object('client_id', c_harbor,  'issued_on', '2026-07-31', 'due_on', '2026-08-14', 'items', '[{"name":"Website redesign","rate":3140}]'));
  perform create_invoice(jsonb_build_object('client_id', c_vela,    'issued_on', '2026-08-02', 'due_on', '2026-08-16', 'items', '[{"name":"Campaign landing pages","rate":5160}]'));
  perform create_invoice(jsonb_build_object('client_id', c_juniper, 'issued_on', '2026-08-26', 'due_on', '2026-09-09', 'items', '[{"name":"Bakery rebrand","rate":5540}]'));
  perform create_invoice(jsonb_build_object('client_id', c_meadow,  'issued_on', '2026-08-29', 'due_on', '2026-09-12', 'items', '[{"name":"Showroom signage","rate":1460}]'));
  perform create_invoice(jsonb_build_object('client_id', c_atlas,   'issued_on', '2026-09-10', 'due_on', '2026-09-24', 'items', '[{"name":"Brand photography","rate":2100}]'));
  -- mark all of the above paid on their due dates
  for inv in select id from invoices where business_id = b loop
    perform record_payment(inv, (select total from invoice_totals where id = inv), 'card');
  end loop;
  update invoices i set paid_on = i.due_on where business_id = b and status = 'paid';
  update payments p set paid_on = i.due_on from invoices i where p.invoice_id = i.id and i.business_id = b;

  -- Open / overdue
  perform create_invoice(jsonb_build_object('client_id', c_juniper, 'issued_on', '2026-09-14', 'due_on', '2026-09-28', 'items', '[{"name":"Menu & packaging design","rate":740}]'));
  perform create_invoice(jsonb_build_object('client_id', c_cedar,   'issued_on', '2026-09-20', 'due_on', '2026-10-04', 'items', '[{"name":"Packaging system","rate":4300}]'));
  perform create_invoice(jsonb_build_object('client_id', c_harbor,  'issued_on', '2026-09-26', 'due_on', '2026-10-10', 'items', '[{"name":"Brand identity system","rate":900},{"name":"Landing page design","rate":340}]'));
  perform create_invoice(jsonb_build_object('client_id', c_vela,    'issued_on', '2026-10-03', 'due_on', '2026-10-14', 'items', '[{"name":"Website design","rate":2400},{"name":"Hosting - annual","rate":680}]'));
  perform mark_overdue();

  -- Estimates
  perform create_invoice(jsonb_build_object('client_id', c_meadow,  'kind', 'estimate', 'status', 'accepted', 'issued_on', '2026-10-01', 'due_on', '2026-10-31', 'items', '[{"name":"Showroom refresh","rate":5400}]'));
  perform create_invoice(jsonb_build_object('client_id', c_vela,    'kind', 'estimate', 'status', 'sent',     'issued_on', '2026-10-02', 'due_on', '2026-11-01', 'items', '[{"name":"Website design","rate":2400},{"name":"Hosting - annual","rate":680}]'));
  perform create_invoice(jsonb_build_object('client_id', c_atlas,   'kind', 'estimate', 'status', 'sent',     'issued_on', '2026-09-26', 'due_on', '2026-10-26', 'items', '[{"name":"Brand photography","rate":2100}]'));
  perform create_invoice(jsonb_build_object('client_id', c_harbor,  'kind', 'estimate', 'status', 'draft',    'issued_on', '2026-09-30', 'due_on', '2026-10-30', 'items', '[{"name":"Brand identity system","rate":900},{"name":"Landing page design","rate":340}]'));

  insert into expenses (business_id, name, category, amount, spent_on, receipt_path) values
    (b, 'Design software',            'Software', 49,  '2026-10-01', 'x'),
    (b, 'Client lunch - Harbor & Co', 'Meals',    86,  '2026-09-30', 'x'),
    (b, 'Flight to Seattle',          'Travel',   412, '2026-09-28', 'x'),
    (b, 'Printer paper & toner',      'Office',   64,  '2026-09-26', null),
    (b, 'Co-working desk',            'Office',   350, '2026-09-24', 'x');
end $$;
