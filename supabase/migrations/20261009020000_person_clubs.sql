-- Kişinin kartında üye olduğu kulüpler (en altta; dokununca kulüp sayfası).
-- Yalnızca açık kulüpler; engellediğin ya da seni engelleyen kişininki gelmez.
begin;

create or replace function public.person_clubs(target uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select cm.club_id
  from public.club_members cm
  join public.clubs c on c.id = cm.club_id and c.is_active
  join public.profiles p on p.id = cm.user_id and p.is_active
  where cm.user_id = target
    and auth.uid() is not null
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = target)
         or (b.blocker_id = target and b.blocked_id = auth.uid())
    )
  order by c.name;
$$;
revoke all on function public.person_clubs(uuid) from public, anon;
grant execute on function public.person_clubs(uuid) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261009020000', 'person_clubs')
on conflict (version) do nothing;

commit;
