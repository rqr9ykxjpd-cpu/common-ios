-- Eşleşmeden çıkma.
--
-- `matches.unmatched_at` sütunu vardı ama yalnızca engelleme onu kullanıyordu; kullanıcının
-- "bu eşleşmeyi bitir" seçeneği yoktu. Sıkıldığı biriyle sohbeti bitirmek isteyen kişi
-- karşı tarafı engellemek zorunda kalıyordu — çok daha ağır ve geri dönüşü zor bir eylem.
--
-- İstemciye `matches` üzerinde update yetkisi verilmediği için security definer RPC gerekiyor.
-- Idempotent.

begin;

create or replace function public.unmatch(match_uuid uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.matches
  set unmatched_at = now()
  where id = match_uuid
    and unmatched_at is null
    and (user_a = auth.uid() or user_b = auth.uid());
  if not found then raise exception 'Match unavailable'; end if;
end;
$$;

revoke all on function public.unmatch(uuid) from public, anon;
grant execute on function public.unmatch(uuid) to authenticated;

commit;
