-- Common: EMPTY PROJECT ONLY. Atomic installation, no existing app data allowed.
begin;
do $$ begin
 if exists(select 1 from pg_tables where schemaname='public') then
  raise exception 'Refusing bootstrap: public schema is not empty';
 end if;
end $$;

-- Migration: 20260817133000_common_unified_backend.sql

create extension if not exists pgcrypto;

create type public.profile_gender as enum ('female', 'male');
create type public.dating_preference as enum ('women', 'men', 'everyone');
create type public.relationship_intent as enum ('friendship', 'dating', 'both');
create type public.reaction_kind as enum ('pass', 'like');
create type public.report_reason as enum ('spam', 'harassment', 'impersonation', 'underage', 'other');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  birth_date date not null check (birth_date <= (current_date - interval '18 years')::date),
  gender public.profile_gender not null,
  dating_preference public.dating_preference not null,
  relationship_intent public.relationship_intent not null default 'both',
  university text not null check (char_length(btrim(university)) between 1 and 120),
  university_domain text not null default 'yalova.edu.tr',
  department text not null check (char_length(btrim(department)) between 1 and 120),
  academic_year text not null check (char_length(btrim(academic_year)) between 1 and 40),
  bio text not null default '' check (char_length(bio) <= 500),
  avatar_path text,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  discovery_enabled boolean not null default false,
  last_active_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint avatar_owned_path check (avatar_path is null or avatar_path like id::text || '/%')
);

create table public.profile_interests (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  interest text not null check (char_length(btrim(interest)) between 1 and 40),
  created_at timestamptz not null default now(),
  primary key (profile_id, interest)
);

create table public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  position smallint not null check (position between 0 and 4),
  created_at timestamptz not null default now(),
  unique (profile_id, position),
  constraint photo_owned_path check (storage_path like profile_id::text || '/%')
);

create table public.profile_prompts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  prompt_key text not null check (char_length(prompt_key) between 1 and 60),
  answer text not null check (char_length(btrim(answer)) between 1 and 220),
  position smallint not null check (position between 0 and 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, position),
  unique (profile_id, prompt_key)
);

create table public.discovery_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  min_age smallint not null default 18 check (min_age between 18 and 99),
  max_age smallint not null default 30 check (max_age between 18 and 99 and max_age >= min_age),
  academic_years text[] not null default '{}',
  departments text[] not null default '{}',
  require_common_interest boolean not null default false,
  campus_only boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.reactions (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  kind public.reaction_kind not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (actor_id, subject_id),
  check (actor_id <> subject_id)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unmatched_at timestamptz,
  check (user_a < user_b),
  unique (user_a, user_b)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  reply_to_id uuid references public.messages(id) on delete set null,
  reaction text check (reaction is null or char_length(reaction) <= 16),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  reason public.report_reason not null,
  details text check (details is null or char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  caption text not null default '' check (char_length(caption) <= 2200),
  media_path text,
  place_name text check (place_name is null or char_length(btrim(place_name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint post_has_content check (char_length(btrim(caption)) > 0 or media_path is not null),
  constraint post_media_owned_path check (media_path is null or media_path like author_id::text || '/%')
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_discovery_idx on public.profiles (discovery_enabled, is_verified, is_active);
create index reactions_subject_like_idx on public.reactions (subject_id, actor_id) where kind = 'like';
create index matches_user_a_idx on public.matches (user_a, created_at desc);
create index matches_user_b_idx on public.matches (user_b, created_at desc);
create index messages_match_created_idx on public.messages (match_id, created_at);
create index posts_created_at_idx on public.posts (created_at desc);
create index comments_post_created_at_idx on public.comments (post_id, created_at);

create or replace function public.validate_message_reply()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.reply_to_id is not null and not exists (
    select 1 from public.messages replied
    where replied.id = new.reply_to_id and replied.match_id = new.match_id
  ) then
    raise exception 'Reply must belong to the same match';
  end if;
  return new;
end;
$$;

create trigger messages_validate_reply before insert or update of reply_to_id, match_id on public.messages
for each row execute function public.validate_message_reply();

create or replace function public.validate_profile_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  account_email text;
begin
  select email into account_email from auth.users where id = new.id;
  if account_email is null or lower(split_part(account_email, '@', 2)) <> lower(new.university_domain) then
    raise exception 'A verified university email is required';
  end if;
  new.is_verified := true;
  return new;
end;
$$;

create trigger profiles_validate_membership before insert or update of university_domain on public.profiles
for each row execute function public.validate_profile_membership();

create or replace function public.cleanup_post_media()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.media_path is not null then
    delete from storage.objects where bucket_id = 'post-media' and name = old.media_path;
  end if;
  return old;
end;
$$;

create trigger posts_cleanup_media after delete on public.posts
for each row execute function public.cleanup_post_media();

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  delete from storage.objects
  where bucket_id in ('profile-photos', 'post-media')
    and (storage.foldername(name))[1] = account_id::text;
  delete from auth.users where id = account_id;
end;
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger prompts_set_updated_at before update on public.profile_prompts
for each row execute function public.set_updated_at();
create trigger preferences_set_updated_at before update on public.discovery_preferences
for each row execute function public.set_updated_at();
create trigger reactions_set_updated_at before update on public.reactions
for each row execute function public.set_updated_at();
create trigger posts_set_updated_at before update on public.posts
for each row execute function public.set_updated_at();
create trigger comments_set_updated_at before update on public.comments
for each row execute function public.set_updated_at();

create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[],
  profile_prompts jsonb
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
  )
  on conflict (id) do update set
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

create or replace function public.is_match_member(match_uuid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.matches
    where id = match_uuid
      and unmatched_at is null
      and (user_a = auth.uid() or user_b = auth.uid())
  );
$$;

create or replace function public.set_message_reaction(message_uuid uuid, reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  requested_reaction text := reaction;
begin
  if requested_reaction is not null and char_length(requested_reaction) > 16 then raise exception 'Reaction is too long'; end if;
  update public.messages m
  set reaction = requested_reaction
  where m.id = message_uuid and public.is_match_member(m.match_id);
  if not found then raise exception 'Message unavailable'; end if;
end;
$$;

create or replace function public.get_discovery_candidates(page_limit integer default 20, page_offset integer default 0)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
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
    c.bio, c.avatar_path, c.is_verified, c.relationship_intent, c.interests,
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
    select 1
    from public.profiles me
    join public.profiles candidate on candidate.id = subject
    left join public.discovery_preferences dp on dp.user_id = me.id
    where me.id = auth.uid()
      and candidate.is_active and candidate.is_verified and candidate.discovery_enabled
      and extract(year from age(current_date, candidate.birth_date)) between coalesce(dp.min_age, 18) and coalesce(dp.max_age, 99)
      and (coalesce(cardinality(dp.academic_years), 0) = 0 or candidate.academic_year = any(dp.academic_years))
      and (coalesce(cardinality(dp.departments), 0) = 0 or candidate.department = any(dp.departments))
      and (not coalesce(dp.campus_only, true) or candidate.university = me.university)
      and (me.dating_preference = 'everyone'
        or (me.dating_preference = 'women' and candidate.gender = 'female')
        or (me.dating_preference = 'men' and candidate.gender = 'male'))
      and (candidate.dating_preference = 'everyone'
        or (candidate.dating_preference = 'women' and me.gender = 'female')
        or (candidate.dating_preference = 'men' and me.gender = 'male'))
      and (not coalesce(dp.require_common_interest, false) or exists (
        select 1 from public.profile_interests mine
        join public.profile_interests theirs on theirs.interest = mine.interest
        where mine.profile_id = auth.uid() and theirs.profile_id = subject
      ))
  ) then raise exception 'Profile unavailable'; end if;
  if exists (select 1 from public.blocks where (blocker_id = auth.uid() and blocked_id = subject) or (blocker_id = subject and blocked_id = auth.uid())) then raise exception 'Profile unavailable'; end if;

  select unmatched_at into previous_unmatched_at
  from public.matches where user_a = first_user and user_b = second_user;

  insert into public.reactions(actor_id, subject_id, kind)
  values (auth.uid(), subject, reaction)
  on conflict (actor_id, subject_id) do update set kind = excluded.kind, updated_at = now();

  if reaction = 'like' and exists (
    select 1 from public.reactions
    where actor_id = subject and subject_id = auth.uid() and kind = 'like'
      and (previous_unmatched_at is null or updated_at > previous_unmatched_at)
  ) then
    insert into public.matches(user_a, user_b) values (first_user, second_user)
    on conflict (user_a, user_b) do update set unmatched_at = null
    returning id into created_match;
    return query select true, created_match;
  else
    return query select false, null::uuid;
  end if;
end;
$$;

alter table public.profiles enable row level security;
alter table public.profile_interests enable row level security;
alter table public.profile_photos enable row level security;
alter table public.profile_prompts enable row level security;
alter table public.discovery_preferences enable row level security;
alter table public.reactions enable row level security;
alter table public.matches enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;

create policy "users view relevant profiles" on public.profiles for select to authenticated using (
  id = auth.uid()
  or exists (
    select 1 from public.matches m
    where m.unmatched_at is null
      and ((m.user_a = auth.uid() and m.user_b = profiles.id) or (m.user_b = auth.uid() and m.user_a = profiles.id))
  )
  or exists (select 1 from public.posts p where p.author_id = profiles.id)
);
create policy "users insert own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "users update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "users delete own profile" on public.profiles for delete to authenticated using (id = auth.uid());

create policy "interests follow visible profiles" on public.profile_interests for select to authenticated using (exists (select 1 from public.profiles p where p.id = profile_id));
create policy "users manage own interests" on public.profile_interests for all to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "photos follow visible profiles" on public.profile_photos for select to authenticated using (exists (select 1 from public.profiles p where p.id = profile_id));
create policy "users manage own photos" on public.profile_photos for all to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "prompts follow visible profiles" on public.profile_prompts for select to authenticated using (exists (select 1 from public.profiles p where p.id = profile_id));
create policy "users manage own prompts" on public.profile_prompts for all to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "users manage own discovery preferences" on public.discovery_preferences for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users read own reactions" on public.reactions for select to authenticated using (actor_id = auth.uid());
create policy "members read matches" on public.matches for select to authenticated using (user_a = auth.uid() or user_b = auth.uid());
create policy "members read messages" on public.messages for select to authenticated using (public.is_match_member(match_id));
create policy "members send as themselves" on public.messages for insert to authenticated with check (sender_id = auth.uid() and public.is_match_member(match_id));
create policy "recipients mark messages read" on public.messages for update to authenticated using (public.is_match_member(match_id) and sender_id <> auth.uid()) with check (public.is_match_member(match_id));
create policy "users manage own blocks" on public.blocks for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy "users create reports" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "users see own reports" on public.reports for select to authenticated using (reporter_id = auth.uid());
create policy "authenticated users view posts" on public.posts for select to authenticated using (true);
create policy "users manage own posts" on public.posts for all to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "authenticated users view comments" on public.comments for select to authenticated using (true);
create policy "users create own comments" on public.comments for insert to authenticated with check (author_id = auth.uid());
create policy "users update own comments" on public.comments for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "authors and post owners delete comments" on public.comments for delete to authenticated using (
  author_id = auth.uid() or exists (select 1 from public.posts where posts.id = comments.post_id and posts.author_id = auth.uid())
);

revoke all on public.profiles, public.profile_interests, public.profile_photos, public.profile_prompts,
  public.discovery_preferences, public.reactions, public.matches, public.messages, public.blocks,
  public.reports, public.posts, public.comments from anon;
grant select, insert, update, delete on public.profiles, public.profile_interests, public.profile_photos,
  public.profile_prompts, public.discovery_preferences, public.blocks, public.posts, public.comments to authenticated;
grant select on public.reactions, public.matches to authenticated;
grant select, insert on public.messages to authenticated;
grant update (read_at) on public.messages to authenticated;
grant select, insert on public.reports to authenticated;
revoke all on function public.is_match_member(uuid) from public, anon;
revoke all on function public.get_discovery_candidates(integer, integer) from public, anon;
revoke all on function public.react_to_profile(uuid, public.reaction_kind) from public, anon;
revoke all on function public.delete_my_account() from public, anon;
revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) from public, anon;
revoke all on function public.set_message_reaction(uuid, text) from public, anon;
grant execute on function public.is_match_member(uuid) to authenticated;
grant execute on function public.get_discovery_candidates(integer, integer) to authenticated;
grant execute on function public.react_to_profile(uuid, public.reaction_kind) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) to authenticated;
grant execute on function public.set_message_reaction(uuid, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('profile-photos', 'profile-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('post-media', 'post-media', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "authenticated users read common media" on storage.objects for select to authenticated using (bucket_id in ('profile-photos', 'post-media'));
create policy "users upload to own media folder" on storage.objects for insert to authenticated with check (bucket_id in ('profile-photos', 'post-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users update own media folder" on storage.objects for update to authenticated using (bucket_id in ('profile-photos', 'post-media') and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id in ('profile-photos', 'post-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users delete own media folder" on storage.objects for delete to authenticated using (bucket_id in ('profile-photos', 'post-media') and (storage.foldername(name))[1] = auth.uid()::text);


-- Migration: 20260817190000_tighten_privacy.sql
-- Forward-only hardening for databases that already applied the unified backend.
-- No user tables or data are dropped.

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


-- Migration: 20260817200000_photos_and_safety.sql
-- Adds gallery photos to discovery candidates and a server-enforced block that also
-- severs any existing match. Forward-only; get_discovery_candidates is dropped and
-- recreated because its return signature gains a column (gallery_paths).

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


-- Migration: 20260817210000_realtime_messages_and_likes.sql
-- Turns on live message delivery and makes post likes persist server-side.
-- Forward-only; safe to re-run.

-- Postgres Changes only pushes rows the subscribing role could already SELECT
-- (RLS on public.messages already restricts that to `is_match_member`), so this
-- just turns replication on for the table — it doesn't widen who can read what.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_likes enable row level security;

drop policy if exists "authenticated users view post likes" on public.post_likes;
create policy "authenticated users view post likes" on public.post_likes
for select to authenticated using (true);

drop policy if exists "users manage own likes" on public.post_likes;
create policy "users manage own likes" on public.post_likes
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.post_likes from anon;
grant select, insert, delete on public.post_likes to authenticated;


-- Migration: 20260818090000_get_my_profile.sql
-- Kullanıcının kendi profilini eksiksiz okuması için RPC.
--
-- `tighten_privacy` migration'ı public.profiles üzerindeki genel SELECT yetkisini kaldırıp
-- yalnızca hassas olmayan sütunlara kolon bazlı yetki verdi; gender / dating_preference /
-- relationship_intent bilerek dışarıda bırakıldı. Bu yüzden kullanıcı kendi bu alanlarını da
-- doğrudan sorgulayamıyor. Security definer RPC, başkalarının alanlarını açmadan yalnızca
-- auth.uid()'in kendi kaydını döndürür.
--
-- Forward-only; tekrar çalıştırılabilir.

create or replace function public.get_my_profile()
returns table (
  name text,
  birth_date date,
  gender public.profile_gender,
  dating_preference public.dating_preference,
  relationship_intent public.relationship_intent,
  university text,
  department text,
  academic_year text,
  bio text,
  interests text[],
  prompt_keys text[],
  prompt_answers text[],
  min_age smallint,
  max_age smallint,
  academic_years text[],
  departments text[],
  require_common_interest boolean,
  campus_only boolean
)
language sql stable security definer set search_path = '' as $$
  select
    p.name, p.birth_date, p.gender, p.dating_preference, p.relationship_intent,
    p.university, p.department, p.academic_year, p.bio,
    coalesce((select array_agg(pi.interest order by pi.interest) from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce(dp.min_age, 18::smallint),
    coalesce(dp.max_age, 30::smallint),
    coalesce(dp.academic_years, '{}'),
    coalesce(dp.departments, '{}'),
    coalesce(dp.require_common_interest, false),
    coalesce(dp.campus_only, true)
  from public.profiles p
  left join public.discovery_preferences dp on dp.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;


-- Migration: 20260818100000_notifications.sql
-- Uygulama içi bildirimler. Bu ekran şimdiye kadar yalnızca demo örneklerinden besleniyordu;
-- gerçek kullanıcı eşleşme, mesaj, yorum veya beğeni aldığında hiçbir iz kalmıyordu.
--
-- Bildirimleri istemci oluşturmaz: hepsi veritabanı trigger'larıyla üretilir. Aksi halde
-- istemci başkasının adına bildirim yazabilirdi ve içerik uydurulabilirdi.
--
-- Forward-only; tekrar çalıştırılabilir.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'notification_kind') then
    create type public.notification_kind as enum ('like', 'comment', 'match', 'message', 'club', 'meeting_request');
  end if;
end $$;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind public.notification_kind not null,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  body text not null default '' check (char_length(body) <= 500),
  actor_id uuid references public.profiles(id) on delete cascade,
  match_id uuid references public.matches(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint no_self_notification check (actor_id is null or actor_id <> user_id)
);

create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_user_unread_idx on public.notifications (user_id) where not is_read;

alter table public.notifications enable row level security;

drop policy if exists "users read own notifications" on public.notifications;
create policy "users read own notifications" on public.notifications
for select to authenticated using (user_id = auth.uid());

drop policy if exists "users mark own notifications read" on public.notifications;
create policy "users mark own notifications read" on public.notifications
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "users delete own notifications" on public.notifications;
create policy "users delete own notifications" on public.notifications
for delete to authenticated using (user_id = auth.uid());

revoke all on public.notifications from anon, authenticated;
grant select, delete on public.notifications to authenticated;
-- Yalnızca okundu işareti güncellenebilir; başlık/gövde istemciden değiştirilemez.
grant update (is_read) on public.notifications to authenticated;

-- Push bildirimi için cihaz jetonları. Gönderim APNs üzerinden bir Edge Function ile
-- yapılacak; tablo şimdiden burada olsun ki istemci tarafı ona göre kurulabilsin.
create table if not exists public.device_tokens (
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'ios' check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.device_tokens enable row level security;

drop policy if exists "users manage own device tokens" on public.device_tokens;
create policy "users manage own device tokens" on public.device_tokens
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.device_tokens from anon;
grant select, insert, update, delete on public.device_tokens to authenticated;

create or replace function public.profile_display_name(profile_uuid uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((select name from public.profiles where id = profile_uuid), 'Biri');
$$;

-- Eşleşme: iki tarafa da bildirim.
create or replace function public.notify_on_match()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.unmatched_at is not null then return new; end if;
  insert into public.notifications (user_id, kind, title, body, actor_id, match_id)
  values
    (new.user_a, 'match', 'Yeni bir eşleşme',
     'Sen ve ' || public.profile_display_name(new.user_b) || ' birbirinizi beğendiniz.', new.user_b, new.id),
    (new.user_b, 'match', 'Yeni bir eşleşme',
     'Sen ve ' || public.profile_display_name(new.user_a) || ' birbirinizi beğendiniz.', new.user_a, new.id);
  return new;
end;
$$;

drop trigger if exists matches_notify on public.matches;
create trigger matches_notify after insert on public.matches
for each row execute function public.notify_on_match();

-- Mesaj: karşı tarafa bildirim. Aynı sohbet için okunmamış bildirim varsa yenisi
-- eklenmez — aksi halde hızlı yazışmada bildirim listesi tek sohbetle dolar.
create or replace function public.notify_on_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  recipient uuid;
begin
  select case when m.user_a = new.sender_id then m.user_b else m.user_a end
  into recipient from public.matches m where m.id = new.match_id;
  if recipient is null then return new; end if;

  if exists (
    select 1 from public.notifications n
    where n.user_id = recipient and n.kind = 'message' and n.match_id = new.match_id and not n.is_read
  ) then
    update public.notifications
    set body = left(new.body, 140), created_at = now()
    where user_id = recipient and kind = 'message' and match_id = new.match_id and not is_read;
    return new;
  end if;

  insert into public.notifications (user_id, kind, title, body, actor_id, match_id)
  values (recipient, 'message',
    public.profile_display_name(new.sender_id) || ' sana mesaj gönderdi',
    left(new.body, 140), new.sender_id, new.match_id);
  return new;
end;
$$;

drop trigger if exists messages_notify on public.messages;
create trigger messages_notify after insert on public.messages
for each row execute function public.notify_on_message();

-- Yorum: gönderi sahibine bildirim (kendi gönderisine yorum yaparsa atlanır).
create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is null or owner_id = new.author_id then return new; end if;
  insert into public.notifications (user_id, kind, title, body, actor_id, post_id)
  values (owner_id, 'comment',
    public.profile_display_name(new.author_id) || ' yorum yaptı',
    left(new.body, 140), new.author_id, new.post_id);
  return new;
end;
$$;

drop trigger if exists comments_notify on public.comments;
create trigger comments_notify after insert on public.comments
for each row execute function public.notify_on_comment();

-- Beğeni: gönderi sahibine bildirim (kendi beğenisi atlanır, tekrar beğenide çoğalmaz).
create or replace function public.notify_on_post_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  if exists (
    select 1 from public.notifications n
    where n.user_id = owner_id and n.kind = 'like' and n.post_id = new.post_id and n.actor_id = new.user_id
  ) then
    return new;
  end if;
  insert into public.notifications (user_id, kind, title, body, actor_id, post_id)
  values (owner_id, 'like',
    public.profile_display_name(new.user_id) || ' gönderini beğendi', '', new.user_id, new.post_id);
  return new;
end;
$$;

drop trigger if exists post_likes_notify on public.post_likes;
create trigger post_likes_notify after insert on public.post_likes
for each row execute function public.notify_on_post_like();

revoke all on function public.profile_display_name(uuid) from public, anon;

-- Bildirimler anlık düşsün.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;


-- Migration: 20260818120000_places_clubs_stories_meetings.sql
-- Story'ler, buluşma istekleri, kulüpler ve kampüs yerleri.
--
-- Bunların hiçbirinin tablosu yoktu: hepsi yalnızca uygulamanın belleğinde yaşıyor,
-- uygulama kapanınca kayboluyordu. Kulüpler ve yerler ise kodda sabit listeydi, yani
-- herkese aynı görünüyor ve yönetilemiyordu.
--
-- Bu dosya baştan idempotent yazıldı; tekrar çalıştırmak güvenlidir.

-- ---------------------------------------------------------------- yerler

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(btrim(name)) between 1 and 120),
  area text not null default '' check (char_length(area) <= 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.places enable row level security;
drop policy if exists "authenticated read places" on public.places;
create policy "authenticated read places" on public.places
for select to authenticated using (is_active);

revoke all on public.places from anon;
grant select on public.places to authenticated;

insert into public.places (name, area) values
  ('Hazırlık Kantini', 'YÜ'),
  ('Şamdan Kafe', 'Yalova'),
  ('Otağ', 'Merkez Kampüs'),
  ('İİBF', 'Merkez Kampüs'),
  ('Merkez Kütüphane', 'Merkez Kampüs')
on conflict (name) do nothing;

-- ---------------------------------------------------------------- kulüpler

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(btrim(name)) between 1 and 120),
  summary text not null default '' check (char_length(summary) <= 400),
  icon text not null default 'person.3.fill',
  next_event text not null default '' check (char_length(next_event) <= 160),
  place_id uuid references public.places(id) on delete set null,
  accent_hex text not null default '7C5CFF' check (accent_hex ~ '^[0-9A-Fa-f]{6}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.club_members (
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

alter table public.clubs enable row level security;
alter table public.club_members enable row level security;

drop policy if exists "authenticated read clubs" on public.clubs;
create policy "authenticated read clubs" on public.clubs
for select to authenticated using (is_active);

drop policy if exists "authenticated read club members" on public.club_members;
create policy "authenticated read club members" on public.club_members
for select to authenticated using (true);

drop policy if exists "users manage own club membership" on public.club_members;
create policy "users manage own club membership" on public.club_members
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.clubs, public.club_members from anon;
grant select on public.clubs to authenticated;
grant select, insert, delete on public.club_members to authenticated;

insert into public.clubs (name, summary, icon, next_event, place_id, accent_hex)
select v.name, v.summary, v.icon, v.next_event, p.id, v.accent_hex
from (values
  ('Sürdürülebilirlik Kulübü', 'Kampüste geri dönüşüm ve iklim çalışmaları.', 'leaf.fill', 'Çarşamba · 17.30 · Otağ', 'Otağ', '34C77B'),
  ('Fotoğraf Topluluğu', 'Haftalık kampüs yürüyüşleri ve karanlık oda.', 'camera.fill', 'Cuma · 16.00 · İİBF', 'İİBF', '7C5CFF')
) as v(name, summary, icon, next_event, place_name, accent_hex)
left join public.places p on p.name = v.place_name
on conflict (name) do nothing;

-- ---------------------------------------------------------------- story'ler

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  media_path text not null,
  caption text not null default '' check (char_length(caption) <= 280),
  place_id uuid references public.places(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  constraint story_media_owned_path check (media_path like author_id::text || '/%')
);

create index if not exists stories_active_idx on public.stories (expires_at desc, created_at desc);

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  view_count integer not null default 1 check (view_count > 0),
  last_viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

alter table public.stories enable row level security;
alter table public.story_views enable row level security;

-- Süresi dolmuş story'ler kimseye görünmez; silme işini ayrıca zamanlamaya gerek kalmıyor.
drop policy if exists "authenticated read active stories" on public.stories;
create policy "authenticated read active stories" on public.stories
for select to authenticated using (
  expires_at > now()
  and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = stories.author_id)
       or (b.blocker_id = stories.author_id and b.blocked_id = auth.uid())
  )
);

drop policy if exists "users manage own stories" on public.stories;
create policy "users manage own stories" on public.stories
for all to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());

-- Story sahibi kimlerin izlediğini görür; izleyen yalnızca kendi kaydını yazar.
drop policy if exists "story owner reads views" on public.story_views;
create policy "story owner reads views" on public.story_views
for select to authenticated using (
  viewer_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_views.story_id and s.author_id = auth.uid())
);

drop policy if exists "viewers record own views" on public.story_views;
create policy "viewers record own views" on public.story_views
for all to authenticated using (viewer_id = auth.uid()) with check (viewer_id = auth.uid());

revoke all on public.stories, public.story_views from anon;
grant select, insert, delete on public.stories to authenticated;
grant select, insert, update, delete on public.story_views to authenticated;

-- ---------------------------------------------------------------- buluşma istekleri

do $$
begin
  if not exists (select 1 from pg_type where typname = 'meeting_request_status') then
    create type public.meeting_request_status as enum ('pending', 'accepted', 'declined');
  end if;
end $$;

create table if not exists public.meeting_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  status public.meeting_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> recipient_id)
);

-- Aynı kişiye aynı yer için birden fazla bekleyen istek gönderilemez.
create unique index if not exists meeting_requests_pending_idx
  on public.meeting_requests (requester_id, recipient_id, place_id)
  where status = 'pending';

create index if not exists meeting_requests_recipient_idx on public.meeting_requests (recipient_id, created_at desc);

alter table public.meeting_requests enable row level security;

drop policy if exists "members read meeting requests" on public.meeting_requests;
create policy "members read meeting requests" on public.meeting_requests
for select to authenticated using (requester_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "users send meeting requests" on public.meeting_requests;
create policy "users send meeting requests" on public.meeting_requests
for insert to authenticated with check (
  requester_id = auth.uid()
  and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = recipient_id)
       or (b.blocker_id = recipient_id and b.blocked_id = auth.uid())
  )
);

-- Yalnızca alıcı yanıtlayabilir; gönderen kendi isteğini kabul edemez.
drop policy if exists "recipients answer meeting requests" on public.meeting_requests;
create policy "recipients answer meeting requests" on public.meeting_requests
for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

drop policy if exists "requesters cancel meeting requests" on public.meeting_requests;
create policy "requesters cancel meeting requests" on public.meeting_requests
for delete to authenticated using (requester_id = auth.uid());

revoke all on public.meeting_requests from anon;
grant select, insert, delete on public.meeting_requests to authenticated;
grant update (status) on public.meeting_requests to authenticated;

drop trigger if exists meeting_requests_set_updated_at on public.meeting_requests;
create trigger meeting_requests_set_updated_at before update on public.meeting_requests
for each row execute function public.set_updated_at();

-- Buluşma isteği geldiğinde bildirim.
create or replace function public.notify_on_meeting_request()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  place_label text;
begin
  select name into place_label from public.places where id = new.place_id;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (new.recipient_id, 'meeting_request',
    public.profile_display_name(new.requester_id) || ' buluşmak istiyor',
    coalesce(place_label, 'Kampüs') || ' için gönderilen isteği yanıtla.',
    new.requester_id);
  return new;
end;
$$;

drop trigger if exists meeting_requests_notify on public.meeting_requests;
create trigger meeting_requests_notify after insert on public.meeting_requests
for each row execute function public.notify_on_meeting_request();

-- ---------------------------------------------------------------- story medyası

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('story-media', 'story-media', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Story medyası, süresi dolmamış ve engellenmemiş story'ler için okunabilir.
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
        or (media_bucket = 'story-media' and exists (
          select 1 from public.stories s
          where s.author_id = owner_uuid and s.media_path = media_name and s.expires_at > now()
        ))
        or (media_bucket = 'profile-photos' and exists (
          select 1 from public.profiles p
          where p.id = owner_uuid and p.is_verified and p.is_active and p.discovery_enabled
        ))
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

drop policy if exists "members read permitted media" on storage.objects;
create policy "members read permitted media" on storage.objects
for select to authenticated using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_read_media(((storage.foldername(name))[1])::uuid, bucket_id, name)
);

drop policy if exists "users upload to own media folder" on storage.objects;
create policy "users upload to own media folder" on storage.objects
for insert to authenticated with check (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users update own media folder" on storage.objects;
create policy "users update own media folder" on storage.objects
for update to authenticated using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] = auth.uid()::text
) with check (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users delete own media folder" on storage.objects;
create policy "users delete own media folder" on storage.objects
for delete to authenticated using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Story silinince medyası da gitsin.
create or replace function public.cleanup_story_media()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from storage.objects where bucket_id = 'story-media' and name = old.media_path;
  return old;
end;
$$;

drop trigger if exists stories_cleanup_media on public.stories;
create trigger stories_cleanup_media after delete on public.stories
for each row execute function public.cleanup_story_media();

-- Hesap silinince story medyası da temizlensin.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  delete from storage.objects
  where bucket_id in ('profile-photos', 'post-media', 'story-media')
    and (storage.foldername(name))[1] = account_id::text;
  delete from auth.users where id = account_id;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------- aktiflik

-- "Bugün aktif / Yakın zamanda aktif" etiketi last_active_at'e bakıyordu ama bu alan
-- hiçbir yerde güncellenmiyordu; herkes için sürekli "Bu hafta aktif" görünüyordu.
create or replace function public.touch_last_active()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  update public.profiles set last_active_at = now()
  where id = auth.uid() and last_active_at < now() - interval '5 minutes';
end;
$$;

revoke all on function public.touch_last_active() from public, anon;
grant execute on function public.touch_last_active() to authenticated;


-- Migration: 20260818140000_place_presence.sql
-- Yer görünürlüğü ("şu an buradayım").
--
-- "Nerede tanışabiliriz" ekranındaki kişiler koda gömülü sabit bir listeydi: herkese aynı
-- sahte isimler görünüyordu ve `togglePresence` yalnızca bellekte çalışıyordu, yani kimse
-- gerçekten bir yerde görünmüyordu.
--
-- Görünürlük bilinçli olarak kısa ömürlü: konum paylaşımı kalıcı olmamalı, bu yüzden
-- `visible_until` alanı var ve süresi dolunca kişi listeden kendiliğinden düşüyor.
--
-- Idempotent; tekrar çalıştırılabilir.

alter table public.profiles
  add column if not exists visible_place_id uuid references public.places(id) on delete set null,
  add column if not exists visible_until timestamptz;

create index if not exists profiles_visible_place_idx
  on public.profiles (visible_place_id, visible_until)
  where visible_place_id is not null;

-- Görünürlük alanları kolon bazlı okuma yetkisine eklenmeli; `tighten_privacy`
-- migration'ı profiles üzerindeki genel SELECT yetkisini kaldırmıştı.
grant select (visible_place_id, visible_until) on public.profiles to authenticated;

-- Kendi görünürlüğünü ayarla. Yer null ise görünürlük kapanır.
create or replace function public.set_visible_place(target_place uuid, minutes integer default 90)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_place is null then
    update public.profiles set visible_place_id = null, visible_until = null where id = auth.uid();
    return;
  end if;
  if not exists (select 1 from public.places where id = target_place and is_active) then
    raise exception 'Unknown place';
  end if;
  update public.profiles
  set visible_place_id = target_place,
      visible_until = now() + make_interval(mins => greatest(15, least(minutes, 240))),
      last_active_at = now()
  where id = auth.uid();
end;
$$;

revoke all on function public.set_visible_place(uuid, integer) from public, anon;
grant execute on function public.set_visible_place(uuid, integer) to authenticated;

-- Bir yerde şu an görünen kişiler. Keşifteki filtrelerin aynısı geçerli:
-- doğrulanmış, aktif, engellenmemiş ve kendisi değil.
create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    case when p.last_active_at > now() - interval '1 hour' then 'Yakın zamanda aktif'
         when p.last_active_at > now() - interval '1 day' then 'Bugün aktif'
         else 'Bu hafta aktif' end
  from public.profiles p
  where p.visible_place_id = target_place
    and p.visible_until > now()
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

revoke all on function public.get_people_at_place(uuid) from public, anon;
grant execute on function public.get_people_at_place(uuid) to authenticated;


-- Migration: 20260818160000_saved_posts.sql
-- Gönderi kaydetme (yer imi).
--
-- Akıştaki yer imi butonu yalnızca yerel durumu değiştiriyordu: uygulama kapanınca
-- kayboluyor ve kaydedilenleri görebileceğin bir ekran da yoktu. Yani buton hiçbir
-- işe yaramıyordu.
--
-- Kimin neyi kaydettiği özeldir; post_likes'ın aksine bu tablo yalnızca sahibine açık.
--
-- Idempotent.

create table if not exists public.saved_posts (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists saved_posts_user_idx on public.saved_posts (user_id, created_at desc);

alter table public.saved_posts enable row level security;

-- Beğenilerin aksine kaydetme gizlidir: kimse başkasının kaydettiklerini göremez.
drop policy if exists "users manage own saved posts" on public.saved_posts;
create policy "users manage own saved posts" on public.saved_posts
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.saved_posts from anon;
grant select, insert, delete on public.saved_posts to authenticated;


-- Migration: 20260818180000_profile_visits.sql
-- Profil ziyaretleri ("profilini kimler görüntüledi").
--
-- Bu özellik daha önce yalnızca arayüzde vardı; hiçbir yere kaydedilmiyordu, liste
-- her zaman boştu. Gerçek hale getirirken alınan gizlilik kararları:
--
-- 1. Ziyaret kaydını yalnızca profil sahibi görebilir. Ziyaretçi, başkasının
--    ziyaretçi listesini okuyamaz.
-- 2. Aynı kişi tekrar bakınca yeni satır açılmaz; sayaç ve zaman güncellenir.
--    Böylece liste tek kişiyle dolmaz.
-- 3. Kayıtlar 7 günden eskiyse gösterilmez — süresiz iz bırakmıyoruz.
-- 4. Karşılıklı engelleme varsa ziyaret kaydedilmez ve görünmez.
-- 5. Kendi profilini görüntülemek kaydedilmez.
-- 6. Ziyaret kaydı yalnızca `record_profile_visit` RPC'siyle oluşur; istemci
--    doğrudan yazamaz, böylece başkası adına sahte ziyaret üretilemez.
--
-- Idempotent.

create table if not exists public.profile_visits (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  visitor_id uuid not null references public.profiles(id) on delete cascade,
  visit_count integer not null default 1 check (visit_count > 0),
  last_visited_at timestamptz not null default now(),
  primary key (profile_id, visitor_id),
  check (profile_id <> visitor_id)
);

create index if not exists profile_visits_owner_idx
  on public.profile_visits (profile_id, last_visited_at desc);

alter table public.profile_visits enable row level security;

-- Yalnızca profil sahibi kendi ziyaretçilerini görür.
drop policy if exists "owners read own visits" on public.profile_visits;
create policy "owners read own visits" on public.profile_visits
for select to authenticated using (profile_id = auth.uid());

revoke all on public.profile_visits from anon, authenticated;
grant select on public.profile_visits to authenticated;

-- Ziyaret kaydı yalnızca bu RPC üzerinden; istemciye insert/update yetkisi verilmiyor.
create or replace function public.record_profile_visit(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or target is null or target = auth.uid() then return; end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = target)
       or (b.blocker_id = target and b.blocked_id = auth.uid())
  ) then return; end if;
  if not exists (select 1 from public.profiles p where p.id = target and p.is_active) then return; end if;

  insert into public.profile_visits (profile_id, visitor_id)
  values (target, auth.uid())
  on conflict (profile_id, visitor_id) do update
    set visit_count = public.profile_visits.visit_count + 1,
        last_visited_at = now();
end;
$$;

revoke all on function public.record_profile_visit(uuid) from public, anon;
grant execute on function public.record_profile_visit(uuid) to authenticated;

-- Ziyaretçi listesi. Profil alanları kolon bazlı yetkiyle kısıtlı olduğu için
-- (bkz. tighten_privacy) security definer ile okunuyor; yalnızca çağıranın
-- kendi ziyaretçileri döner.
create or replace function public.get_my_profile_visits()
returns table (
  visitor_id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  visit_count integer, last_visited_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, v.visit_count, v.last_visited_at
  from public.profile_visits v
  join public.profiles p on p.id = v.visitor_id
  where v.profile_id = auth.uid()
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


-- Migration: 20260818200000_unmatch.sql
-- Eşleşmeden çıkma.
--
-- `matches.unmatched_at` sütunu vardı ama yalnızca engelleme onu kullanıyordu; kullanıcının
-- "bu eşleşmeyi bitir" seçeneği yoktu. Sıkıldığı biriyle sohbeti bitirmek isteyen kişi
-- karşı tarafı engellemek zorunda kalıyordu — çok daha ağır ve geri dönüşü zor bir eylem.
--
-- İstemciye `matches` üzerinde update yetkisi verilmediği için security definer RPC gerekiyor.
-- Idempotent.

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


-- Migration: 20260818210000_university_domain_fix.sql
-- `save_my_profile` hiçbir zaman `university_domain` sütununu set etmiyordu; profil
-- oluşturulurken sütunun `not null default 'yalova.edu.tr'` varsayılanı kullanılıyordu.
-- `profiles_validate_membership` tetikleyicisi ise hesabın gerçek e-posta domain'ini bu
-- sütunla birebir karşılaştırıyor. Sonuç: gerçek öğrenci adresleri (`...@ogrenci.yalova.edu.tr`)
-- varsayılanla eşleşmediği için ilk profil kaydında "A verified university email is
-- required" hatasıyla reddediliyordu — kayıt akışı hiçbir zaman uçtan uca çalışamazdı.
--
-- Ayrıca iş kuralı: yalnızca .edu.tr uzantılı hesaplar profil oluşturabilsin (tek
-- üniversiteye değil, herhangi bir Türkiye yükseköğretim domainine izin verilir).
--
-- Idempotent; tekrar çalıştırılabilir.

create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[],
  profile_prompts jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  account_domain text;
  prompt jsonb;
  prompt_position integer := 0;
begin
  if account_id is null then raise exception 'Authentication required'; end if;

  select lower(split_part(email, '@', 2)) into account_domain
  from auth.users where id = account_id;

  if account_domain is null or account_domain !~ '\.edu\.tr$' then
    raise exception 'A verified .edu.tr email is required';
  end if;

  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;
  if jsonb_array_length(profile_prompts) <> 3 then raise exception 'Exactly three prompts are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, university_domain, discovery_enabled
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), account_domain, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    university_domain = excluded.university_domain, discovery_enabled = true;

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

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) to authenticated;


-- Migration: 20260818220000_remove_domain_verification.sql
-- Giriş yöntemi e-posta/OTP'den Apple + Google'a geçiyor. Apple/Google hesap e-postaları
-- (kişisel Gmail, iCloud, Hide My Email adresleri) .edu.tr olmak zorunda değil, bu yüzden
-- "hesabın gerçek e-posta domain'i üniversite domain'iyle eşleşmeli" kuralı artık anlamsız
-- ve her girişi bloke eder. `20260818210000_university_domain_fix.sql` ile eklenen tetikleyici
-- ve RPC kısıtı burada kaldırılıyor.
--
-- Idempotent; tekrar çalıştırılabilir.

drop trigger if exists profiles_validate_membership on public.profiles;
drop function if exists public.validate_profile_membership();

create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[],
  profile_prompts jsonb
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

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) to authenticated;


-- Migration: 20260818230000_truthful_active_label.sql
-- Aktiflik etiketi doğru olmayan bilgi veriyordu.
--
-- İki fonksiyonda da etiket şöyleydi:
--
--   case when last_active_at > now() - interval '1 hour' then 'Yakın zamanda aktif'
--        when last_active_at > now() - interval '1 day'  then 'Bugün aktif'
--        else 'Bu hafta aktif' end
--
-- Son dal her şeyi yakalıyordu: üç ay önce girmiş biri de "Bu hafta aktif"
-- görünüyordu. Kullanıcı karşısındaki kişinin ne zaman uğradığına bakarak karar
-- veriyor; burada söylenen şey basitçe yanlıştı.
--
-- Yeni kovalar gerçeği söylüyor ve bir ayı geçenlerde etiket boş bırakılıyor —
-- "uzun süredir yok" demektense hiçbir şey dememek daha az yanıltıcı, arayüz de
-- boş etiketi zaten göstermiyor.
--
-- Ayrıca "tanışma niyeti" sorusu üründen kaldırıldı: artık kimseye sorulmuyor ve
-- herkeste varsayılan değer duruyor. Bu yüzden uyum puanındaki +8 herkese eşit
-- veriliyor (hiçbir şey ayırt etmiyor) ve "Tanışma niyetiniz benzer" satırı herkese
-- gösterilerek gerçek olmayan bir yakınlık kuruyordu. İkisi de çıkarıldı.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- Ortak yardımcı: iki fonksiyon da aynı kuralı kullansın, ileride tek yerden değişsin.
create or replace function public.activity_label(last_active timestamptz)
-- `stable`, `immutable` değil: gövde now() kullanıyor, yani sonuç zamana bağlı.
returns text language sql stable set search_path = '' as $$
  select case
    when last_active is null then ''
    when last_active > now() - interval '1 hour'  then 'Yakın zamanda aktif'
    when last_active > now() - interval '1 day'   then 'Bugün aktif'
    when last_active > now() - interval '2 days'  then 'Dün aktif'
    when last_active > now() - interval '7 days'  then 'Bu hafta aktif'
    when last_active > now() - interval '30 days' then 'Bu ay aktif'
    else ''
  end;
$$;

revoke all on function public.activity_label(timestamptz) from public, anon;
grant execute on function public.activity_label(timestamptz) to authenticated;

-- ============ get_discovery_candidates ============

create or replace function public.get_discovery_candidates(page_limit integer default 20, page_offset integer default 0)
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
      + case when c.academic_year = (select academic_year from me) then 5 else 0 end)::integer as compatibility_score,
    array_remove(array[
      case when c.common_count > 0 then c.common_count || ' ortak ilgi alanı' end,
      case when c.academic_year = (select academic_year from me) then 'Aynı sınıf düzeyi' end
    ], null),
    public.activity_label(c.last_active_at)
  from candidates c
  order by compatibility_score desc, c.last_active_at desc, c.id
  limit greatest(1, least(page_limit, 50)) offset greatest(page_offset, 0);
$$;

revoke all on function public.get_discovery_candidates(integer, integer) from public, anon;
grant execute on function public.get_discovery_candidates(integer, integer) to authenticated;

-- ============ get_people_at_place ============

create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    public.activity_label(p.last_active_at)
  from public.profiles p
  where p.visible_place_id = target_place
    and p.visible_until > now()
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

revoke all on function public.get_people_at_place(uuid) from public, anon;
grant execute on function public.get_people_at_place(uuid) to authenticated;


-- Migration: 20260819000000_drop_profile_prompts.sql
-- Profil soruları ("Kampüste beni nerede bulursun?", "İlk buluşma fikrim",
-- "Beraber deneyelim") ürün kararıyla kaldırıldı. Kayıt akışı kısaldı.
--
-- `save_my_profile` bunları hâlâ ZORUNLU tutuyordu:
--   - tam üç soru gelmeli
--   - üçünün de cevabı boş olmamalı
-- Uygulama artık soru göndermediği için bu haliyle her kayıt denemesi
-- "Exactly three prompts are required" hatasıyla reddedilirdi.
--
-- Ayrıca `profile_dating_preference` de artık cinsiyetten türetiliyor (kadın →
-- erkekleri görür, erkek → kadınları). Parametre imzada kalıyor: sunucu tarafında
-- bir şey değişmiyor, uygulama sadece hesaplanmış değeri gönderiyor.
--
-- Eski imza (11 parametre) düşürülüp 10 parametreli yenisi oluşturuluyor; aksi
-- halde iki aşırı yükleme yan yana kalır ve PostgREST hangisini çağıracağını
-- seçemez.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

drop function if exists public.save_my_profile(
  text, date, public.profile_gender, public.dating_preference,
  public.relationship_intent, text, text, text, text, text[], jsonb
);

create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;

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

  -- Özellik kalktığı için eski cevaplar da bırakılmıyor: profilde görünmeyen
  -- ama sunucuda duran veri, ileride yanlışlıkla geri sızabilecek bir yük.
  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;


-- Migration: 20260819120000_badges_and_places.sql
-- Rozetler, görünürlük kapısı düzeltmesi ve gerçek YÜ birimleri.
--
-- ÖNEMLİ BİR HATA DÜZELTİLİYOR: `is_verified` iki ayrı işi birden yapıyordu.
--
--   1. Kartlardaki mavi tik (görsel rozet)
--   2. Görünürlük kapısı — keşif adayları, tepki verme, fotoğraf okuma, yerdeki
--      kişiler ve profil görünürlüğü dahil dokuz ayrı yerde `and p.is_verified`
--      filtresi var.
--
-- Varsayılanı `false` ve hiçbir kod onu `true` yapmıyordu. Yani kayıt olan
-- kullanıcı ne kimseyi görebiliyor ne de kimseye görünüyordu — Tanış boş
-- geliyor, kimse eşleşemiyor, sebebi de hiçbir yerde yazmıyordu.
--
-- Bu yüzden ikisi ayrılıyor:
--   * `is_verified` → kapı olarak kalıyor ve profilini tamamlayan herkese
--     veriliyor (`save_my_profile` içinde). Üniversite doğrulaması ürün kararıyla
--     zaten kaldırılmıştı, dolayısıyla "içeri girebilir" ölçütü artık budur.
--   * `badge` → yeni sütun, kartlarda görünen işaret. İstemci bunu ayarlayamaz:
--     `save_my_profile` parametresi değil, kolon yetkisi de verilmiyor. Yalnızca
--     panelden elle atanır.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- ---------------------------------------------------------------- rozet

do $$
begin
  if not exists (select 1 from pg_type where typname = 'profile_badge') then
    create type public.profile_badge as enum ('none', 'verified', 'moderator', 'founder');
  end if;
end $$;

alter table public.profiles
  add column if not exists badge public.profile_badge not null default 'none';

-- İstemci rozeti kendine veremesin: yazma yetkisi verilmiyor.
revoke update (badge) on public.profiles from authenticated, anon;

-- ---------------------------------------------------------------- kapı

-- Profilini tamamlayan herkes görünür hale gelir. `save_my_profile` gövdesi
-- 20260819000000 ile aynı; yalnızca `is_verified` eklendi.
create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, discovery_enabled, is_verified
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    discovery_enabled = true, is_verified = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;

-- Bu migration'dan önce profilini tamamlamış olanlar da açılsın.
update public.profiles set is_verified = true where discovery_enabled and not is_verified;


-- ---------------------------------------------------------------- rozeti istemciye aç
--
-- Rozet, `is_verified`'in bugüne kadar gösterildiği her yerde görünmeli; aksi halde
-- kartta çıkıp sohbette çıkmayan tutarsız bir işaret olur. `is_verified` alanları
-- yerinde bırakılıyor (kapı olarak hâlâ kullanılıyor), yanlarına `badge` ekleniyor.

-- Sohbet ve gönderi yazarları doğrudan `profiles`'tan seçiliyor: kolon okuma izni.
grant select (badge) on public.profiles to authenticated;

-- Keşif adayları
--
-- `create or replace function` dönüş tipini değiştiremez (RETURNS TABLE'a yeni
-- sütun eklemek de buna girer) — önce düşürmek zorundayız, aksi halde
-- "cannot change return type of existing function" hatasıyla tüm migration
-- geri sarılır.
drop function if exists public.get_discovery_candidates(integer, integer);
create or replace function public.get_discovery_candidates(page_limit integer default 20, page_offset integer default 0)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, gallery_paths text[], is_verified boolean,
  badge public.profile_badge,
  relationship_intent public.relationship_intent, interests text[],
  prompt_keys text[], prompt_answers text[], compatibility integer,
  compatibility_reasons text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  with me as (
    select p.id, p.gender, p.dating_preference, p.academic_year,
      coalesce(dp.min_age, 18) as min_age, coalesce(dp.max_age, 30) as max_age,
      coalesce(dp.academic_years, '{}') as academic_years,
      coalesce(dp.departments, '{}') as departments,
      coalesce(dp.require_common_interest, false) as require_common_interest,
      coalesce((select array_agg(interest) from public.profile_interests where profile_id = p.id), '{}') as my_interests
    from public.profiles p
    left join public.discovery_preferences dp on dp.user_id = p.id
    where p.id = auth.uid()
  ),
  candidates as (
    select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
      p.bio, p.avatar_path, p.is_verified, p.badge, p.relationship_intent, p.last_active_at,
      coalesce(array_agg(pi.interest) filter (where pi.interest is not null), '{}') as interests,
      cardinality(array(
        select unnest(coalesce(array_agg(pi.interest) filter (where pi.interest is not null), '{}'))
        intersect
        select unnest((select my_interests from me))
      )) as common_count
    from public.profiles p
    left join public.profile_interests pi on pi.profile_id = p.id
    cross join me
    where p.id <> auth.uid()
      and p.is_verified and p.is_active and p.discovery_enabled
      and extract(year from age(current_date, p.birth_date)) between me.min_age and me.max_age
      and (cardinality(me.academic_years) = 0 or p.academic_year = any(me.academic_years))
      and (cardinality(me.departments) = 0 or p.department = any(me.departments))
      and (me.dating_preference = 'everyone'
           or (me.dating_preference = 'women' and p.gender = 'female')
           or (me.dating_preference = 'men' and p.gender = 'male'))
      and (p.dating_preference = 'everyone'
           or (p.dating_preference = 'women' and me.gender = 'female')
           or (p.dating_preference = 'men' and me.gender = 'male'))
      and not exists (select 1 from public.reactions r where r.actor_id = auth.uid() and r.subject_id = p.id)
      and not exists (select 1 from public.blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    group by p.id
  )
  select c.id, c.name, c.birth_date, c.university, c.department, c.academic_year,
    c.bio, c.avatar_path,
    coalesce((select array_agg(pp.storage_path order by pp.position) from public.profile_photos pp where pp.profile_id = c.id), '{}'),
    c.is_verified, c.badge, c.relationship_intent, c.interests,
    '{}'::text[], '{}'::text[],
    least(99, 55 + least(c.common_count * 10, 30)
      + case when c.academic_year = (select academic_year from me) then 5 else 0 end)::integer as compatibility_score,
    array_remove(array[
      case when c.common_count > 0 then c.common_count || ' ortak ilgi alanı' end,
      case when c.academic_year = (select academic_year from me) then 'Aynı sınıf düzeyi' end
    ], null),
    case
      when c.last_active_at > now() - interval '15 minutes' then 'Şu an aktif'
      when c.last_active_at > now() - interval '1 day' then 'Bugün aktif'
      when c.last_active_at > now() - interval '3 days' then 'Son birkaç gün içinde aktif'
      when c.last_active_at > now() - interval '7 days' then 'Bu hafta aktif'
      else 'Bir süredir uğramadı'
    end
  from candidates c
  where (not (select require_common_interest from me)) or c.common_count > 0
  order by compatibility_score desc, c.last_active_at desc nulls last, c.id
  limit greatest(page_limit, 0) offset greatest(page_offset, 0);
$$;

revoke all on function public.get_discovery_candidates(integer, integer) from public, anon;
grant execute on function public.get_discovery_candidates(integer, integer) to authenticated;


-- Yerdeki kişiler
drop function if exists public.get_people_at_place(uuid);
create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    public.activity_label(p.last_active_at)
  from public.profiles p
  where p.visible_place_id = target_place
    and p.visible_until > now()
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

revoke all on function public.get_people_at_place(uuid) from public, anon;
grant execute on function public.get_people_at_place(uuid) to authenticated;


-- Profil ziyaretçileri
drop function if exists public.get_my_profile_visits();
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


-- Kendi profilim (rozetimi kendi ekranımda da görebilmek için)
drop function if exists public.get_my_profile();
create or replace function public.get_my_profile()
returns table (
  name text, birth_date date, gender public.profile_gender,
  dating_preference public.dating_preference,
  relationship_intent public.relationship_intent,
  university text, department text, academic_year text, bio text,
  badge public.profile_badge,
  interests text[], prompt_keys text[], prompt_answers text[],
  min_age smallint, max_age smallint, academic_years text[], departments text[],
  require_common_interest boolean, campus_only boolean
)
language sql stable security definer set search_path = '' as $$
  select
    p.name, p.birth_date, p.gender, p.dating_preference, p.relationship_intent,
    p.university, p.department, p.academic_year, p.bio, p.badge,
    coalesce((select array_agg(pi.interest order by pi.interest) from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce(dp.min_age, 18::smallint),
    coalesce(dp.max_age, 30::smallint),
    coalesce(dp.academic_years, '{}'),
    coalesce(dp.departments, '{}'),
    coalesce(dp.require_common_interest, false),
    coalesce(dp.campus_only, true)
  from public.profiles p
  left join public.discovery_preferences dp on dp.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- ---------------------------------------------------------------- yerler
--
-- Fakülte adları Yalova Üniversitesi'nin kendi iletişim sayfasından alındı
-- (yalova.edu.tr/iletisim).
--
-- Alan etiketleri tek bir değere indiriliyor. Eskiden aynı kampüs için üç ayrı
-- etiket vardı ("YÜ", "Yalova", "Merkez Kampüs") ve buraya bir de "Merkez Yerleşke"
-- eklenince liste dört başlığa bölünmüş görünüyordu — oysa bu noktaların hepsi
-- merkez kampüste.

insert into public.places (name, area) values
  ('Aytaç Cafe',                          'Merkez Kampüs'),
  ('Mühendislik Fakültesi',               'Merkez Kampüs'),
  ('Sanat ve Tasarım Fakültesi',          'Merkez Kampüs'),
  ('Hukuk Fakültesi',                     'Merkez Kampüs'),
  ('İnsan ve Toplum Bilimleri Fakültesi', 'Merkez Kampüs'),
  ('İlahiyat Fakültesi',                  'Merkez Kampüs'),
  ('Sağlık Bilimleri Fakültesi',          'Merkez Kampüs'),
  ('Spor Bilimleri Fakültesi',            'Merkez Kampüs'),
  ('Tıp Fakültesi',                       'Merkez Kampüs'),
  ('Yabancı Diller Yüksekokulu',          'Merkez Kampüs'),
  ('Yalova Meslek Yüksekokulu',           'Merkez Kampüs'),
  ('Yemekhane',                           'Merkez Kampüs'),
  ('Spor Salonu',                         'Merkez Kampüs')
on conflict (name) do nothing;

-- Eskiden eklenmiş kayıtların etiketleri de tek değere çekiliyor.
update public.places set area = 'Merkez Kampüs' where area <> 'Merkez Kampüs';


-- Migration: 20260819200000_storage_cleanup_fix.sql
-- Gönderi ve story silme çalışmıyordu.
--
-- Cihazdan alınan ham hata:
--   42501 "Direct deletion from storage tables is not allowed.
--          Use the Storage API instead."
--   hint: "This prevents accidental data loss from orphaned objects."
--
-- `cleanup_post_media` ve `cleanup_story_media` tetikleyicileri, satır silinince
-- `storage.objects`'ten de doğrudan siliyordu. Supabase bunu artık veritabanı
-- seviyesinde engelliyor; tetikleyici hata verince silme işleminin tamamı geri
-- sarılıyor ve kullanıcı "Gönderi silinemedi" görüyordu.
--
-- Dosya silme işi istemciye alınıyor: uygulama önce Storage API ile dosyayı
-- siliyor, sonra satırı siliyor. Tetikleyiciler tamamen kaldırılıyor — boş bir
-- gövdeyle bırakmak, ileride okuyan birine hâlâ bir temizlik yapıldığını
-- düşündürürdü.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

drop trigger if exists posts_cleanup_media on public.posts;
drop trigger if exists stories_cleanup_media on public.stories;

drop function if exists public.cleanup_post_media();
drop function if exists public.cleanup_story_media();

-- Not: bu değişiklikten önce silinmiş gönderilerin dosyaları depolamada kalmış
-- olabilir. Zararsız (kimse erişemiyor, yalnızca yer kaplıyor); istenirse
-- Storage panelinden elle temizlenebilir.


-- Migration: 20260819210000_account_deletion_storage.sql
-- Hesap silme de aynı sebeple kırıktı.
--
-- `delete_my_account` içinde şu vardı:
--   delete from storage.objects where bucket_id in (...) and ...
--
-- Bu, gönderi silmeyi bozan işlemin aynısı: Supabase depolama tablolarından
-- doğrudan silmeyi engelliyor ("Direct deletion from storage tables is not
-- allowed"). Yani "Hesabı kalıcı sil" düğmesi de hata verecekti — henüz kimse
-- denemediği için görünmemişti.
--
-- Dosya silme istemciye alınıyor: uygulama önce Storage API ile kullanıcının
-- klasörlerini boşaltıyor, sonra bu fonksiyonu çağırıyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  -- Depolama artık istemci tarafında, Storage API ile temizleniyor.
  -- Buradaki satır silme, `auth.users` üzerinden cascade ile tüm tabloları
  -- boşaltıyor.
  delete from auth.users where id = account_id;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- Migration: 20260819230000_meeting_accepted_notification.sql
-- Buluşma isteği kabul edilince gönderenin haberi olmuyordu.
--
-- `meeting_requests` üzerindeki bildirim tetikleyicisi yalnızca `after insert`
-- çalışıyor: alıcı isteği görüyor, ama kabul ettiğinde gönderene hiçbir şey
-- gitmiyor. Gönderenin öğrenmesinin tek yolu "Buluşma istekleri" ekranını
-- açmayı akıl etmesi. Aynı yerde, o an buluşmaya yarayan bir özellik için bu,
-- özelliği işlevsiz bırakıyor: karşı taraf kabul edip beklerken gönderen çoktan
-- oradan ayrılmış oluyor.
--
-- Reddedilme bilerek bildirilmiyor. İstek göndermenin eşiğini düşüren şey,
-- reddedilirse karşı tarafın bunu öğrenmeyecek olması; uygulama da kullanıcıya
-- bunu vaat ediyor.
--
-- Yeni bir enum değeri EKLENMİYOR. `notification_kind` üzerinde `alter type ...
-- add value` çalıştırmak, migration'ın tamamı tek işlemde koştuğu için riskli
-- (eklenen değer aynı işlem içinde kullanılamaz). Mevcut 'meeting_request'
-- değeri yeniden kullanılıyor; arayüz bu türü zaten tanıyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

create or replace function public.notify_on_meeting_accepted()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  place_label text;
begin
  select name into place_label from public.places where id = new.place_id;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (new.requester_id, 'meeting_request',
    public.profile_display_name(new.recipient_id) || ' buluşmayı kabul etti',
    coalesce(place_label, 'Kampüs') || ' için buluşmanız onaylandı.',
    new.recipient_id);
  return new;
end;
$$;

drop trigger if exists meeting_requests_accepted_notify on public.meeting_requests;
create trigger meeting_requests_accepted_notify
after update of status on public.meeting_requests
for each row
when (new.status = 'accepted' and old.status is distinct from 'accepted')
execute function public.notify_on_meeting_accepted();


-- Migration: 20260820100000_profile_visibility_beyond_posts.sql
-- Bir hesabın attığı story diğer hesapta hiç görünmüyordu.
--
-- Story izin kuralı serbest; sorun yazarın profilinde. Profil okuma kuralı
-- şuydu: "bir profili ancak kendinsen, eşleştiysen ya da o kişi GÖNDERİ
-- paylaştıysa görebilirsin." Story sorgusu yazarın profilini de çektiği için,
-- hiç gönderi paylaşmamış birinin story'sinde profil null dönüyor ve uygulama
-- yazarsız story'yi sessizce atıyordu. Yani "yeni hesap açtım, story attım,
-- diğer hesapta görünmüyor" tam olarak beklenen davranıştı.
--
-- Aynı kural altı yeri birden bozuyordu:
--   - story'ler (yazar okunamıyor → story kayboluyor)
--   - yorumlar (yazar okunamıyor → yorum adsız)
--   - story izleyici listesi (izleyen okunamıyor → listede eksik)
--   - bildirimler (bildirimi doğuran kişi okunamıyor)
--   - buluşma istekleri (gönderen/alan okunamıyor)
--
-- Kuralın amacı rastgele profil taramasını engellemekti; o amaç korunuyor.
-- Eklenen maddelerin hepsi ya kişinin kendi isteğiyle herkese açık bir şey
-- yapmış olması (story, yorum) ya da seninle kurulmuş somut bir ilişki
-- (buluşma isteği, story'ni izlemiş olması, sana düşen bir bildirim).
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

drop policy if exists "users view relevant profiles" on public.profiles;

create policy "users view relevant profiles" on public.profiles
for select to authenticated using (
  id = auth.uid()

  -- Eşleştiklerin
  or exists (
    select 1 from public.matches m
    where m.unmatched_at is null
      and ((m.user_a = auth.uid() and m.user_b = profiles.id)
        or (m.user_b = auth.uid() and m.user_a = profiles.id))
  )

  -- Herkese açık içerik paylaşmış olanlar
  or exists (select 1 from public.posts p where p.author_id = profiles.id)
  or exists (
    select 1 from public.stories s
    where s.author_id = profiles.id and s.expires_at > now()
  )
  or exists (select 1 from public.comments c where c.author_id = profiles.id)

  -- Seninle somut ilişkisi olanlar
  or exists (
    select 1 from public.meeting_requests mr
    where (mr.requester_id = auth.uid() and mr.recipient_id = profiles.id)
       or (mr.recipient_id = auth.uid() and mr.requester_id = profiles.id)
  )
  or exists (
    select 1 from public.story_views sv
    join public.stories s on s.id = sv.story_id
    where sv.viewer_id = profiles.id and s.author_id = auth.uid()
  )
  or exists (
    select 1 from public.notifications n
    where n.user_id = auth.uid() and n.actor_id = profiles.id
  )
);


-- Migration: 20260820140000_reset_passes.sql
-- "Geç" denilen kişiler bir daha hiç görünmüyordu.
--
-- Keşif sorgusu, karar verilmiş herkesi eliyor: `not exists (select 1 from
-- reactions where actor_id = auth.uid() and subject_id = p.id)`. Beğeni için
-- doğru, ama "geç" için kalıcı bir karar olmamalı — kampüste toplam birkaç bin
-- kişi var ve bir kere sağa/sola kaydırmak kimseyi ömür boyu silmemeli.
--
-- İstemci bu kayıtları kendisi silemiyor: `reactions` tablosunda authenticated
-- rolünün yalnızca select yetkisi var (bilerek — kimse başkasının kararını
-- değiştirememeli). O yüzden silme işi bu fonksiyonun içinde.
--
-- Yalnızca 'pass' kayıtları siliniyor. Beğeniler duruyor, dolayısıyla eşleşmeler
-- ve mevcut sohbetler etkilenmiyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

create or replace function public.reset_my_passes()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  silinen integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.reactions
  where actor_id = auth.uid() and kind = 'pass';
  get diagnostics silinen = row_count;
  return silinen;
end;
$$;

revoke all on function public.reset_my_passes() from public, anon;
grant execute on function public.reset_my_passes() to authenticated;


-- Migration: 20260821000000_message_edit_delete_story_likes.sql
-- İki eksik: mesaj silme/düzenleme ve story beğenisi.
--
-- Uygulamanın `messages` tablosunda yalnızca okuma, ekleme ve `read_at`
-- güncelleme yetkisi vardı; kendi mesajını silmenin ya da düzeltmenin yolu
-- yoktu. Story beğenisi ise hiç yoktu: kalp düğmesi eşleşilen sohbete "❤️"
-- mesajı gönderiyordu, story sahibine "beğenildi" diye bir şey ulaşmıyordu.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- ------------------------------------------------------------ mesaj düzenleme
-- Düzenlenmiş mesajı arayüzde işaretleyebilmek için. Boşsa hiç düzenlenmemiş.
alter table public.messages add column if not exists edited_at timestamptz;

-- Yalnızca kendi mesajını ve yalnızca hâlâ üyesi olduğun eşleşmede.
drop policy if exists "senders edit own messages" on public.messages;
create policy "senders edit own messages" on public.messages
for update to authenticated
using (sender_id = auth.uid() and public.is_match_member(match_id))
with check (sender_id = auth.uid() and public.is_match_member(match_id));

-- `read_at` yetkisi zaten vardı; gövde ve düzenleme damgası ekleniyor.
grant update (body, edited_at) on public.messages to authenticated;

-- ---------------------------------------------------------------- mesaj silme
drop policy if exists "senders delete own messages" on public.messages;
create policy "senders delete own messages" on public.messages
for delete to authenticated
using (sender_id = auth.uid() and public.is_match_member(match_id));

grant delete on public.messages to authenticated;

-- ------------------------------------------------------------ story beğenisi
create table if not exists public.story_likes (
  story_id uuid not null references public.stories(id) on delete cascade,
  liker_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, liker_id)
);

alter table public.story_likes enable row level security;

-- Beğeniyi story sahibi ve beğenen görebilir; başkası göremez.
drop policy if exists "owner and liker read story likes" on public.story_likes;
create policy "owner and liker read story likes" on public.story_likes
for select to authenticated using (
  liker_id = auth.uid()
  or exists (
    select 1 from public.stories s
    where s.id = story_likes.story_id and s.author_id = auth.uid()
  )
);

-- Herkes yalnızca kendi beğenisini ekler ve kaldırır.
drop policy if exists "users manage own story likes" on public.story_likes;
create policy "users manage own story likes" on public.story_likes
for all to authenticated
using (liker_id = auth.uid())
with check (liker_id = auth.uid());

revoke all on public.story_likes from anon;
grant select, insert, delete on public.story_likes to authenticated;

-- Story sahibine bildirim. Yeni enum değeri EKLENMİYOR: `alter type ... add
-- value` migration'ın tamamı tek işlemde koştuğu için riskli. Mevcut 'like'
-- değeri kullanılıyor, arayüz bu türü zaten tanıyor.
create or replace function public.notify_on_story_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.stories where id = new.story_id;
  -- Kendi story'sini beğenmek bildirim üretmez; `no_self_notification` kısıtı
  -- zaten buna izin vermezdi ve tetikleyici hatası beğeniyi de geri sarardı.
  if owner_id is null or owner_id = new.liker_id then return new; end if;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (owner_id, 'like',
    public.profile_display_name(new.liker_id) || ' story''ni beğendi', '',
    new.liker_id);
  return new;
end;
$$;

drop trigger if exists story_likes_notify on public.story_likes;
create trigger story_likes_notify after insert on public.story_likes
for each row execute function public.notify_on_story_like();


-- Migration: 20260821120000_plan_quotas.sql
-- Abonelik kademeleri ve sayılı sınırlar.
--
-- Sınırlar sunucuda uygulanmak zorunda: istemcideki bir sayaç, uygulamayı
-- kurcalayan biri için hiçbir engel değil.
--
-- Kurallar:
--   Tanış beğenisi (48 saatte)   ücretsiz 5 · plus 10 · pro sınırsız
--   Buluşma isteği (7 günde)     ücretsiz 3 · plus  5 · pro sınırsız
--   Buluşma kabulü (7 günde)     ücretsiz 2 · plus  5 · pro sınırsız
--
-- Uygulama, sınıra takıldığını hata mesajından anlıyor: QUOTA_LIKE,
-- QUOTA_MEETING_REQUEST, QUOTA_MEETING_ACCEPT. Metne göre değil bu koda göre
-- davranıyor, çünkü metin değişebilir.
--
-- `react_to_profile` gibi büyük fonksiyonlar yeniden yazılmıyor; sınırlar
-- tetikleyicilerle uygulanıyor. Böylece mevcut mantığa hiç dokunulmuyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- ------------------------------------------------------------------- kademe
--
-- Kademe `profiles` üzerinde bir sütun DEĞİL, ayrı bir tablo. `profiles`
-- satırının tamamı; paylaşım yapmış, story atmış, yorum yazmış ya da seninle
-- eşleşmiş herkes tarafından okunabiliyor (bkz. "users view relevant
-- profiles"). Kademe orada dursaydı biraz meraklı herkes kimin Plus/Pro
-- olduğunu sorgulayabilirdi — oysa paywall'da açıkça "kimse senin Plus
-- olduğunu bilmeyecek" diyoruz. Ayrı tabloda kural tek satır: yalnızca kendi
-- kademeni görürsün.
create table if not exists public.subscriptions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'plus', 'pro')),
  -- Apple'ın abonelik kimliği. Tekil: bir abonelik yalnızca bir hesabı açar.
  -- Olmasaydı tek Pro aboneliğinin makbuzu elden ele dolaşıp elli hesabı
  -- açardı; Apple'ın kendi doğrulaması bunu engellemiyor, çünkü makbuz gerçek.
  original_transaction_id text,
  product_id text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Tablo daha önce bu sütunlar olmadan oluşturulduysa.
alter table public.subscriptions add column if not exists original_transaction_id text;
alter table public.subscriptions add column if not exists product_id text;
alter table public.subscriptions add column if not exists expires_at timestamptz;
create unique index if not exists subscriptions_original_transaction_idx
  on public.subscriptions (original_transaction_id)
  where original_transaction_id is not null;

alter table public.subscriptions enable row level security;

drop policy if exists "users read own subscription" on public.subscriptions;
create policy "users read own subscription" on public.subscriptions
for select to authenticated using (user_id = auth.uid());

-- Yazma yetkisi hiç kimsede yok: ne insert, ne update, ne delete. Kademeyi
-- yalnızca aşağıdaki `set_plan` değiştirebiliyor. Sütunu tetikleyiciyle
-- korumaya çalışmaktan hem daha basit hem daha sağlam.
revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;

-- Sınır tetikleyicileri, beğeniyi yapan kişinin kademesini okumak zorunda;
-- o satır o kişiye ait olduğu için normal yetkiyle görünmez — bu yüzden
-- security definer.
--
-- Süresi geçmiş abonelik hak vermiyor. Apple yenilemeyi bildirene kadar satır
-- eski haliyle duruyor; tarihe bakmasaydık iptal eden kullanıcı sınırsız
-- kalırdı.
create or replace function public.plan_of(account uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select plan from public.subscriptions
    where user_id = account
      and (expires_at is null or expires_at > now())
  ), 'free');
$$;

revoke all on function public.plan_of(uuid) from public, anon, authenticated;

-- Kademeyi değiştiren tek yol.
--
-- Bilerek `authenticated` rolüne AÇILMIYOR. Açık olsaydı uygulamayı kurcalayan
-- herkes kendine 'pro' deyip bedava Pro olurdu ve bütün sınırlar anlamsızlaşırdı.
-- Gerçek satın alma devreye girdiğinde bunu çağıracak yer, Apple'ın makbuzunu
-- doğrulayan bir Edge Function olacak (service_role ile).
--
-- Test için (SQL editöründe, service_role ile):
--   select public.set_plan('<kullanıcı-uuid>', 'pro');
create or replace function public.set_plan(
  account uuid,
  new_plan text,
  original_transaction text default null,
  product text default null,
  expires timestamptz default null
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_plan not in ('free', 'plus', 'pro') then raise exception 'Invalid plan'; end if;

  -- Aynı Apple aboneliği başka bir hesaba bağlıysa reddediyoruz. Aksi halde
  -- bir kişinin makbuzu istediği kadar hesabı Pro yapardı.
  if original_transaction is not null and exists (
    select 1 from public.subscriptions
    where original_transaction_id = original_transaction and user_id <> account
  ) then
    raise exception 'SUBSCRIPTION_ALREADY_LINKED';
  end if;

  insert into public.subscriptions (user_id, plan, original_transaction_id, product_id, expires_at, updated_at)
  values (account, new_plan, original_transaction, product, expires, now())
  on conflict (user_id) do update set
    plan = excluded.plan,
    original_transaction_id = coalesce(excluded.original_transaction_id, public.subscriptions.original_transaction_id),
    product_id = coalesce(excluded.product_id, public.subscriptions.product_id),
    expires_at = excluded.expires_at,
    updated_at = now();
end;
$$;

revoke all on function public.set_plan(uuid, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.set_plan(uuid, text, text, text, timestamptz) to service_role;
-- Eski iki parametreli sürüm kaldıysa kalmasın.
drop function if exists public.set_plan(uuid, text);

-- Kendi kademeni okumak için. Hiç abone olmamış kullanıcının `subscriptions`'ta
-- satırı yok; boş sonuç yerine 'free' dönsün diye tek bir yer.
create or replace function public.my_plan()
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select plan from public.subscriptions
    where user_id = auth.uid()
      and (expires_at is null or expires_at > now())
  ), 'free');
$$;

revoke all on function public.my_plan() from public, anon;
grant execute on function public.my_plan() to authenticated;

-- ------------------------------------------------------- beğeni sınırı (48s)
create or replace function public.enforce_like_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  -- Yalnızca yeni bir 'like' sayılıyor. 'pass' sınırsız; 'like'ı tekrar
  -- kaydetmek (aynı kişi) yeni hak harcamamalı.
  if new.kind <> 'like' then return new; end if;
  if tg_op = 'UPDATE' and old.kind = 'like' then return new; end if;

  sinir := case public.plan_of(new.actor_id)
             when 'pro'  then null
             when 'plus' then 10
             else 5
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.reactions
  where actor_id = new.actor_id
    and kind = 'like'
    and updated_at > now() - interval '48 hours'
    and subject_id <> new.subject_id;

  if kullanilan >= sinir then
    raise exception 'QUOTA_LIKE' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists reactions_like_quota on public.reactions;
create trigger reactions_like_quota before insert or update on public.reactions
for each row execute function public.enforce_like_quota();

-- ------------------------------------------------ buluşma isteği sınırı (7g)
create or replace function public.enforce_meeting_request_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  sinir := case public.plan_of(new.requester_id)
             when 'pro'  then null
             when 'plus' then 5
             else 3
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.meeting_requests
  where requester_id = new.requester_id
    and created_at > now() - interval '7 days';

  if kullanilan >= sinir then
    raise exception 'QUOTA_MEETING_REQUEST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists meeting_requests_quota on public.meeting_requests;
create trigger meeting_requests_quota before insert on public.meeting_requests
for each row execute function public.enforce_meeting_request_quota();

-- ------------------------------------------------ buluşma kabulü sınırı (7g)
create or replace function public.enforce_meeting_accept_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  if new.status <> 'accepted' or old.status = 'accepted' then return new; end if;

  sinir := case public.plan_of(new.recipient_id)
             when 'pro'  then null
             when 'plus' then 5
             else 2
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.meeting_requests
  where recipient_id = new.recipient_id
    and status = 'accepted'
    and updated_at > now() - interval '7 days'
    and id <> new.id;

  if kullanilan >= sinir then
    raise exception 'QUOTA_MEETING_ACCEPT' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists meeting_requests_accept_quota on public.meeting_requests;
create trigger meeting_requests_accept_quota before update of status on public.meeting_requests
for each row execute function public.enforce_meeting_accept_quota();

-- Bu migration'ın önceki sürümü kademeyi `profiles.plan` sütununda tutuyor ve
-- sütunu bir tetikleyiciyle koruyordu. O yol herkesin başkasının kademesini
-- okumasına açıktı. Hiçbir yere yazılmadan değiştirildiği için taşınacak veri
-- yok; yine de daha önce çalıştırıldıysa kalıntı bırakmayalım.
drop trigger if exists profiles_guard_plan on public.profiles;
drop function if exists public.guard_plan_column();
drop function if exists public.set_my_plan(text);
alter table public.profiles drop column if exists plan;


-- Migration: 20260821140000_message_requests.sql
-- Eşleşmeden yanıt yazabilme: "yanıt isteği".
--
-- Mesajlaşma eşleşmeye bağlı ve bu veritabanı seviyesinde zorunlu. Şartı
-- tamamen kaldırmak "herkes herkese yazabilir" demekti; tanışma uygulamalarında
-- bunun karşılığı istenmeyen mesaj yağmuru ve kadın kullanıcıların uygulamayı
-- bırakması oluyor. Ayrıca Tanış'ın ve beğeni hakkının değeri sıfırlanırdı.
--
-- Ara yol: eşleşmeden yazılan mesaj doğrudan sohbete düşmüyor, karşı tarafa bir
-- istek olarak gidiyor. Kabul edilirse eşleşme kuruluyor ve ilk mesaj sohbete
-- yazılıyor; reddedilirse gönderene bildirim gitmiyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'message_request_status') then
    create type public.message_request_status as enum ('pending', 'accepted', 'declined');
  end if;
end $$;

create table if not exists public.message_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  story_id uuid references public.stories(id) on delete set null,
  status public.message_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

-- Aynı kişiye bekleyen ikinci bir istek gönderilemez: ısrarlı mesajın önü
-- kapalı olmalı.
create unique index if not exists message_requests_pending_idx
  on public.message_requests (sender_id, recipient_id)
  where status = 'pending';

alter table public.message_requests enable row level security;

drop policy if exists "parties read message requests" on public.message_requests;
create policy "parties read message requests" on public.message_requests
for select to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

-- Gönderen yalnızca kendi adına ve engelli olmadığı birine yazabilir.
drop policy if exists "senders create message requests" on public.message_requests;
create policy "senders create message requests" on public.message_requests
for insert to authenticated
with check (
  sender_id = auth.uid()
  and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = recipient_id)
       or (b.blocker_id = recipient_id and b.blocked_id = auth.uid())
  )
);

-- Durumu yalnızca alıcı değiştirebilir, o da yalnızca reddetmek için.
-- 'accepted' bilerek dışarıda: kabul, eşleşmeyi kurup ilk mesajı sohbete yazan
-- `accept_message_request` fonksiyonunun işi. Doğrudan yazılabilseydi istek
-- "kabul edildi" görünürken ortada ne eşleşme ne de mesaj olurdu; gönderen
-- kabul edildiğini görüp açacak bir sohbet bulamazdı. Fonksiyon security
-- definer olduğu için bu kısıt onu engellemiyor.
drop policy if exists "recipients answer message requests" on public.message_requests;
create policy "recipients answer message requests" on public.message_requests
for update to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid() and status <> 'accepted');

revoke all on public.message_requests from anon;
grant select, insert on public.message_requests to authenticated;
grant update (status, updated_at) on public.message_requests to authenticated;

-- Reddedilen bir daha yazamaz ve kimse gün boyu istek yağdıramaz.
--
-- Bekleyen ikinci isteği yukarıdaki tekil indeks engelliyor ama tek başına
-- yetmiyordu: reddedilen kişi tekrar tekrar gönderebiliyor, ısrarcı biri de
-- yüzlerce farklı kişiye yazabiliyordu. Eşleşme şartını gevşetmemizin sebebi
-- utangaç kullanıcıydı; ısrarcı kullanıcıya kapı açmak değil.
--
-- Bu sınır kademeye bağlı DEĞİL: Pro olmak ısrar etme hakkı satın almak
-- olmamalı. Günlük 10, normal kullanımın çok üstünde bir tavan.
create or replace function public.guard_message_request()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  gunluk integer;
begin
  if exists (
    select 1 from public.message_requests
    where sender_id = new.sender_id
      and recipient_id = new.recipient_id
      and status = 'declined'
  ) then
    raise exception 'MESSAGE_REQUEST_DECLINED' using errcode = 'check_violation';
  end if;

  select count(*) into gunluk
  from public.message_requests
  where sender_id = new.sender_id and created_at > now() - interval '24 hours';

  if gunluk >= 10 then
    raise exception 'MESSAGE_REQUEST_RATE' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists message_requests_guard on public.message_requests;
create trigger message_requests_guard before insert on public.message_requests
for each row execute function public.guard_message_request();

drop trigger if exists message_requests_set_updated_at on public.message_requests;
create trigger message_requests_set_updated_at before update on public.message_requests
for each row execute function public.set_updated_at();

-- Alıcıya bildirim. Yeni enum değeri eklenmiyor; mevcut 'message' kullanılıyor.
create or replace function public.notify_on_message_request()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (new.recipient_id, 'message',
    public.profile_display_name(new.sender_id) || ' sana yazmak istiyor',
    left(new.body, 140), new.sender_id);
  return new;
end;
$$;

drop trigger if exists message_requests_notify on public.message_requests;
create trigger message_requests_notify after insert on public.message_requests
for each row execute function public.notify_on_message_request();

-- Kabul: eşleşme kuruluyor ve ilk mesaj sohbete yazılıyor.
create or replace function public.accept_message_request(request uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  kayit public.message_requests;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
begin
  select * into kayit from public.message_requests
  where id = request and recipient_id = auth.uid() and status = 'pending';
  if kayit.id is null then raise exception 'Request not found'; end if;

  ilk := least(kayit.sender_id, kayit.recipient_id);
  ikinci := greatest(kayit.sender_id, kayit.recipient_id);

  insert into public.matches(user_a, user_b) values (ilk, ikinci)
  on conflict (user_a, user_b) do update set unmatched_at = null
  returning id into eslesme;

  insert into public.messages(match_id, sender_id, body)
  values (eslesme, kayit.sender_id, kayit.body);

  update public.message_requests set status = 'accepted' where id = request;
  return eslesme;
end;
$$;

revoke all on function public.accept_message_request(uuid) from public, anon;
grant execute on function public.accept_message_request(uuid) to authenticated;


-- Migration: 20260821150000_restore_edu_domain_check.sql
-- Ürün kararı geri geldi: yalnızca .edu.tr uzantılı hesaplar profil oluşturabilsin.
--
-- `20260818220000_remove_domain_verification.sql` bu kontrolü tamamen kaldırmıştı,
-- çünkü eski tetikleyici `profiles.university_domain` sütununun varsayılan değeriyle
-- (`yalova.edu.tr`) hesabın gerçek e-posta domain'ini karşılaştırıyordu ve
-- `save_my_profile` bu sütunu hiç set etmediği için ilk kayıtta herkesi reddediyordu.
--
-- Kontrol şimdi `university_domain` sütununa hiç dokunmadan, doğrudan
-- `auth.users.email` üzerinden geri getiriliyor: Apple/Google girişinde hesabın
-- taşıdığı e-posta `.edu.tr` ile bitmiyorsa `save_my_profile` reddeder. Test etmek
-- için hesabın gerçek e-postasının (kişisel Gmail/iCloud değil, üniversitenin
-- verdiği `...@ogrenci.<üniversite>.edu.tr` gibi bir Google hesabının) OAuth
-- token'ında gelmesi gerekiyor.
--
-- Gövde `20260819120000_badges_and_places.sql` ile birebir aynı (10 parametre,
-- is_verified); yalnızca en başa domain kontrolü eklendi. Geri almak istenirse
-- o migration'daki gövde tekrar `create or replace` ile uygulanır.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  account_domain text;
begin
  if account_id is null then raise exception 'Authentication required'; end if;

  select lower(split_part(email, '@', 2)) into account_domain
  from auth.users where id = account_id;

  if account_domain is null or account_domain !~ '\.edu\.tr$' then
    raise exception 'A verified .edu.tr email is required';
  end if;

  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, discovery_enabled, is_verified
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    discovery_enabled = true, is_verified = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;


-- Migration: 20260821160000_edu_domain_signup_hook.sql
-- E-posta/OTP ile hesap oluşturmayı .edu.tr'ye kısıtlar — mail gönderilmeden önce.
--
-- SMTP zaten panelde Resend üzerinden yapılandırılı (Authentication → Emails →
-- Custom SMTP, host smtp.resend.com); bu migration o gönderimin yerine geçmiyor,
-- sadece önüne bir kapı koyuyor. Supabase Auth'un "Before User Created" hook'u,
-- GoTrue yeni bir `auth.users` satırı oluşturmadan (dolayısıyla kod maili
-- gönderilmeden) hemen önce çalışıyor. Reddedilirse ne satır oluşuyor ne mail gidiyor.
--
-- Kontrol yalnızca `provider = 'email'` olan girişlere uygulanıyor — Apple/Google'a
-- DOKUNMUYOR. Apple/Google hesap e-postaları (kişisel Gmail/iCloud) zaten .edu.tr
-- olmak zorunda değil; bunu buraya da uygulamak `20260818220000_remove_domain_
-- verification.sql`'de düzeltilen sorunu ("her girişi bloke ediyordu") aynen geri
-- getirirdi. Apple/Google için kontrol `save_my_profile` içinde (profil tamamlanırken)
-- kalmaya devam ediyor; ikisi birbirinin yerine geçmiyor, farklı girişleri süzüyor.
--
-- Supabase'in kuralı: bu fonksiyon hata FIRLATAMAZ (`raise exception` GoTrue
-- tarafından bir hook cevabı olarak yorumlanmıyor); ya `{}` (izin ver) ya da
-- `{"error": {"http_code":..., "message":...}}` (reddet) döndürmesi gerekiyor.
--
-- Panelde ayrıca yapılması gereken: Authentication → Auth Hooks → "Before User
-- Created" → Enable, tür Postgres Function, şema `public`, fonksiyon
-- `restrict_signup_to_edu_tr`.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

create or replace function public.restrict_signup_to_edu_tr(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  account_provider text := event->'user'->'app_metadata'->>'provider';
  account_email text := lower(event->'user'->>'email');
begin
  if account_provider is distinct from 'email' then
    return '{}'::jsonb;
  end if;

  if account_email is null or account_email !~ '\.edu\.tr$' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Yalnızca .edu.tr uzantılı e-postalar kabul ediliyor.'
      )
    );
  end if;

  return '{}'::jsonb;
end;
$$;

grant execute on function public.restrict_signup_to_edu_tr(jsonb) to supabase_auth_admin;
revoke execute on function public.restrict_signup_to_edu_tr(jsonb) from authenticated, anon, public;


-- Migration: 20260821170000_staff_pro_and_profile_grants.sql
-- İki şey: ekibe Pro ve `profiles` üzerindeki yazma yetkisinin daraltılması.
--
-- İkisi aynı dosyada, çünkü birincisi ikincisi olmadan güvenli değil.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- ------------------------------------------- profiles: sütun bazında yazma
--
-- `authenticated` rolüne tablo seviyesinde UPDATE verilmişti
-- (20260817133000). Sonra 20260819120000 içinde
-- `revoke update (badge) ... from authenticated` yazıldı ama bu Postgres'te
-- işe yaramaz: tablo seviyesindeki yetki bütün sütunları kapsar ve tek bir
-- sütun için geri alınamaz. Postgres bu durumda sessizce bir uyarı basıp
-- hiçbir şey yapmaz.
--
-- Sonuç: kullanıcı kendi satırında istediği sütunu yazabiliyordu. `badge`
-- yazılabildiği için herkes kendini "Common Kurucusu" ya da moderatör
-- yapabilirdi; `is_verified` yazılabildiği için doğrulanmış görünebilirdi.
--
-- Doğru yol tek yol: tablo yetkisini kaldırıp yalnızca gerçekten yazılan
-- sütunu açmak. İstemci `profiles` üzerinde doğrudan sadece `avatar_path`
-- yazıyor (fotoğraf yükleme/kaldırma); metin alanları `save_my_profile`,
-- görünürlük `set_visible_place`, etkinlik `touch_last_active` üzerinden
-- gidiyor ve hepsi security definer, yani bu kısıttan etkilenmiyor.
revoke update on public.profiles from authenticated, anon;
grant update (avatar_path) on public.profiles to authenticated;

-- ------------------------------------------------------------ ekibe Pro
--
-- Kurucu ve moderatörler uygulamayı çalıştıran insanlar; kendi uygulamalarına
-- abone olmaları anlamsız. Kademeyi elle yazmak yerine rozetten türetiyoruz:
-- yeni bir moderatör atandığında ayrıca bir şey yapmak gerekmiyor, rozet
-- alındığında Pro da kendiliğinden kalkıyor.
--
-- Bu ancak yukarıdaki yetki daraltmasıyla birlikte güvenli: rozet
-- yazılabilir olsaydı herkes kendine kurucu deyip bedava Pro olurdu.
create or replace function public.plan_of(account uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when exists (
      select 1 from public.profiles
      where id = account and badge in ('founder', 'moderator')
    ) then 'pro'
    else coalesce((
      select plan from public.subscriptions
      where user_id = account
        and (expires_at is null or expires_at > now())
    ), 'free')
  end;
$$;

revoke all on function public.plan_of(uuid) from public, anon, authenticated;

-- Arayüz de aynı cevabı almalı, yoksa sınırlar kalkıyor ama ekranlar kilitli
-- kalıyordu.
create or replace function public.my_plan()
returns text language sql stable security definer set search_path = '' as $$
  select public.plan_of(auth.uid());
$$;

revoke all on function public.my_plan() from public, anon;
grant execute on function public.my_plan() to authenticated;

-- Rozeti yalnızca sunucu tarafı verebilir. Kurucu/moderatör atamanın tek yolu.
--
--   select public.set_badge('<kullanıcı-uuid>', 'founder');
--   select public.set_badge(id, 'moderator') from auth.users where email = '...';
create or replace function public.set_badge(account uuid, new_badge text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_badge not in ('none', 'verified', 'moderator', 'founder') then
    raise exception 'Invalid badge';
  end if;
  update public.profiles set badge = new_badge::public.profile_badge where id = account;
end;
$$;

revoke all on function public.set_badge(uuid, text) from public, anon, authenticated;
grant execute on function public.set_badge(uuid, text) to service_role;


-- Migration: 20260821180000_defer_edu_domain_check.sql
-- .edu.tr şartı ilk sürümde kapalı.
--
-- Ürün kararı: v1'de herkes kolayca girebilsin. Kısıtlama tamamen silinmiyor,
-- yalnızca devre dışı bırakılıyor — geri açmak için `20260821150000` ve
-- `20260821160000` dosyalarını tekrar çalıştırmak yeterli.
--
-- Ayrıca App Store incelemesi için zorunluydu: şart açıkken inceleyen kişi
-- kendi Apple hesabıyla girebiliyor ama kayıt akışının son adımında
-- `save_my_profile` onu reddediyor ve uygulamayı hiç göremiyor. Gördüğü tek
-- şey bir hata mesajı olan bir uygulama reddedilir.
--
-- İki yerde kapatılıyor, çünkü iki ayrı yerde açılmıştı:
--   1. `save_my_profile` içindeki domain kontrolü (Apple/Google dahil herkese)
--   2. `restrict_signup_to_edu_tr` kayıt hook'u (yalnızca e-posta girişi)
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- ------------------------------------------------------ 1. profil kaydı
--
-- Gövde `20260821150000` ile birebir aynı; yalnızca en baştaki domain
-- kontrolü çıkarıldı. Rozet/is_verified davranışı aynen korunuyor.
create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;

  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, discovery_enabled, is_verified
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    discovery_enabled = true, is_verified = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;

-- ------------------------------------------------------ 2. kayıt hook'u
--
-- Hook'u panelden kapatmak da işe yarardı ama tek başına yeterli değil:
-- panel ayarı bu dosyada görünmüyor, unutulursa kimse fark etmiyor.
-- Fonksiyonun kendisi herkese izin verir hale getiriliyor; panelde açık
-- kalsa bile kimseyi engellemiyor.
create or replace function public.restrict_signup_to_edu_tr(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  return '{}'::jsonb;
end;
$$;

grant execute on function public.restrict_signup_to_edu_tr(jsonb) to supabase_auth_admin;
revoke execute on function public.restrict_signup_to_edu_tr(jsonb) from authenticated, anon, public;


-- Migration: 20260821190000_moderation.sql
-- Moderasyon: kurucu ve moderatörler içerik kaldırabilsin, hesap askıya alabilsin.
--
-- Şu ana kadar rozet yalnızca görseldi. Şikayet tablosuna kayıt düşüyordu ama
-- **kimse okuyamıyordu** — kurucu bile. Yani birileri bir gönderiyi şikayet
-- ettiğinde uygulama üzerinden yapılabilecek hiçbir şey yoktu.
--
-- Bu yalnızca bir eksik özellik değil: App Store 1.2 maddesi, kullanıcı
-- içeriği barındıran uygulamalardan şikayeti 24 saat içinde değerlendirip
-- içeriği kaldırmayı ve gerekiyorsa hesabı uygulamadan çıkarmayı istiyor.
-- Mağaza notlarımızda bunu yaptığımızı yazıyoruz; bu migration olmadan o
-- cümle doğru değil.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

-- ------------------------------------------------------------ kim moderatör
--
-- Rozet `profiles` üzerinde ve oraya yazma yetkisi 20260821170000 ile
-- kaldırıldı; yalnızca `set_badge` verebiliyor. Dolayısıyla bu kontrol
-- güvenli: kimse kendini moderatör ilan edip içerik silemez.
create or replace function public.is_moderator()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and badge in ('founder', 'moderator')
  );
$$;

revoke all on function public.is_moderator() from public, anon;
grant execute on function public.is_moderator() to authenticated;

-- --------------------------------------------------------- içerik kaldırma
--
-- Mevcut "kendi içeriğini yönet" kuralları duruyor; bunlar onların yanına
-- ekleniyor. Postgres izin kurallarını VEYA'lıyor, dolayısıyla normal
-- kullanıcı yine yalnızca kendi içeriğine dokunabiliyor.
drop policy if exists "moderators delete any post" on public.posts;
create policy "moderators delete any post" on public.posts
for delete to authenticated using (public.is_moderator());

drop policy if exists "moderators delete any story" on public.stories;
create policy "moderators delete any story" on public.stories
for delete to authenticated using (public.is_moderator());

drop policy if exists "moderators delete any comment" on public.comments;
create policy "moderators delete any comment" on public.comments
for delete to authenticated using (public.is_moderator());

-- ------------------------------------------------------------- şikayetler
alter table public.reports add column if not exists handled_at timestamptz;
alter table public.reports add column if not exists handled_by uuid references public.profiles(id) on delete set null;
alter table public.reports add column if not exists resolution text
  check (resolution is null or resolution in ('dismissed', 'content_removed', 'account_suspended'));

drop policy if exists "moderators read all reports" on public.reports;
create policy "moderators read all reports" on public.reports
for select to authenticated using (public.is_moderator());

-- Şikayeti yalnızca moderatör kapatabilir. Şikayet eden kendi kaydını
-- değiştiremiyor: "ben hallettim" diyip kaydı kapatmak kimsenin işi değil.
drop policy if exists "moderators resolve reports" on public.reports;
create policy "moderators resolve reports" on public.reports
for update to authenticated
using (public.is_moderator()) with check (public.is_moderator());

grant update (handled_at, handled_by, resolution) on public.reports to authenticated;

-- --------------------------------------------------------- hesap askıya alma
--
-- `is_active = false` olan hesap keşifte çıkmıyor, profili okunmuyor,
-- story'si görünmüyor — bu kural zaten her sorguda var (bkz. 20260817190000).
-- Eksik olan tek şey onu değiştirebilecek bir yoldu.
--
-- `profiles` üzerinde authenticated'ın UPDATE yetkisi yok (20260821170000),
-- o yüzden security definer.
create or replace function public.set_account_active(account uuid, active boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderator privileges required';
  end if;
  -- Moderatör moderatörü askıya alamasın: yetki kavgası ve kaza ihtimali.
  if exists (select 1 from public.profiles where id = account and badge in ('founder', 'moderator')) then
    raise exception 'Cannot suspend a moderator';
  end if;
  update public.profiles set is_active = active where id = account;
end;
$$;

revoke all on function public.set_account_active(uuid, boolean) from public, anon;
grant execute on function public.set_account_active(uuid, boolean) to authenticated;

-- Askıya alınan hesabın yeni içerik üretememesi gerekiyor; okuma kuralları
-- zaten kapalı ama yazma tarafı açıktı.
create or replace function public.block_inactive_authors()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and is_active) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_block_inactive on public.posts;
create trigger posts_block_inactive before insert on public.posts
for each row execute function public.block_inactive_authors();

drop trigger if exists stories_block_inactive on public.stories;
create trigger stories_block_inactive before insert on public.stories
for each row execute function public.block_inactive_authors();

drop trigger if exists comments_block_inactive on public.comments;
create trigger comments_block_inactive before insert on public.comments
for each row execute function public.block_inactive_authors();

drop trigger if exists messages_block_inactive on public.messages;
create trigger messages_block_inactive before insert on public.messages
for each row execute function public.block_inactive_authors();


-- Migration: 20260821200000_close_profile_insert_hole.sql
-- Normal kullanıcı kendine yetki veremesin.
--
-- 20260821170000, `profiles` üzerindeki UPDATE yetkisini daraltmıştı: artık
-- yalnızca `avatar_path` yazılabiliyor, dolayısıyla kimse kendi satırındaki
-- `badge`'i değiştiremiyor.
--
-- Ama INSERT yetkisi duruyordu (20260817133000'de verilmiş, hiç geri
-- alınmamış) ve izin kuralı da kendi satırını eklemeye açıktı:
-- "users insert own profile ... with check (id = auth.uid())".
--
-- Yani kullanıcı satırını UPDATE edemiyor ama INSERT edebiliyordu. Sonuç,
-- güncelleme yasağını tamamen delen bir yol:
--
--   1. Yeni kayıt olan biri, `save_my_profile` çalışmadan önce doğrudan
--      /rest/v1/profiles'a badge='founder', is_verified=true yazabiliyordu.
--   2. Var olan biri de yapabiliyordu: DELETE yetkisi de açıktı, kendi
--      satırını silip yerine kurucu rozetli yenisini koyabiliyordu.
--
-- Kurucu rozeti moderasyon yetkisi (bkz. is_moderator) ve otomatik Pro
-- demek. Yani bu, tam yetki yükseltmesiydi.
--
-- Profil oluşturmanın ve silmenin zaten tek meşru yolu var ve ikisi de
-- security definer: `save_my_profile` ve `delete_my_account`. İstemci
-- `profiles` tablosuna doğrudan yalnızca `avatar_path` yazıyor. Dolayısıyla
-- INSERT ve DELETE yetkilerine hiç gerek yok.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

revoke insert, delete on public.profiles from authenticated, anon;

-- Artık işlevsiz kalan izin kurallarını da kaldırıyoruz. Yetki ve izin kuralı
-- birlikte gerekiyor, dolayısıyla yukarıdaki revoke tek başına yeterli. Ama bu
-- açık tam olarak "eski bir migration'daki yetkinin niyetten uzun yaşaması"
-- yüzünden oluştu; kural da dururken ileride biri yetkiyi geri verirse kapı
-- sessizce açılır. İkisini birden kapatıyoruz.
drop policy if exists "users insert own profile" on public.profiles;
drop policy if exists "users delete own profile" on public.profiles;

-- ------------------------------------------------- aynı sınıftan iki küçük iş
--
-- Bu açığın sınıfı şu: "sütunu güncelleyemiyorsun ama satırı eklerken
-- istediğin değeri verebiliyorsun". Aynı desen iki yerde daha vardı.

-- 1) Şikayet, kapatılmış olarak eklenebiliyordu. Yetki kazandırmıyor ama
--    moderatör kaydını taklit ediyor; şikayet kutusundaki geçmişe güvenmek
--    isteriz.
create or replace function public.reports_force_open()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.handled_at := null;
  new.handled_by := null;
  new.resolution := null;
  return new;
end;
$$;

drop trigger if exists reports_force_open on public.reports;
create trigger reports_force_open before insert on public.reports
for each row execute function public.reports_force_open();

-- 2) Yanıt isteği 'accepted' olarak eklenebiliyordu. Bekleyen ikinci isteği
--    engelleyen tekil indeks yalnızca 'pending' satırları kapsıyor;
--    'accepted' yazan biri aynı kişiye günlük tavana kadar üst üste istek
--    gönderebiliyordu. Kabul, eşleşmeyi kuran fonksiyonun işi.
create or replace function public.message_requests_force_pending()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.status := 'pending';
  return new;
end;
$$;

drop trigger if exists message_requests_force_pending on public.message_requests;
create trigger message_requests_force_pending before insert on public.message_requests
for each row execute function public.message_requests_force_pending();


-- Migration: 20260822133000_accept_meeting_creates_match.sql
-- Kabul edilen buluşma isteği karşılıklı niyet sayılır ve gerçek bir sohbet açar.
--
-- İstek durumu ile eşleşme aynı transaction'da değişir. Böylece bağlantı arada
-- koparsa "kabul edildi ama sohbet yok" durumu oluşmaz.

create or replace function public.accept_meeting_request(request uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  kayit public.meeting_requests;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
begin
  if auth.uid() is null then
    raise exception 'Missing session';
  end if;

  select * into kayit
  from public.meeting_requests
  where id = request
    and recipient_id = auth.uid()
    and status = 'pending'
  for update;

  if kayit.id is null then
    raise exception 'Request not found';
  end if;

  if exists (
    select 1
    from public.blocks
    where (blocker_id = kayit.requester_id and blocked_id = kayit.recipient_id)
       or (blocker_id = kayit.recipient_id and blocked_id = kayit.requester_id)
  ) then
    raise exception 'Profile unavailable';
  end if;

  ilk := least(kayit.requester_id, kayit.recipient_id);
  ikinci := greatest(kayit.requester_id, kayit.recipient_id);

  -- Keşif eşleşmesiyle aynı kilit: iki farklı akış aynı anda aynı çifti
  -- oluşturmaya çalışırsa tek bir eşleşme satırı kalır.
  perform pg_advisory_xact_lock(
    hashtextextended(ilk::text || ':' || ikinci::text, 0)
  );

  select id into eslesme
  from public.matches
  where user_a = ilk and user_b = ikinci
  for update;

  if eslesme is null then
    insert into public.matches (user_a, user_b, unmatched_at)
    values (ilk, ikinci, null)
    returning id into eslesme;

    -- `matches` insert trigger'ı iki tarafa "beğeni eşleşmesi" bildirimi üretir.
    -- Burada kaynak buluşma kabulüdür; gönderen aşağıdaki status update trigger'ından
    -- doğru bildirimi alır, kabul eden ise zaten bu akışın içindedir.
    delete from public.notifications
    where kind = 'match' and match_id = eslesme;
  else
    update public.matches
    set unmatched_at = null
    where id = eslesme;
  end if;

  -- Kota ve kabul bildirimi trigger'ları bu update ile atomik olarak çalışır.
  update public.meeting_requests
  set status = 'accepted'
  where id = request;

  return eslesme;
end;
$$;

revoke all on function public.accept_meeting_request(uuid) from public, anon;
grant execute on function public.accept_meeting_request(uuid) to authenticated;


-- Migration: 20260823170000_avatar_readable_with_public_content.sql
-- Profil fotoğrafı: gönderisi olan biri profilde görünürken PP boş kalıyordu.
--
-- `can_read_media` profil fotoğrafları için `discovery_enabled` istiyordu.
-- Gönderi/story paylaşmış hesaplar profil satırında görünür (bkz.
-- `users view relevant profiles`) ama keşiften kapalıysa storage imzası
-- reddediliyordu. Sahibi kendi PP'sini görüyor (owner bypass), başkası
-- gradient placeholder görüyordu.
--
-- Düzeltme: profil-photos için discovery şartı kalkar; doğrulanmış + aktif
-- sahip ve kayıtlı avatar/galeri yolu yeterli. Engelli çiftler hâlâ kapalı.
--
-- Idempotent.

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
        or (media_bucket = 'story-media' and exists (
          select 1 from public.stories s
          where s.author_id = owner_uuid and s.media_path = media_name and s.expires_at > now()
        ))
        or (media_bucket = 'profile-photos' and exists (
          select 1 from public.profiles p
          where p.id = owner_uuid
            and p.is_verified
            and p.is_active
            and (
              p.avatar_path = media_name
              or exists (
                select 1 from public.profile_photos photo
                where photo.profile_id = owner_uuid and photo.storage_path = media_name
              )
            )
        ))
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


-- Migration: 20260823200000_founder_discovery_refresh.sql
-- Kurucu/moderatör "Yenile" ile desteyi gerçekten sıfırlayabilsin.
--
-- Normal kullanıcıda yalnızca 'pass' silinir (beğeniler/eşleşmeler korunur).
-- Staff hesapta eşleşmeye dönüşmemiş tüm tepkiler silinir — test ederken
-- herkesi geçtikten sonra Yenile'nin boş dönmesi kurucuyu kilitliyordu.
--
-- Idempotent.

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


-- Migration: 20260823210000_founder_refresh_clears_all_reactions.sql
-- Kurucu Yenile: eşleşmiş olsa bile tepkileri temizle.
--
-- Önceki sürüm eşleşmeli kişilerin reaction'ını bırakıyordu; test hesabında
-- herkes eşleşince Yenile yine boş desteyle dönüyordu. Sohbet/eşleşme satırı
-- durur, yalnızca keşif filtresindeki reaction kalkar.
--
-- Idempotent.

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


-- Migration: 20260823211000_founder_admirers.sql
-- Kurucuya özel: hesabımı kimler sağa kaydırdı.
--
-- `reactions` üzerindeki okuma kuralı herkese yalnızca KENDİ yaptığı beğenileri
-- gösteriyor (bkz. 20260817133000, "users read own reactions"). Kendisine gelen
-- beğeniyi kimse göremiyor; bu fonksiyon o kuralın tek istisnası.
--
-- İki bilinçli kısıt var:
--
--   1. Rozet kontrolü `is_moderator()` değil, doğrudan 'founder'. Moderatör
--      rozeti ileride başkasına verilirse o kişi bu listeyi görmemeli.
--
--   2. Fonksiyon parametre almıyor. Yani "şu kişiyi kimler beğendi" diye
--      sorulamıyor — yalnızca çağıranın kendi hesabına geleni döndürüyor.
--      Parametre alsaydı kurucu bütün kullanıcıların beğenilerini okuyabilirdi;
--      bu, kullanıcı mahremiyetinde kalıcı bir delik olurdu.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

create or replace function public.who_liked_me()
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
  liked_at timestamptz,
  is_matched boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  -- Tablo alan adları (`id`, `badge`, ...) bu fonksiyonda aynı zamanda birer
  -- değişken. Niteleyici olmadan yazılırsa Postgres "ambiguous column
  -- reference" hatası veriyor; o yüzden her kolon takma adla yazılı.
  if not exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.badge = 'founder'
  ) then
    raise exception 'Founder privileges required';
  end if;

  return query
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
    r.updated_at,
    exists (
      select 1 from public.matches m
      where m.user_a = least(p.id, auth.uid())
        and m.user_b = greatest(p.id, auth.uid())
        and m.unmatched_at is null
    )
  from public.reactions r
  join public.profiles p on p.id = r.actor_id
  where r.subject_id = auth.uid()
    and r.kind = 'like'
    -- Askıya alınmış hesaplar listede görünmesin: uygulamanın geri kalanında
    -- da `is_active = false` olan profil hiçbir yerde çıkmıyor.
    and p.is_active
    -- Engellediğin ya da seni engelleyen biri listede durmasın.
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by r.updated_at desc;
end;
$$;

revoke all on function public.who_liked_me() from public, anon;
grant execute on function public.who_liked_me() to authenticated;


-- Migration: 20260824090000_profile_photos_readable_for_members.sql
-- Post / akış avatarları hâlâ boş: imza RLS'te takılıyordu.
--
-- `avatar_path = media_name` birebir eşleşmesi bazı kayıtlarda (eski path,
-- büyük/küçük harf, silinmiş-yeniden yüklenmiş dosya) imzayı düşürüyordu.
-- Gönderi medyası çalışırken PP'nin boş kalması buydu.
--
-- Doğrulanmış + aktif birinin profile-photos klasörü, engelli değilse
-- diğer doğrulanmış üyelere okunur. discovery_enabled şartı yok.
--
-- Idempotent.

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
        or (media_bucket = 'story-media' and exists (
          select 1 from public.stories s
          where s.author_id = owner_uuid and s.media_path = media_name and s.expires_at > now()
        ))
        or (media_bucket = 'profile-photos' and exists (
          select 1 from public.profiles p
          where p.id = owner_uuid and p.is_verified and p.is_active
        ))
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


-- Migration: 20260824120000_ghost_mode_and_push.sql
-- Hayalet mod sunucuda da zorunlu. Eskiden yalnızca istemci ziyaret/izleme
-- isteğini göndermiyordu; uygulamayı kurcalayan biri aynı RPC'yi yine de
-- çağırabilirdi. Kolon + RPC + trigger: hayaletken iz bırakılmaz.
--
-- Push: bildirim satırı oluşunca Edge Function'ı çağıran tetikleyici.
-- Vault'ta `project_url` ve `service_role_key` yoksa sessizce geçer;
-- o durumda Dashboard → Database → Webhooks ile `send-push` bağlanır.
--
-- Idempotent.

alter table public.profiles
  add column if not exists ghost_mode boolean not null default false;

-- Pro (veya kurucu/moderatör) değilken açık sayılmaz. Kolon true kalsa bile
-- abonelik bitince iz bırakmama hakkı düşer.
create or replace function public.is_acting_ghost(account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.ghost_mode from public.profiles p where p.id = account
  ), false)
  and public.plan_of(account) = 'pro';
$$;

revoke all on function public.is_acting_ghost(uuid) from public, anon, authenticated;

create or replace function public.set_ghost_mode(enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if enabled and public.plan_of(auth.uid()) is distinct from 'pro' then
    raise exception 'ghost_mode requires pro';
  end if;
  update public.profiles
     set ghost_mode = enabled
   where id = auth.uid();
end;
$$;

revoke all on function public.set_ghost_mode(boolean) from public, anon;
grant execute on function public.set_ghost_mode(boolean) to authenticated;

-- Ziyaret: hayaletken satır açılmaz / sayaç artmaz.
create or replace function public.record_profile_visit(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or target is null or target = auth.uid() then return; end if;
  if public.is_acting_ghost(auth.uid()) then return; end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = target)
       or (b.blocker_id = target and b.blocked_id = auth.uid())
  ) then return; end if;
  if not exists (select 1 from public.profiles p where p.id = target and p.is_active) then return; end if;

  insert into public.profile_visits (profile_id, visitor_id)
  values (target, auth.uid())
  on conflict (profile_id, visitor_id) do update
    set visit_count = public.profile_visits.visit_count + 1,
        last_visited_at = now();
end;
$$;

revoke all on function public.record_profile_visit(uuid) from public, anon;
grant execute on function public.record_profile_visit(uuid) to authenticated;

-- Story izleme: INSERT/UPDATE hayaletken yutulur.
create or replace function public.skip_ghost_story_view()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_acting_ghost(new.viewer_id) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists story_views_skip_ghost on public.story_views;
create trigger story_views_skip_ghost
  before insert or update on public.story_views
  for each row execute function public.skip_ghost_story_view();

-- Kendi profilimde hayalet tercihini görmek için.
drop function if exists public.get_my_profile();
create or replace function public.get_my_profile()
returns table (
  name text, birth_date date, gender public.profile_gender,
  dating_preference public.dating_preference,
  relationship_intent public.relationship_intent,
  university text, department text, academic_year text, bio text,
  badge public.profile_badge,
  interests text[], prompt_keys text[], prompt_answers text[],
  min_age smallint, max_age smallint, academic_years text[], departments text[],
  require_common_interest boolean, campus_only boolean,
  ghost_mode boolean
)
language sql stable security definer set search_path = '' as $$
  select
    p.name, p.birth_date, p.gender, p.dating_preference, p.relationship_intent,
    p.university, p.department, p.academic_year, p.bio, p.badge,
    coalesce((select array_agg(pi.interest order by pi.interest) from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce(dp.min_age, 18::smallint),
    coalesce(dp.max_age, 30::smallint),
    coalesce(dp.academic_years, '{}'),
    coalesce(dp.departments, '{}'),
    coalesce(dp.require_common_interest, false),
    coalesce(dp.campus_only, true),
    p.ghost_mode
  from public.profiles p
  left join public.discovery_preferences dp on dp.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- Bildirim satırı → APNs. Sır yoksa no-op; insert asla düşmez.
create or replace function public.push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  service_key text;
begin
  begin
    select ds.decrypted_secret into project_url
      from vault.decrypted_secrets ds
     where ds.name = 'project_url'
     limit 1;
    select ds.decrypted_secret into service_key
      from vault.decrypted_secrets ds
     where ds.name = 'service_role_key'
     limit 1;
  exception
    when undefined_table then
      return new;
    when undefined_object then
      return new;
  end;

  if project_url is null or service_key is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', to_jsonb(new)
    )
  );
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists notifications_send_push on public.notifications;
create trigger notifications_send_push
  after insert on public.notifications
  for each row execute function public.push_on_notification();


-- Migration: 20260824130000_story_video.sql
-- Story videosu. Gönderi (post-media) bilinçli olarak dokunulmuyor:
-- akış hâlâ yalnızca fotoğraf.
--
-- Yeni kolonlar varsayılan 'image': mevcut fotoğraf story'leri ve eski
-- istemci aynı insert ile çalışmaya devam eder. Video satırında süre
-- (en fazla 15 sn) ve kapak JPEG zorunlu.
--
-- Idempotent.

alter table public.stories
  add column if not exists media_kind text not null default 'image';

alter table public.stories
  add column if not exists duration_ms integer;

alter table public.stories
  add column if not exists poster_path text;

update public.stories set media_kind = 'image' where media_kind is null or media_kind = '';

alter table public.stories drop constraint if exists stories_media_kind_check;
alter table public.stories
  add constraint stories_media_kind_check
  check (media_kind in ('image', 'video'));

alter table public.stories drop constraint if exists stories_video_fields;
alter table public.stories
  add constraint stories_video_fields check (
    (media_kind = 'image'
      and duration_ms is null
      and poster_path is null)
    or (media_kind = 'video'
      and duration_ms between 1 and 15000
      and poster_path is not null
      and poster_path like author_id::text || '/%')
  );

alter table public.stories drop constraint if exists story_poster_owned_path;
alter table public.stories
  add constraint story_poster_owned_path check (
    poster_path is null or poster_path like author_id::text || '/%'
  );

-- Kapak dosyası da story medyası gibi okunabilsin.
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
        or (media_bucket = 'story-media' and exists (
          select 1 from public.stories s
          where s.author_id = owner_uuid
            and s.expires_at > now()
            and (s.media_path = media_name or s.poster_path = media_name)
        ))
        or (media_bucket = 'profile-photos' and exists (
          select 1 from public.profiles p
          where p.id = owner_uuid and p.is_verified and p.is_active
        ))
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

-- Yalnızca story bucket: mp4 + 30 MB. post-media aynı (görsel, 10 MB).
update storage.buckets
set
  file_size_limit = 31457280,
  allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/heic', 'image/webp', 'video/mp4'
  ]
where id = 'story-media';


-- Migration: 20260824170000_profile_photos_select_policy.sql
-- Profil fotoğrafları: SELECT politikası foldername::uuid hata verince
-- tüm satırı reddediyordu. İmzalı URL GET bazen çalışır, Storage download
-- (JWT) ise bu yüzden 403 olur — hesap değişince PP boş kalıyordu.
--
-- Yeni politika: uuid cast yok. Doğrulanmış üye, engelli değilse başka
-- doğrulanmış üyenin profile-photos klasörünü okur. Sahip kendi klasörünü
-- her zaman okur. Mevcut "members read permitted media" OR ile duruyor.
--
-- Idempotent.

create or replace function public.media_owner_id(object_name text)
returns uuid
language sql
stable
parallel safe
set search_path = ''
as $$
  select case
    when split_part(trim(both '/' from object_name), '/', 1)
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(trim(both '/' from object_name), '/', 1)::uuid
    else null
  end;
$$;

revoke all on function public.media_owner_id(text) from public, anon;
grant execute on function public.media_owner_id(text) to authenticated;

drop policy if exists "verified members read profile photos" on storage.objects;
create policy "verified members read profile photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and public.media_owner_id(name) is not null
  and (
    public.media_owner_id(name) = auth.uid()
    or (
      exists (
        select 1 from public.profiles reader
        where reader.id = auth.uid() and reader.is_verified and reader.is_active
      )
      and exists (
        select 1 from public.profiles owner
        where owner.id = public.media_owner_id(name)
          and owner.is_verified
          and owner.is_active
      )
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = public.media_owner_id(name))
           or (b.blocker_id = public.media_owner_id(name) and b.blocked_id = auth.uid())
      )
    )
  )
);

-- Eski politika uuid cast'te patlamasın.
drop policy if exists "members read permitted media" on storage.objects;
create policy "members read permitted media" on storage.objects
for select to authenticated using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and public.media_owner_id(name) is not null
  and public.can_read_media(public.media_owner_id(name), bucket_id, name)
);


-- Migration: 20260824190000_storage_read_grants.sql
-- Önceki 20260824170000 media_owner_id'yi PUBLIC'ten aldı ve tüm
-- storage SELECT politikasını ona bağladı. Storage RLS bu fonksiyonu
-- çalıştıramazsa profil/post/story medyası 403 olur — PP'ler boş kalır.
--
-- Bu dosya:
-- 1) fonksiyonu SECURITY DEFINER yapıp her role execute verir
-- 2) profile-photos için fonksiyon kullanmayan LIKE politikası koyar
-- 3) post/story okumasını eski güvenli regex + can_read_media'ya döndürür
--
-- Idempotent.

create or replace function public.media_owner_id(object_name text)
returns uuid
language sql
stable
parallel safe
security definer
set search_path = pg_catalog, public
as $$
  select case
    when split_part(trim(both '/' from object_name), '/', 1)
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(trim(both '/' from object_name), '/', 1)::uuid
    else null
  end;
$$;

grant execute on function public.media_owner_id(text) to public, anon, authenticated, service_role;
grant execute on function public.can_read_media(uuid, text, text) to public, anon, authenticated, service_role;

drop policy if exists "verified members read profile photos" on storage.objects;
create policy "verified members read profile photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and (
    lower(name) like auth.uid()::text || '/%'
    or (
      exists (
        select 1 from public.profiles reader
        where reader.id = auth.uid()
          and reader.is_verified
          and reader.is_active
      )
      and exists (
        select 1 from public.profiles owner
        where owner.is_verified
          and owner.is_active
          and lower(name) like owner.id::text || '/%'
      )
      and not exists (
        select 1
        from public.blocks b
        join public.profiles owner
          on lower(name) like owner.id::text || '/%'
        where (b.blocker_id = auth.uid() and b.blocked_id = owner.id)
           or (b.blocker_id = owner.id and b.blocked_id = auth.uid())
      )
    )
  )
);

drop policy if exists "members read permitted media" on storage.objects;
create policy "members read permitted media"
on storage.objects
for select
to authenticated
using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_read_media(
    ((storage.foldername(name))[1])::uuid,
    bucket_id,
    name
  )
);


-- Migration: 20260824200000_profile_photos_auth_read.sql
-- Profil fotoğrafları hâlâ 403: önceki kural okuyan ve sahibi
-- is_verified + is_active istiyordu. E-posta doğrulaması düşmüş
-- hesaplarda PP boş kalıyordu. Gönderisi görünen birinin fotoğrafı
-- da görünmeli.
--
-- Giriş yapmış kullanıcı profile-photos okuyabilir. Engellenen çift
-- uygulamanın kendi listesinde zaten yok; dosya yolu UUID.
--
-- Idempotent.

drop policy if exists "verified members read profile photos" on storage.objects;
drop policy if exists "members read profile photos" on storage.objects;
drop policy if exists "authenticated read profile photos" on storage.objects;

create policy "authenticated read profile photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-photos');


-- Migration: 20260824210000_profile_photos_public_bucket.sql
-- Profil fotoğrafları üye CDN gibi açılsın. Yol UUID içeriyor, klasör
-- listesi anonime kapalı kalır. Uygulama zaten bu fotoğrafları üyelere
-- gösteriyor; GET'in JWT/RLS'e takılması PP'leri boş bırakıyordu.
--
-- Idempotent.

update storage.buckets
set public = true
where id = 'profile-photos';


-- Migration: 20260824220000_profile_photos_public_read.sql
-- Profil fotoğrafları Tanış kartında da boş: public GET 400, oturumlu
-- download da SDK yol kodlamasına takılabiliyor. Bucket public olsun;
-- UUID'li yol listelenmez. Anon/authenticated SELECT, SDK indirmesini
-- de açar.
--
-- Idempotent.

update storage.buckets
set public = true
where id = 'profile-photos';

drop policy if exists "public read profile photos" on storage.objects;
create policy "public read profile photos"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'profile-photos');


-- Migration: 20260824230000_post_limit.sql
-- Kişi başına en fazla 5 gönderi. Akış tavanı (100) herkese ait;
-- bu kural kullanıcının kendi paylaşımını sınırlar. Silince yer açılır.
-- İstemci de keser; tetikleyici atlatmayı kapatır.
--
-- Idempotent.

create or replace function public.enforce_post_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (
    select count(*) from public.posts
    where author_id = new.author_id
  ) >= 5 then
    raise exception 'POST_LIMIT';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_enforce_limit on public.posts;
create trigger posts_enforce_limit
before insert on public.posts
for each row execute function public.enforce_post_limit();


-- Migration: 20260824240000_post_limit_plus_pro.sql
-- 5 gönderi tavanı yalnızca ücretsiz planda. Plus ve Pro sınırsız.
-- Kurucu/moderatör plan_of ile zaten 'pro'.
-- Hata kodu QUOTA_POST: uygulama paywall açıyor.
--
-- Idempotent.

create or replace function public.enforce_post_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  kademe text;
  adet integer;
begin
  kademe := public.plan_of(new.author_id);
  if kademe in ('plus', 'pro') then
    return new;
  end if;

  select count(*) into adet
  from public.posts
  where author_id = new.author_id;

  if adet >= 5 then
    raise exception 'QUOTA_POST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_enforce_limit on public.posts;
create trigger posts_enforce_limit
before insert on public.posts
for each row execute function public.enforce_post_limit();


-- Migration: 20260910091000_content_reports.sql
-- Exact-content reports, validated evidence, and atomic moderation actions.
-- Existing reports remain profile reports (nullable target). No live deployment
-- is performed by adding this file; deploy before releasing the updated app.

alter table public.reports
  add column if not exists target_kind text,
  add column if not exists target_id uuid,
  add column if not exists content_text text,
  add column if not exists content_media_path text,
  add column if not exists content_media_bucket text;

alter table public.reports drop constraint if exists reports_valid_target;
alter table public.reports add constraint reports_valid_target check (
  (target_kind is null and target_id is null)
  or (target_kind is not null and target_kind in ('post', 'story', 'comment', 'message') and target_id is not null)
);
create index if not exists reports_content_target_idx
  on public.reports(target_kind, target_id) where target_id is not null;

-- SECURITY INVOKER deliberately preserves the reporter's SELECT RLS. A guessed
-- private-message ID cannot expose its text or create a report for a stranger.
-- Also protects direct REST inserts: the client cannot forge owner/evidence.
create or replace function public.capture_report_content()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  content_owner uuid;
begin
  new.content_text := null;
  new.content_media_path := null;
  new.content_media_bucket := null;

  if new.target_kind is null and new.target_id is null then
    return new;
  end if;
  if new.target_kind is null or new.target_id is null then
    raise exception 'REPORT_TARGET_REQUIRED';
  end if;

  case new.target_kind
    when 'post' then
      select p.author_id, p.caption, p.media_path
        into content_owner, new.content_text, new.content_media_path
      from public.posts p where p.id = new.target_id;
      if new.content_media_path is not null then new.content_media_bucket := 'post-media'; end if;
    when 'story' then
      select s.author_id, s.caption, s.media_path
        into content_owner, new.content_text, new.content_media_path
      from public.stories s where s.id = new.target_id;
      if new.content_media_path is not null then new.content_media_bucket := 'story-media'; end if;
    when 'comment' then
      select c.author_id, c.body into content_owner, new.content_text
      from public.comments c
      join public.posts p on p.id = c.post_id
      where c.id = new.target_id;
    when 'message' then
      select m.sender_id, m.body into content_owner, new.content_text
      from public.messages m where m.id = new.target_id;
    else
      raise exception 'INVALID_REPORT_TARGET';
  end case;

  if content_owner is null then raise exception 'REPORT_CONTENT_UNAVAILABLE'; end if;
  if content_owner = auth.uid() then raise exception 'CANNOT_REPORT_OWN_CONTENT'; end if;
  new.reported_id := content_owner;
  return new;
end;
$$;

drop trigger if exists reports_capture_content on public.reports;
create trigger reports_capture_content before insert on public.reports
for each row execute function public.capture_report_content();

create or replace function public.report_content(
  content_kind text, content_id uuid, report_reason public.report_reason,
  report_details text default null
)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  new_report_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if content_kind is null or content_id is null then raise exception 'REPORT_TARGET_REQUIRED'; end if;
  insert into public.reports (reporter_id, target_kind, target_id, reason, details)
  values (auth.uid(), content_kind, content_id, report_reason, nullif(btrim(report_details), ''))
  returning id into new_report_id;
  return new_report_id;
end;
$$;
revoke all on function public.report_content(text, uuid, public.report_reason, text) from public, anon;
grant execute on function public.report_content(text, uuid, public.report_reason, text) to authenticated;

-- Only a report-resolution transaction may mark content as removed. The old
-- direct UPDATE route could close a report without deleting anything.
drop policy if exists "moderators resolve reports" on public.reports;
revoke update on public.reports from authenticated;
revoke update (handled_at, handled_by, resolution) on public.reports from authenticated;

create or replace function public.resolve_content_report(report_id uuid, report_resolution text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  report public.reports%rowtype;
begin
  if not public.is_moderator() then raise exception 'Moderator privileges required'; end if;
  if report_resolution is null or report_resolution not in ('dismissed', 'content_removed', 'account_suspended') then
    raise exception 'INVALID_REPORT_RESOLUTION';
  end if;
  select * into report from public.reports where id = report_id for update;
  if not found then raise exception 'REPORT_NOT_FOUND'; end if;
  if report.handled_at is not null then
    if report.resolution = report_resolution then return; end if;
    raise exception 'REPORT_ALREADY_RESOLVED';
  end if;

  if report_resolution = 'content_removed' then
    if report.target_kind is null or report.target_id is null then
      raise exception 'REPORT_HAS_NO_CONTENT_TARGET';
    end if;
    -- target IDs are preserved after deletion, so repeats and reports for a
    -- subsequently deleted item remain safe and never delete another row.
    case report.target_kind
      when 'post' then delete from public.posts where id = report.target_id and author_id = report.reported_id;
      when 'story' then delete from public.stories where id = report.target_id and author_id = report.reported_id;
      when 'comment' then delete from public.comments where id = report.target_id and author_id = report.reported_id;
      when 'message' then delete from public.messages where id = report.target_id and sender_id = report.reported_id;
      else raise exception 'INVALID_REPORT_TARGET';
    end case;
  elsif report_resolution = 'account_suspended' then
    perform public.set_account_active(report.reported_id, false);
  end if;

  update public.reports
    set handled_at = now(), handled_by = auth.uid(), resolution = report_resolution
    where id = report.id;
end;
$$;
revoke all on function public.resolve_content_report(uuid, text) from public, anon;
grant execute on function public.resolve_content_report(uuid, text) to authenticated;

-- A moderator can inspect only media referenced by a report. A reported
-- private message is exposed through its captured text, never a whole thread.
create or replace function public.can_read_reported_media(media_bucket text, media_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_moderator() and exists (
    select 1 from public.reports r
    where r.content_media_bucket = media_bucket and r.content_media_path = media_name
  );
$$;
revoke all on function public.can_read_reported_media(text, text) from public, anon;
grant execute on function public.can_read_reported_media(text, text) to authenticated;
drop policy if exists "moderators read reported media" on storage.objects;
create policy "moderators read reported media" on storage.objects for select to authenticated
using (bucket_id in ('post-media', 'story-media') and public.can_read_reported_media(bucket_id, name));


-- Migration: 20260910120000_content_text_safety.sql
-- Baseline text filtering for every client, including older app builds.
-- Prepared locally: apply during the separately authorized Supabase setup.
-- This is deliberately a limited token/phrase filter, not image, video or
-- context-aware moderation. Reports are EXCLUDED so users can quote abuse.
-- Keep the token and phrase lists aligned with ContentSafety.swift.

create or replace function public.content_text_is_blocked(raw_text text)
returns boolean
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  normalized text;
  words text[];
  sentence text;
begin
  normalized := translate(
    lower(normalize(coalesce(raw_text, ''), NFKC)),
    'çğıöşüâîûÇĞİÖŞÜÂÎÛ',
    'cgiosuaiucgiosuaiu'
  );
  normalized := translate(normalized, U&'\200B\200C\200D\2060\FEFF\0307', '');
  select coalesce(array_agg(translate(token, '013457', 'oieast') order by ordinal), '{}'::text[])
  into words
  from regexp_split_to_table(normalized, '[^[:alnum:]]+') with ordinality as pieces(token, ordinal)
  where token <> '';

  if words && array[
    'amk', 'amq', 'aminakoyayim', 'aminakoyim', 'amcik',
    'orospu', 'orospuoglu', 'siktir', 'siktirin', 'siktirgit',
    'sikerim', 'sikeriz', 'sikeyim', 'sikeyin', 'sikicem', 'sikecegim',
    'sikiyorum', 'sikismek', 'yarrak', 'yarragi', 'gotsiken',
    'fuck', 'fucking', 'fucked', 'fucker', 'fuckers', 'fuckoff',
    'motherfucker', 'motherfuckers', 'motherfucking', 'cunt', 'cunts',
    'asshole', 'assholes', 'dickhead', 'dickheads', 'bullshit',
    'porn', 'porno', 'pornhub', 'pornography', 'pornographic',
    'blowjob', 'blowjobs', 'handjob', 'handjobs'
  ] then
    return true;
  end if;

  sentence := ' ' || array_to_string(words, ' ') || ' ';
  return position(' amina koyayim ' in sentence) > 0
      or position(' amina koyim ' in sentence) > 0
      or position(' kill yourself ' in sentence) > 0
      or position(' go die ' in sentence) > 0
      or position(' seni oldurecegim ' in sentence) > 0
      or position(' seni oldururum ' in sentence) > 0
      or position(' sana tecavuz edecegim ' in sentence) > 0;
end;
$$;

create or replace function public.check_content_text_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  column_name text;
  proposed_text text;
begin
  foreach column_name in array tg_argv loop
    proposed_text := to_jsonb(new) ->> column_name;
    -- Updating a like counter/read receipt/other field must not revalidate old
    -- text or make it impossible to moderate a legacy row.
    if tg_op = 'UPDATE' then
      if (to_jsonb(old) ->> column_name) is not distinct from proposed_text then
        continue;
      end if;
    end if;
    if public.content_text_is_blocked(proposed_text) then
      -- No user-written content in errors/logs. The app maps this stable marker
      -- to a localized, actionable message.
      raise exception using errcode = '23514', message = 'CONTENT_BLOCKED';
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function public.content_text_is_blocked(text) from public;
revoke all on function public.check_content_text_before_write() from public;
grant execute on function public.content_text_is_blocked(text) to authenticated, service_role;

drop trigger if exists content_text_safety on public.posts;
create trigger content_text_safety before insert or update of caption, place_name on public.posts
for each row execute function public.check_content_text_before_write('caption', 'place_name');

drop trigger if exists content_text_safety on public.comments;
create trigger content_text_safety before insert or update of body on public.comments
for each row execute function public.check_content_text_before_write('body');

drop trigger if exists content_text_safety on public.stories;
create trigger content_text_safety before insert or update of caption on public.stories
for each row execute function public.check_content_text_before_write('caption');

drop trigger if exists content_text_safety on public.messages;
create trigger content_text_safety before insert or update of body on public.messages
for each row execute function public.check_content_text_before_write('body');

drop trigger if exists content_text_safety on public.message_requests;
create trigger content_text_safety before insert or update of body on public.message_requests
for each row execute function public.check_content_text_before_write('body');

drop trigger if exists content_text_safety on public.profiles;
create trigger content_text_safety before insert or update of name, bio, university, department, academic_year on public.profiles
for each row execute function public.check_content_text_before_write('name', 'bio', 'university', 'department', 'academic_year');

drop trigger if exists content_text_safety on public.profile_interests;
create trigger content_text_safety before insert or update of interest on public.profile_interests
for each row execute function public.check_content_text_before_write('interest');

drop trigger if exists content_text_safety on public.profile_prompts;
create trigger content_text_safety before insert or update of answer on public.profile_prompts
for each row execute function public.check_content_text_before_write('answer');


-- Migration: 20260911010000_private_profile_media.sql
-- Keep historical migrations intact; close all legacy public-photo paths.

update storage.buckets set public = false where id = 'profile-photos';
drop policy if exists "public read profile photos" on storage.objects;
drop policy if exists "authenticated read profile photos" on storage.objects;

create or replace function public.can_read_profile_photo(object_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    public.media_owner_id(object_name) = auth.uid()
    or (
      exists(select 1 from public.profiles r
        where r.id = auth.uid() and r.is_active and r.is_verified)
      and exists(select 1 from public.profiles p
        where p.id = public.media_owner_id(object_name)
          and p.is_active and p.is_verified
          and (p.avatar_path = object_name or exists(
            select 1 from public.profile_photos ph
            where ph.profile_id = p.id and ph.storage_path = object_name)))
      and not exists(select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = public.media_owner_id(object_name))
           or (b.blocked_id = auth.uid() and b.blocker_id = public.media_owner_id(object_name)))
    )
  );
$$;
revoke all on function public.can_read_profile_photo(text) from public, anon;
grant execute on function public.can_read_profile_photo(text) to authenticated;

-- Restrictive guards intersect with every legacy permissive SELECT/ALL policy.
drop policy if exists "profile photo member guard" on storage.objects;
create policy "profile photo member guard" on storage.objects as restrictive
for select to authenticated
using (bucket_id <> 'profile-photos' or public.can_read_profile_photo(name));
drop policy if exists "profile photo anonymous guard" on storage.objects;
create policy "profile photo anonymous guard" on storage.objects as restrictive
for select to anon using (bucket_id <> 'profile-photos');
drop policy if exists "members read registered profile photos" on storage.objects;
create policy "members read registered profile photos" on storage.objects
for select to authenticated
using (bucket_id = 'profile-photos' and public.can_read_profile_photo(name));



-- Migration: 20260911020000_campus_profiles_without_dating.sql
-- Build 3 retires gender-based discovery. Existing legacy values are preserved
-- for compatibility, but new campus profiles do not collect or require them.

alter table public.profiles
  alter column gender drop not null,
  alter column dating_preference drop not null,
  alter column relationship_intent drop not null,
  alter column relationship_intent drop default;

-- Old discovery clients must not keep existing accounts visible after the
-- feature has been removed from the product.
update public.profiles set discovery_enabled = false where discovery_enabled;

create or replace function public.save_my_campus_profile(
  profile_name text,
  profile_birth_date date,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  if coalesce(cardinality(profile_interests), 0) < 3 then
    raise exception 'At least three interests are required';
  end if;

  insert into public.profiles (
    id, name, birth_date, university, department, academic_year, bio,
    discovery_enabled, is_verified
  ) values (
    account_id, btrim(profile_name), profile_birth_date, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio),
    false, true
  ) on conflict (id) do update set
    name = excluded.name,
    birth_date = excluded.birth_date,
    university = excluded.university,
    department = excluded.department,
    academic_year = excluded.academic_year,
    bio = excluded.bio,
    discovery_enabled = false,
    is_verified = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_campus_profile(
  text, date, text, text, text, text, text[]
) from public, anon;
grant execute on function public.save_my_campus_profile(
  text, date, text, text, text, text, text[]
) to authenticated;


-- Migration: 20260911030000_get_campus_people.sql
-- Campus directory replaces swipe discovery. Everyone sees everyone: no gender,
-- dating preference, or discovery_enabled gate. Blocks and ghost mode still hide.

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


-- Migration: 20260911040000_ghost_hides_from_places.sql
-- Ghost mode already hides an account from the campus directory. The place
-- list used the older get_people_at_place without that filter, so paying for
-- invisibility still left you standing in "who's here".

create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    public.activity_label(p.last_active_at)
  from public.profiles p
  where p.visible_place_id = target_place
    and p.visible_until > now()
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not coalesce(p.ghost_mode, false)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

revoke all on function public.get_people_at_place(uuid) from public, anon;
grant execute on function public.get_people_at_place(uuid) to authenticated;


-- Migration: 20260911120000_profile_right_swipes.sql
create table if not exists public.profile_right_swipes (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (actor_id, subject_id),
  constraint profile_right_swipes_not_self check (actor_id <> subject_id)
);

alter table public.profile_right_swipes enable row level security;

drop policy if exists "actors read own right swipes" on public.profile_right_swipes;
create policy "actors read own right swipes" on public.profile_right_swipes
  for select to authenticated using (actor_id = auth.uid());

revoke all on public.profile_right_swipes from public, anon;
grant select on public.profile_right_swipes to authenticated;

create or replace function public.notify_on_profile_right_swipe()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (
    new.subject_id,
    'like',
    'Sizi biri sağa kaydırdı',
    public.profile_display_name(new.actor_id) || ' kartını sağa kaydırdı.',
    new.actor_id
  );
  return new;
end;
$$;

drop trigger if exists profile_right_swipes_notify on public.profile_right_swipes;
create trigger profile_right_swipes_notify
after insert on public.profile_right_swipes
for each row execute function public.notify_on_profile_right_swipe();

create or replace function public.swipe_right_on_profile(subject uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  inserted uuid;
begin
  if actor is null or subject is null or subject = actor then
    raise exception 'Invalid swipe';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = subject and p.is_active and p.is_verified
  ) then
    raise exception 'Profile unavailable';
  end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = actor and b.blocked_id = subject)
       or (b.blocker_id = subject and b.blocked_id = actor)
  ) then
    raise exception 'RIGHT_SWIPE_BLOCKED';
  end if;

  insert into public.profile_right_swipes(actor_id, subject_id)
  values (actor, subject)
  on conflict (actor_id, subject_id) do nothing
  returning subject_id into inserted;

  if inserted is null then
    raise exception 'RIGHT_SWIPE_EXISTS';
  end if;
end;
$$;

revoke all on function public.swipe_right_on_profile(uuid) from public, anon;
grant execute on function public.swipe_right_on_profile(uuid) to authenticated;


commit;

-- Migration: 20260911140000_gate_visits_and_revoke_dating_rpcs.sql
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

-- Migration: 20260911180000_gallery_photo_limit.sql
-- Composer "Kartlara ekle" writes profile_photos. Cap is five cards (0–4);
-- the app stops at 5, but SQL must enforce it and assign the next slot.
begin;

update public.profile_photos
set position = position + 1000;

update public.profile_photos p
set position = r.new_pos
from (
  select id,
    (row_number() over (partition by profile_id order by position, created_at) - 1)::smallint as new_pos
  from public.profile_photos
) r
where p.id = r.id;

delete from public.profile_photos where position > 4;

do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.profile_photos'::regclass
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%position%'
  loop
    execute format('alter table public.profile_photos drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.profile_photos
  add constraint profile_photos_position_check check (position between 0 and 4);

create or replace function public.enforce_gallery_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    select count(*) from public.profile_photos
    where profile_id = new.profile_id
  ) >= 5 then
    raise exception 'gallery_full';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_photos_limit on public.profile_photos;
create trigger profile_photos_limit
before insert on public.profile_photos
for each row execute function public.enforce_gallery_photo_limit();

create or replace function public.append_gallery_photo(p_storage_path text)
returns smallint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_pos smallint;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;
  if p_storage_path is null
     or p_storage_path <> btrim(p_storage_path)
     or p_storage_path not like v_uid::text || '/%' then
    raise exception 'photo_owned_path';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_uid::text));

  select count(*)::smallint into v_pos
  from public.profile_photos
  where profile_id = v_uid;

  if v_pos >= 5 then
    raise exception 'gallery_full';
  end if;

  insert into public.profile_photos (profile_id, storage_path, position)
  values (v_uid, p_storage_path, v_pos);

  return v_pos;
end;
$$;

revoke all on function public.append_gallery_photo(text) from public, anon;
grant execute on function public.append_gallery_photo(text) to authenticated;

commit;

-- Migration: 20260911190000_revoke_campus_people_and_swipes.sql
begin;

revoke all on function public.get_campus_people(integer, integer)
  from public, anon, authenticated;
revoke all on function public.swipe_right_on_profile(uuid)
  from public, anon, authenticated;

commit;

-- Migration: 20260911195000_restore_profile_right_swipe.sql
begin;

revoke all on function public.swipe_right_on_profile(uuid)
  from public, anon;
grant execute on function public.swipe_right_on_profile(uuid)
  to authenticated;

commit;

-- Migration: 20260911200000_founder_only_right_swipe_visibility.sql
begin;

create or replace function public.notify_on_profile_right_swipe()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  subject_is_founder boolean;
begin
  select p.badge = 'founder'
  into subject_is_founder
  from public.profiles p
  where p.id = new.subject_id;

  if coalesce(subject_is_founder, false) then
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (
      new.subject_id,
      'like',
      'Sizi biri sağa kaydırdı',
      public.profile_display_name(new.actor_id) || ' kartını sağa kaydırdı.',
      new.actor_id
    );
  else
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (
      new.subject_id,
      'like',
      'Sizi biri sağa kaydırdı',
      'Kartını biri sağa kaydırdı.',
      null
    );
  end if;

  return new;
end;
$$;

update public.notifications n
set actor_id = null,
    body = 'Kartını biri sağa kaydırdı.'
from public.profiles p
where n.user_id = p.id
  and p.badge is distinct from 'founder'
  and n.kind = 'like'
  and n.title = 'Sizi biri sağa kaydırdı'
  and n.actor_id is not null;

create or replace function public.who_liked_me()
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
  liked_at timestamptz,
  is_matched boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.badge = 'founder'
  ) then
    raise exception 'Founder privileges required';
  end if;

  return query
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
    s.created_at,
    exists (
      select 1 from public.matches m
      where m.user_a = least(p.id, auth.uid())
        and m.user_b = greatest(p.id, auth.uid())
        and m.unmatched_at is null
    )
  from public.profile_right_swipes s
  join public.profiles p on p.id = s.actor_id
  where s.subject_id = auth.uid()
    and p.is_active
  order by s.created_at desc;
end;
$$;

revoke all on function public.who_liked_me() from public, anon;
grant execute on function public.who_liked_me() to authenticated;

commit;

-- Migration: 20260911210000_mutual_right_swipe_creates_match.sql
-- Mutual right-swipe creates a match (DM). One-way swipe stays a ping only.

begin;

create or replace function public.notify_on_profile_right_swipe()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  subject_is_founder boolean;
  is_mutual boolean;
begin
  select exists (
    select 1
    from public.profile_right_swipes s
    where s.actor_id = new.subject_id
      and s.subject_id = new.actor_id
  ) into is_mutual;

  if coalesce(is_mutual, false) then
    return new;
  end if;

  select p.badge = 'founder'
  into subject_is_founder
  from public.profiles p
  where p.id = new.subject_id;

  if coalesce(subject_is_founder, false) then
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (
      new.subject_id,
      'like',
      'Sizi biri sağa kaydırdı',
      public.profile_display_name(new.actor_id) || ' kartını sağa kaydırdı.',
      new.actor_id
    );
  else
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (
      new.subject_id,
      'like',
      'Sizi biri sağa kaydırdı',
      'Kartını biri sağa kaydırdı.',
      null
    );
  end if;

  return new;
end;
$$;

drop function if exists public.swipe_right_on_profile(uuid);

create or replace function public.swipe_right_on_profile(subject uuid)
returns table (matched boolean, match_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  inserted uuid;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
  karsilikli boolean;
begin
  if actor is null or subject is null or subject = actor then
    raise exception 'Invalid swipe';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = subject and p.is_active and p.is_verified
  ) then
    raise exception 'Profile unavailable';
  end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = actor and b.blocked_id = subject)
       or (b.blocker_id = subject and b.blocked_id = actor)
  ) then
    raise exception 'RIGHT_SWIPE_BLOCKED';
  end if;

  insert into public.profile_right_swipes(actor_id, subject_id)
  values (actor, subject)
  on conflict (actor_id, subject_id) do nothing
  returning subject_id into inserted;

  if inserted is null then
    raise exception 'RIGHT_SWIPE_EXISTS';
  end if;

  select exists (
    select 1
    from public.profile_right_swipes s
    where s.actor_id = subject and s.subject_id = actor
  ) into karsilikli;

  if not coalesce(karsilikli, false) then
    return query select false, null::uuid;
    return;
  end if;

  ilk := least(actor, subject);
  ikinci := greatest(actor, subject);

  insert into public.matches(user_a, user_b)
  values (ilk, ikinci)
  on conflict (user_a, user_b) do update set unmatched_at = null
  returning id into eslesme;

  return query select true, eslesme;
end;
$$;

revoke all on function public.swipe_right_on_profile(uuid) from public, anon;
grant execute on function public.swipe_right_on_profile(uuid) to authenticated;

create or replace function public.notify_on_match()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.unmatched_at is not null then return new; end if;
  insert into public.notifications (user_id, kind, title, body, actor_id, match_id)
  values
    (new.user_a, 'match', 'Yeni bağlantı',
     'Sen ve ' || public.profile_display_name(new.user_b) || ' artık bağlantıdasınız.', new.user_b, new.id),
    (new.user_b, 'match', 'Yeni bağlantı',
     'Sen ve ' || public.profile_display_name(new.user_a) || ' artık bağlantıdasınız.', new.user_a, new.id);
  return new;
end;
$$;

commit;
