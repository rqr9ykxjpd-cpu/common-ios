-- Adds gallery photos to discovery candidates and a server-enforced block that also
-- severs any existing match. Forward-only; get_discovery_candidates is dropped and
-- recreated because its return signature gains a column (gallery_paths).

begin;

drop function if exists public.get_discovery_candidates(integer, integer);

create function public.get_discovery_candidates(page_limit integer default 20, page_offset integer default 0)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, gallery_paths text[], is_verified boolean,
  relationship_intent public.relationship_intent, interests text[],
  prompt_keys text[], prompt_answers text[], compatibility integer,
  compatibility_reasons text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  with me as (
    select p.*, coalesce(dp.min_age, 18) min_age, coalesce(dp.max_age, 99) max_age,
      coalesce(dp.academic_years, '{}') academic_years,
      coalesce(dp.departments, '{}') departments,
      coalesce(dp.require_common_interest, false) require_common_interest,
      coalesce(dp.campus_only, true) campus_only
    from public.profiles p
    left join public.discovery_preferences dp on dp.user_id = p.id
    where p.id = auth.uid()
  ), candidates as (
    select p.*,
      coalesce(array_agg(distinct pi.interest) filter (where pi.interest is not null), '{}') interests,
      count(distinct pi.interest) filter (
        where pi.interest in (select interest from public.profile_interests where profile_id = auth.uid())
      )::integer common_count
    from public.profiles p
    left join public.profile_interests pi on pi.profile_id = p.id
    cross join me
    where p.id <> auth.uid()
      and p.is_verified and p.is_active and p.discovery_enabled
      and extract(year from age(current_date, p.birth_date)) between me.min_age and me.max_age
      and (cardinality(me.academic_years) = 0 or p.academic_year = any(me.academic_years))
      and (cardinality(me.departments) = 0 or p.department = any(me.departments))
      and (not me.campus_only or p.university = me.university)
      and (me.dating_preference = 'everyone'
        or (me.dating_preference = 'women' and p.gender = 'female')
        or (me.dating_preference = 'men' and p.gender = 'male'))
      and (p.dating_preference = 'everyone'
        or (p.dating_preference = 'women' and me.gender = 'female')
        or (p.dating_preference = 'men' and me.gender = 'male'))
      and not exists (select 1 from public.reactions r where r.actor_id = auth.uid() and r.subject_id = p.id)
      and not exists (select 1 from public.matches m where m.unmatched_at is null and ((m.user_a = auth.uid() and m.user_b = p.id) or (m.user_b = auth.uid() and m.user_a = p.id)))
      and not exists (select 1 from public.blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    group by p.id, me.min_age, me.max_age, me.academic_years, me.departments, me.require_common_interest, me.campus_only, me.university, me.gender, me.dating_preference
    having not me.require_common_interest or count(distinct pi.interest) filter (
      where pi.interest in (select interest from public.profile_interests where profile_id = auth.uid())
    ) > 0
  )
  select c.id, c.name, c.birth_date, c.university, c.department, c.academic_year,
    c.bio, c.avatar_path,
    coalesce((select array_agg(pp.storage_path order by pp.position) from public.profile_photos pp where pp.profile_id = c.id), '{}'),
    c.is_verified, c.relationship_intent, c.interests,
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = c.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = c.id), '{}'),
    least(99, 55 + least(c.common_count * 10, 30)
      + case when c.relationship_intent = (select relationship_intent from me) then 8 else 0 end
      + case when c.academic_year = (select academic_year from me) then 5 else 0 end)::integer as compatibility_score,
    array_remove(array[
      case when c.common_count > 0 then c.common_count || ' ortak ilgi alanı' end,
      case when c.relationship_intent = (select relationship_intent from me) then 'Tanışma niyetiniz benzer' end,
      case when c.academic_year = (select academic_year from me) then 'Aynı sınıf düzeyi' end
    ], null),
    case when c.last_active_at > now() - interval '1 hour' then 'Yakın zamanda aktif'
         when c.last_active_at > now() - interval '1 day' then 'Bugün aktif'
         else 'Bu hafta aktif' end
  from candidates c
  order by compatibility_score desc, c.last_active_at desc, c.id
  limit greatest(1, least(page_limit, 50)) offset greatest(page_offset, 0);
$$;

revoke all on function public.get_discovery_candidates(integer, integer) from public, anon;
grant execute on function public.get_discovery_candidates(integer, integer) to authenticated;

-- Blocking someone also ends any live match with them so the conversation can't
-- reappear after a refresh; direct client writes to matches are not granted, so
-- this has to run as a security definer RPC.
create or replace function public.block_user(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or target = auth.uid() then raise exception 'Invalid target'; end if;
  insert into public.blocks(blocker_id, blocked_id) values (auth.uid(), target)
  on conflict (blocker_id, blocked_id) do nothing;
  update public.matches set unmatched_at = now()
  where unmatched_at is null
    and ((user_a = auth.uid() and user_b = target) or (user_a = target and user_b = auth.uid()));
end;
$$;

revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

commit;
