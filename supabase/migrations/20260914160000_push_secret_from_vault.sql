-- send-push, paylaşılan sırrı Vault'tan kendisi okur (service_role ile);
-- Edge Function Secrets'a elle kopyalamak gerekmez. Yalnız service_role
-- çağırabilir; authenticated/anon için kapalı.
begin;

create or replace function public.push_webhook_secret()
returns text language sql stable security definer set search_path = '' as $$
  select ds.decrypted_secret from vault.decrypted_secrets ds
  where ds.name = 'push_webhook_secret' limit 1;
$$;
revoke all on function public.push_webhook_secret() from public, anon, authenticated;
grant execute on function public.push_webhook_secret() to service_role;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914160000', 'push_secret_from_vault') on conflict (version) do nothing;

commit;
