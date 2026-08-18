-- Forward-only hardening for databases that already applied the unified backend.
-- No user tables or data are dropped.

begin;

revoke select on public.profiles from authenticated;
grant select (
  id, name, birth_date, university, university_domain, department, academic_year,
  bio, avatar_path, is_verified, is_active, discovery_enabled, last_active_at,
  created_at, updated_at
) on public.profiles to authenticated;

create or replace function public.can_read_media(owner_uuid uuid, media_bucket text, media_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select owner_uuid = auth.uid()
    or (
      exists (
        select 1 from public.profiles reader
        where reader.id = auth.uid() and reader.is_verified and reader.is_active
      )
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = owner_uuid)
           or (b.blocker_id = owner_uuid and b.blocked_id = auth.uid())
      )
      and (
        (media_bucket = 'post-media' and exists (
          select 1 from public.posts p where p.author_id = owner_uuid and p.media_path = media_name
        ))
        or (media_bucket = 'profile-photos' and exists (
          select 1 from public.profiles p
          where p.id = owner_uuid
            and (p.avatar_path = media_name or exists (
              select 1 from public.profile_photos photo
              where photo.profile_id = owner_uuid and photo.storage_path = media_name
            ))
        ))
      )
      and (
        media_bucket = 'post-media'
        or exists (
          select 1 from public.profiles p
          where p.id = owner_uuid and p.is_verified and p.is_active and p.discovery_enabled
        )
        or exists (
          select 1 from public.matches m
          where m.unmatched_at is null
            and ((m.user_a = auth.uid() and m.user_b = owner_uuid)
              or (m.user_b = auth.uid() and m.user_a = owner_uuid))
        )
      )
    );
$$;

revoke all on function public.can_read_media(uuid, text, text) from public, anon;
grant execute on function public.can_read_media(uuid, text, text) to authenticated;

drop policy if exists "authenticated users read common media" on storage.objects;
drop policy if exists "verified members read media" on storage.objects;
drop policy if exists "users read own media" on storage.objects;
create policy "members read permitted media" on storage.objects
for select to authenticated using (
  bucket_id in ('profile-photos', 'post-media')
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and public.can_read_media(((storage.foldername(name))[1])::uuid, bucket_id, name)
);

create or replace function public.save_my_profile(
  profile_name text, profile_birth_date date, profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent, profile_university text,
  profile_department text, profile_academic_year text, profile_bio text,
  profile_interests text[], profile_prompts jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  prompt jsonb;
  prompt_position integer := 0;
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;
  if jsonb_array_length(profile_prompts) <> 3 then raise exception 'Exactly three prompts are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, discovery_enabled
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio, discovery_enabled = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;
  delete from public.profile_prompts where profile_id = account_id;
  for prompt in select value from jsonb_array_elements(profile_prompts)
  loop
    if char_length(btrim(prompt->>'answer')) = 0 then raise exception 'Prompt answers cannot be empty'; end if;
    insert into public.profile_prompts(profile_id, prompt_key, answer, position)
    values (account_id, prompt->>'prompt_key', btrim(prompt->>'answer'), prompt_position);
    prompt_position := prompt_position + 1;
  end loop;
end;
$$;

create or replace function public.set_message_reaction(message_uuid uuid, reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  requested_reaction text := reaction;
begin
  if requested_reaction is not null and char_length(requested_reaction) > 16 then raise exception 'Reaction is too long'; end if;
  update public.messages m set reaction = requested_reaction
  where m.id = message_uuid and public.is_match_member(m.match_id);
  if not found then raise exception 'Message unavailable'; end if;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) from public, anon;
revoke all on function public.set_message_reaction(uuid, text) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) to authenticated;
grant execute on function public.set_message_reaction(uuid, text) to authenticated;

-- Serialize reactions per unordered user pair so concurrent mutual likes cannot miss.
create or replace function public.react_to_profile(subject uuid, reaction public.reaction_kind)
returns table (matched boolean, match_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  created_match uuid;
  first_user uuid;
  second_user uuid;
  previous_unmatched_at timestamptz;
begin
  if auth.uid() is null or subject = auth.uid() then raise exception 'Invalid reaction'; end if;
  first_user := least(auth.uid(), subject);
  second_user := greatest(auth.uid(), subject);
  perform pg_advisory_xact_lock(hashtextextended(first_user::text || ':' || second_user::text, 0));

  if not exists (
    select 1 from public.profiles me
    join public.profiles candidate on candidate.id = subject
    left join public.discovery_preferences dp on dp.user_id = me.id
    where me.id = auth.uid() and candidate.is_active and candidate.is_verified and candidate.discovery_enabled
      and extract(year from age(current_date, candidate.birth_date)) between coalesce(dp.min_age, 18) and coalesce(dp.max_age, 99)
      and (coalesce(cardinality(dp.academic_years), 0) = 0 or candidate.academic_year = any(dp.academic_years))
      and (coalesce(cardinality(dp.departments), 0) = 0 or candidate.department = any(dp.departments))
      and (not coalesce(dp.campus_only, true) or candidate.university = me.university)
      and (me.dating_preference = 'everyone' or (me.dating_preference = 'women' and candidate.gender = 'female') or (me.dating_preference = 'men' and candidate.gender = 'male'))
      and (candidate.dating_preference = 'everyone' or (candidate.dating_preference = 'women' and me.gender = 'female') or (candidate.dating_preference = 'men' and me.gender = 'male'))
      and (not coalesce(dp.require_common_interest, false) or exists (
        select 1 from public.profile_interests mine
        join public.profile_interests theirs on theirs.interest = mine.interest
        where mine.profile_id = auth.uid() and theirs.profile_id = subject
      ))
  ) then raise exception 'Profile unavailable'; end if;
  if exists (select 1 from public.blocks where (blocker_id = auth.uid() and blocked_id = subject) or (blocker_id = subject and blocked_id = auth.uid())) then raise exception 'Profile unavailable'; end if;

  select unmatched_at into previous_unmatched_at from public.matches
  where user_a = first_user and user_b = second_user;
  insert into public.reactions(actor_id, subject_id, kind) values (auth.uid(), subject, reaction)
  on conflict (actor_id, subject_id) do update set kind = excluded.kind, updated_at = now();

  if reaction = 'like' and exists (
    select 1 from public.reactions where actor_id = subject and subject_id = auth.uid() and kind = 'like'
      and (previous_unmatched_at is null or updated_at > previous_unmatched_at)
  ) then
    insert into public.matches(user_a, user_b) values (first_user, second_user)
    on conflict (user_a, user_b) do update set unmatched_at = null returning id into created_match;
    return query select true, created_match;
  end if;
  return query select false, null::uuid;
end;
$$;

commit;
