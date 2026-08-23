-- Kurucu Yenile: eşleşmiş olsa bile tepkileri temizle.
--
-- Önceki sürüm eşleşmeli kişilerin reaction'ını bırakıyordu; test hesabında
-- herkes eşleşince Yenile yine boş desteyle dönüyordu. Sohbet/eşleşme satırı
-- durur, yalnızca keşif filtresindeki reaction kalkar.
--
-- Idempotent.

begin;

create or replace function public.reset_my_passes()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  silinen integer;
  staff boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select exists (
    select 1 from public.profiles
    where id = auth.uid() and badge in ('founder', 'moderator')
  ) into staff;

  if staff then
    delete from public.reactions
    where actor_id = auth.uid();
  else
    delete from public.reactions
    where actor_id = auth.uid() and kind = 'pass';
  end if;

  get diagnostics silinen = row_count;
  return silinen;
end;
$$;

revoke all on function public.reset_my_passes() from public, anon;
grant execute on function public.reset_my_passes() to authenticated;

commit;
