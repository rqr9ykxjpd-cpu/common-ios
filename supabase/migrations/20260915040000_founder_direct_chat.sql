-- Kurucuya herkes doğrudan yazabilir: bağlantı isteği/kabul gerekmez.
--
-- Profilde "Kurucuya yaz" düğmesi bu RPC'yi çağırır; kurucuyla arada bir
-- bağlantı (matches satırı) açılır ya da kapatılmışsa yeniden açılır ve sohbet
-- kimliği döner. Engel varsa ve hesap dondurulmuşsa açılmaz. Kurucu kendisi
-- için anlamsız (SELF). Tetikleyici iki tarafa "Yeni bağlantı" yazar; kişi
-- kendi başlattığı için ona giden bildirim silinir, kurucununki kalır (kim
-- yazmak istedi görsün).

begin;

create or replace function public.open_founder_chat()
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  ben uuid := auth.uid();
  kurucu uuid;
  eslesme uuid;
begin
  if ben is null then raise exception 'AUTH_REQUIRED'; end if;
  select id into kurucu from public.profiles
  where badge = 'founder' and is_active
  order by created_at limit 1;
  if kurucu is null then raise exception 'FOUNDER_NOT_FOUND'; end if;
  if kurucu = ben then raise exception 'SELF'; end if;
  if not exists (select 1 from public.profiles where id = ben and is_active) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = ben and b.blocked_id = kurucu)
       or (b.blocker_id = kurucu and b.blocked_id = ben)
  ) then
    raise exception 'BLOCKED';
  end if;

  insert into public.matches (user_a, user_b)
  values (least(ben, kurucu), greatest(ben, kurucu))
  on conflict (user_a, user_b) do update set unmatched_at = null
  returning id into eslesme;

  delete from public.notifications
  where match_id = eslesme and user_id = ben and kind = 'match'
    and created_at > now() - interval '10 seconds';

  return eslesme;
end;
$$;
revoke all on function public.open_founder_chat() from public, anon;
grant execute on function public.open_founder_chat() to authenticated;

commit;
