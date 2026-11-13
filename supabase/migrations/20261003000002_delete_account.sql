-- In-app account deletion (required by the App Store and Google Play).
-- Removes the caller's files, business (cascades to every table) and auth user.
-- Safe to run again: drops and recreates the function and its grants.

drop function if exists public.delete_my_account();

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_biz uuid;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  select id into v_biz from public.businesses where owner_id = v_uid;

  -- Uploaded files. Never let a storage permission problem block the deletion itself.
  if v_biz is not null then
    begin
      delete from storage.objects
       where bucket_id in ('logos', 'receipts', 'pdfs')
         and (storage.foldername(name))[1] = v_biz::text;
    exception when others then
      raise notice 'storage cleanup skipped: %', sqlerrm;
    end;

    -- Cascades to clients, items, invoices, invoice_items, payments, expenses, invoice_events, online_payments.
    delete from public.businesses where id = v_biz;
  end if;

  -- Removing the auth user also cascades anything still pointing at it.
  delete from auth.users where id = v_uid;
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Make the API see the new function immediately.
notify pgrst, 'reload schema';

-- Verification: expect one row, prosecdef = true, owner = postgres.
select proname, prosecdef, proowner::regrole as owner
from pg_proc where proname = 'delete_my_account';
