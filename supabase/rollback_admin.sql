-- Removes everything the (now deleted) admin migrations created.
-- Only needed if you ran 20261003000003/4/5_admin*.sql in the Supabase SQL editor. Safe to run otherwise.

drop trigger if exists on_auth_user_admin_invite on auth.users;
drop function if exists handle_admin_invite();

drop function if exists admin_invite(text, text);
drop function if exists admin_set_role(text, text);
drop function if exists admin_revoke(text);
drop function if exists admin_list();
drop function if exists admin_invites_list();
drop function if exists admin_status();
drop function if exists admin_require(text[]);
drop function if exists admin_has_mfa(uuid);
drop function if exists admin_role();
drop table if exists admin_invites;

drop function if exists admin_find(text);
drop function if exists admin_business_summary(uuid);
drop function if exists admin_business_activity(uuid);
drop function if exists admin_export_business(uuid);
drop function if exists admin_invoice_rows(uuid);
drop function if exists admin_confirm_email(text);
drop function if exists admin_ban(text, boolean);
drop function if exists admin_assert();

drop view if exists admin_signups_daily, admin_signups_weekly, admin_active_weekly, admin_retention,
  admin_invoices_monthly, admin_revenue_monthly, admin_conversion, admin_top_businesses, admin_invoice_benchmarks,
  admin_overdue, admin_inactive_60d, admin_abuse_bursts, admin_shared_client_emails, admin_storage_usage, admin_row_counts;

drop view if exists admin_stats, admin_daily, admin_businesses, admin_invoices;

drop function if exists admin_set_plan(uuid, text);
drop function if exists admin_set_suspended(uuid, boolean);
drop function if exists admin_delete_account(uuid);
drop function if exists admin_log(text, uuid, jsonb);
drop function if exists touch_active();
drop table if exists admin_actions;

drop policy if exists "admin read businesses"    on businesses;
drop policy if exists "admin read clients"       on clients;
drop policy if exists "admin read items"         on items;
drop policy if exists "admin read invoices"      on invoices;
drop policy if exists "admin read invoice items" on invoice_items;
drop policy if exists "admin read payments"      on payments;
drop policy if exists "admin read expenses"      on expenses;
drop policy if exists "admin read events"        on invoice_events;

alter table businesses drop column if exists suspended_at;
alter table businesses drop column if exists last_active_at;

drop function if exists is_admin();
drop table if exists admins;
