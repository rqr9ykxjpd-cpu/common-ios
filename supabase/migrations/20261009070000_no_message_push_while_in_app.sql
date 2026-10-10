-- Uygulama açıkken mesaj bildirimi gitmesin (kurucunun isteği).
--
-- Sohbet ederken karşı tarafın her mesajı telefonun üstünde bildirim olarak
-- da düşüyordu. Alıcı o an uygulamadaysa (son 2 dakikada "buradayım" demiş ve
-- sonra "ayrıldım" dememiş) mesaj bildirimi için push gönderilmez; bildirim
-- satırı yine yazılır, zil ve sohbet rozeti uygulamada güncellenir.
-- Sunucu tarafında: yayındaki 1.1.2/1.1.3 için de geçerli. 1.1.4'te uygulama
-- açıkken hiçbir bildirim kutusu gösterilmiyor (istemci tarafı).
--
-- Bedeli: uygulama arka plana geçerken "ayrıldım" isteği gidemezse (ağ yok)
-- en fazla 2 dakika mesaj bildirimi gelmez. Uygulama her dakika "buradayım"
-- diyor; 2 dakika bir nabzın kaçmasını tolere ediyor.
-- Gövde 20260914150000'deki (canlıdaki, md5 46da18d6…) tanım; yalnızca baştaki
-- kontrol eklendi.
begin;

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
  -- Alıcı şu an uygulamada: mesaj ekranda/sohbet listesinde zaten görünüyor.
  if new.kind = 'message' and exists (
    select 1 from public.profiles p
    where p.id = new.user_id
      and p.online_at > now() - interval '2 minutes'
      and (p.offline_at is null or p.online_at > p.offline_at)
  ) then
    return new;
  end if;

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
values ('20261009070000', 'no_message_push_while_in_app')
on conflict (version) do nothing;

commit;
