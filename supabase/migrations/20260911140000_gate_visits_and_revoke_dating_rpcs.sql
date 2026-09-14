-- Campus paywall: profile visitors are Plus+. Free clients already hide the
-- list, but get_my_profile_visits did not check the plan, so a free session
-- could still read it. Dating discovery RPCs remain in the schema for now
-- but must not stay callable.

begin;

create or replace function public.get_my_profile_visits()
returns table (
  visitor_id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge,
  visit_count integer, last_visited_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge, v.visit_count, v.last_visited_at
  from public.profile_visits v
  join public.profiles p on p.id = v.visitor_id
  where v.profile_id = auth.uid()
    and public.plan_of(auth.uid()) in ('plus', 'pro')
    and v.last_visited_at > now() - interval '7 days'
    and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by v.last_visited_at desc
  limit 50;
$$;

revoke all on function public.get_my_profile_visits() from public, anon;
grant execute on function public.get_my_profile_visits() to authenticated;

revoke all on function public.get_discovery_candidates(integer, integer) from public, anon, authenticated;
revoke all on function public.who_liked_me() from public, anon, authenticated;
revoke all on function public.react_to_profile(uuid, public.reaction_kind) from public, anon, authenticated;
revoke all on function public.reset_my_passes() from public, anon, authenticated;
revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon, authenticated;
revoke all on function public.enforce_like_quota() from public, anon, authenticated;

commit;
