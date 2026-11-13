# Invonce backend (Supabase + Postgres)

The app runs in **demo mode** (in-memory sample data) until you give it a Supabase project.

## 1. Create the project
1. https://supabase.com → New project. Pick a region near your users.
2. **Authentication → Providers → Email**: for development, turn **Confirm email** *off* so sign-up signs you straight in. (Turn it back on before launch, and add Apple / Google sign-in there too.)

## 2. Apply the schema
Either paste `migrations/20261003000000_init.sql` into **SQL Editor → Run**, or with the CLI:

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

Optional demo data: run `seed_demo.sql` (creates the `seed_demo_data()` function), then from the
app's account call it — e.g. in the SQL editor with "Run as user", or temporarily from Dart:
`Supabase.instance.client.rpc('seed_demo_data')`.

## 3. Point the app at it
Project Settings → API Keys → copy the **Project URL** and the **publishable** key (`sb_publishable_…`;
the older `anon` JWT works too), then run:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```

(Or put them in a `.vscode/launch.json` / Android Studio run config.) The publishable key is safe to ship
in the app — every table is protected by row-level security, so a user can only ever see their own business.

## What the schema gives you
| Table | Purpose |
|---|---|
| `businesses` | one per user, created automatically on sign-up (`handle_new_user` trigger); holds currency, tax, due-days, plan, numbering sequences, document `template` |
| `clients`, `items` | address book and saved products/services |
| `invoices` + `invoice_items` | both invoices and estimates (`kind`), status lifecycle, template, PDF path |
| `payments` | partial or full payments; `record_payment()` flips status to `paid` at zero balance |
| `expenses` | with optional receipt photo path |
| `invoice_events` | sent / viewed (read receipts) / paid activity feed |
| `invoice_totals` (view) | subtotal, tax, total, paid — computed in SQL |

RPCs the app calls: `create_invoice(jsonb)`, `record_payment(...)`, `next_document_number(kind)`.
Scheduled: `mark_overdue()` — wire it to a daily cron (Database → Cron) to roll unpaid → overdue.

Storage buckets `logos`, `receipts`, `pdfs` are private; files must be stored under `<business_id>/…`.

## Next (server-side, Edge Functions in TypeScript)
- `send-invoice` — email/SMS the PDF via Resend / Twilio and log a `sent` event
- `invoice-page` — public link `/i/<token>` that logs `viewed` (read receipt) and shows a Pay button
- `stripe-webhook` — on successful payment call `record_payment`
- `iap-webhook` — verify App Store / Play receipts and set `businesses.plan = 'pro'`
