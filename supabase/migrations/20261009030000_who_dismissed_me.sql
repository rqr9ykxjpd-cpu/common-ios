-- Kurucu: "Beni kaydıranlar" ekranında öneri listesinde kartını X ile
-- kapatanlar da görünür ("kapattı"). Ayrı fonksiyon: who_swiped_me'ye
-- eklenseydi 1.1.2 bunları "sola kaydırdı" diye gösterirdi.
begin;

create or replace function public.who_dismissed_me()
returns table (id uuid, name text, avatar_path text, dismissed_at timestamptz, is_matched boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
  select p.id, p.name, p.avatar_path, d.created_at,
    exists (select 1 from public.matches m
            where m.user_a = least(p.id, auth.uid()) and m.user_b = greatest(p.id, auth.uid())
              and m.unmatched_at is null)
  from public.suggestion_dismissals d
  join public.profiles p on p.id = d.user_id
  where d.profile_id = auth.uid()
  order by d.created_at desc;
end;
$$;
revoke all on function public.who_dismissed_me() from public, anon;
grant execute on function public.who_dismissed_me() to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261009030000', 'who_dismissed_me')
on conflict (version) do nothing;

commit;
