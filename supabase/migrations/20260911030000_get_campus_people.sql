-- Campus directory replaces swipe discovery. Everyone sees everyone: no gender,
-- dating preference, or discovery_enabled gate. Blocks and ghost mode still hide.
begin;

create or replace function public.get_campus_people(
  page_limit integer default 20,
  page_offset integer default 0
)
returns table (
  id uuid,
  name text,
  birth_date date,
  university text,
  department text,
  academic_year text,
  bio text,
  avatar_path text,
  is_verified boolean,
  badge public.profile_badge,
  interests text[],
  visible_place_id uuid,
  visible_place_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.name,
    p.birth_date,
    p.university,
    p.department,
    p.academic_year,
    p.bio,
    p.avatar_path,
    p.is_verified,
    p.badge,
    coalesce((
      select array_agg(pi.interest order by pi.interest)
      from public.profile_interests pi
      where pi.profile_id = p.id
    ), '{}'::text[]),
    case when p.visible_until > now() then p.visible_place_id end,
    case when p.visible_until > now() then pl.name end
  from public.profiles p
  left join public.places pl on pl.id = p.visible_place_id
  where p.id is distinct from auth.uid()
    and p.is_active
    and p.is_verified
    and not coalesce(p.ghost_mode, false)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc nulls last, p.name
  limit greatest(1, least(coalesce(page_limit, 20), 50))
  offset greatest(0, coalesce(page_offset, 0));
$$;

revoke all on function public.get_campus_people(integer, integer) from public, anon;
grant execute on function public.get_campus_people(integer, integer) to authenticated;

commit;
