-- Kurucu: seçtiği tek bir kullanıcıya bildirim (push dahil).
--
-- Herkese duyuru (founder_broadcast) vardı; tek kişiye yoktu. Bildirim
-- duyuru türünde düşer, push tetikleyicisi her zamanki gibi gönderir.
begin;

create or replace function public.founder_notify_user(target uuid, title text, body text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if char_length(btrim(coalesce(title, ''))) = 0 then raise exception 'EMPTY_TITLE'; end if;
  if char_length(title) > 80 or char_length(coalesce(body, '')) > 300 then raise exception 'TOO_LONG'; end if;
  if not exists (select 1 from public.profiles p where p.id = target and p.is_active) then
    raise exception 'USER_NOT_FOUND';
  end if;
  insert into public.notifications (user_id, kind, title, body)
  values (target, 'announcement', btrim(title), btrim(coalesce(body, '')));
  return true;
end;
$$;
revoke all on function public.founder_notify_user(uuid, text, text) from public, anon;
grant execute on function public.founder_notify_user(uuid, text, text) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261002110000', 'founder_notify_user')
on conflict (version) do nothing;

commit;
