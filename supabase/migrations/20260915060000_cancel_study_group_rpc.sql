-- Ev sahibi grubu iptal eder. Doğrudan UPDATE olmuyordu: PostgREST güncellemeyi
-- RETURNING'li CTE ile sarıyor, iptal edilen satır okuma politikasından düştüğü
-- için Postgres "new row violates row-level security policy" diyordu.

begin;

create or replace function public.cancel_study_group(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare guncellenen integer;
begin
  update public.study_groups
     set cancelled_at = now()
   where id = target and host_id = auth.uid() and cancelled_at is null;
  get diagnostics guncellenen = row_count;
  if guncellenen = 0 then raise exception 'STUDY_GROUP_NOT_FOUND' using errcode = 'no_data_found'; end if;
end;
$$;
revoke all on function public.cancel_study_group(uuid) from public, anon;
grant execute on function public.cancel_study_group(uuid) to authenticated;

drop policy if exists "hosts cancel study groups" on public.study_groups;
revoke update on public.study_groups from authenticated;

commit;
