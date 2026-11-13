-- Document template chosen in More → Templates. One per business; applies to
-- every invoice, estimate and receipt (preview, PDF and the public pay page).
-- Ids match `InvoiceTemplate.id` in lib/data/models.dart.
alter table businesses
  add column if not exists template text not null default 'daylit'
    check (template in ('daylit', 'ledger', 'clean', 'bold', 'classic', 'compact'));
