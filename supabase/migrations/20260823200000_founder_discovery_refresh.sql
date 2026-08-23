-- Kurucu/moderatör "Yenile" ile desteyi gerçekten sıfırlayabilsin.
--
-- Normal kullanıcıda yalnızca 'pass' silinir (beğeniler/eşleşmeler korunur).
-- Staff hesapta eşleşmeye dönüşmemiş tüm tepkiler silinir — test ederken
-- herkesi geçtikten sonra Yenile'nin boş dönmesi kurucuyu kilitliyordu.
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
    delete from public.reactions r
    where r.actor_id = auth.uid()
      and not exists (
        select 1 from public.matches m
        where m.unmatched_at is null
          and ((m.user_a = auth.uid() and m.user_b = r.subject_id)
            or (m.user_b = auth.uid() and m.user_a = r.subject_id))
      );
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
