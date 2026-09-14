-- Push bildirimi hiç çıkmıyordu: pg_net kapalıydı (net.http_post yok),
-- Vault boştu; tetikleyici hatayı yutup sessizce dönüyordu.
-- - pg_net açılır.
-- - Vault'a project_url ve veritabanının kendi ürettiği push_webhook_secret
--   yazılır (varsa dokunulmaz). Sır kimsenin elinden geçmez; Edge Function
--   tarafına aynı değer PUSH_WEBHOOK_SECRET olarak kopyalanır.
-- - Tetikleyici service_role yerine bu sırla çağırır; service_role Vault'ta
--   durmasın diye. (Eski davranış yedek olarak kalır.)
begin;

create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'project_url') then
    perform vault.create_secret('https://wwogjakgwzwmffyzpjjo.supabase.co', 'project_url');
  end if;
  if not exists (select 1 from vault.secrets where name = 'push_webhook_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'push_webhook_secret');
  end if;
end $$;

create or replace function public.push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  bearer text;
begin
  begin
    select ds.decrypted_secret into project_url
      from vault.decrypted_secrets ds where ds.name = 'project_url' limit 1;
    select ds.decrypted_secret into bearer
      from vault.decrypted_secrets ds where ds.name = 'push_webhook_secret' limit 1;
    if bearer is null then
      select ds.decrypted_secret into bearer
        from vault.decrypted_secrets ds where ds.name = 'service_role_key' limit 1;
    end if;
  exception
    when undefined_table then return new;
    when undefined_object then return new;
  end;

  if project_url is null or bearer is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || bearer
    ),
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', to_jsonb(new)
    )
  );
  return new;
exception
  when others then
    return new;
end;
$$;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914150000', 'push_via_webhook_secret') on conflict (version) do nothing;

commit;
