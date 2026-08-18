begin;

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
  position smallint not null check (position between 0 and 5),
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

commit;
