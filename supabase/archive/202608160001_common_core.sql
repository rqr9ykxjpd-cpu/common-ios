create extension if not exists pgcrypto;

create type public.reaction_kind as enum ('pass', 'like');
create type public.report_reason as enum ('spam', 'harassment', 'impersonation', 'underage', 'other');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 40),
  birth_date date not null check (birth_date <= current_date - interval '18 years'),
  university text not null,
  university_domain text not null,
  department text not null,
  bio text not null default '' check (char_length(bio) <= 500),
  interests text[] not null default '{}',
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  position smallint not null check (position between 0 and 5),
  created_at timestamptz not null default now(),
  unique(profile_id, position)
);

create table public.reactions (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  kind public.reaction_kind not null,
  created_at timestamptz not null default now(),
  primary key(actor_id, subject_id),
  check(actor_id <> subject_id)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check(user_a < user_b),
  unique(user_a, user_b)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  reason public.report_reason not null,
  details text check (char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  check(reporter_id <> reported_id)
);

create index reactions_subject_like_idx on public.reactions(subject_id, actor_id) where kind = 'like';
create index messages_match_created_idx on public.messages(match_id, created_at);
create index matches_user_a_idx on public.matches(user_a);
create index matches_user_b_idx on public.matches(user_b);

create or replace function public.create_match_on_mutual_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  first_user uuid;
  second_user uuid;
begin
  if new.kind <> 'like' then return new; end if;
  if exists (
    select 1 from public.reactions
    where actor_id = new.subject_id and subject_id = new.actor_id and kind = 'like'
  ) then
    first_user := least(new.actor_id, new.subject_id);
    second_user := greatest(new.actor_id, new.subject_id);
    insert into public.matches(user_a, user_b)
    values (first_user, second_user)
    on conflict (user_a, user_b) do nothing;
  end if;
  return new;
end;
$$;

create trigger mutual_like_creates_match
after insert or update of kind on public.reactions
for each row execute function public.create_match_on_mutual_like();

create or replace function public.is_match_member(match_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.matches
    where id = match_uuid and (user_a = auth.uid() or user_b = auth.uid())
  );
$$;

alter table public.profiles enable row level security;
alter table public.profile_photos enable row level security;
alter table public.reactions enable row level security;
alter table public.matches enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

create policy "verified profiles are discoverable" on public.profiles for select to authenticated
using (
  (id = auth.uid()) or
  (is_verified and is_active and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = profiles.id)
       or (b.blocker_id = profiles.id and b.blocked_id = auth.uid())
  ))
);
create policy "users insert own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "users update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "photos follow visible profiles" on public.profile_photos for select to authenticated
using (exists (select 1 from public.profiles p where p.id = profile_id));
create policy "users manage own photos" on public.profile_photos for all to authenticated
using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy "users read own reactions only" on public.reactions for select to authenticated using (actor_id = auth.uid());
create policy "users create own reactions" on public.reactions for insert to authenticated with check (actor_id = auth.uid());
create policy "users update own reactions" on public.reactions for update to authenticated using (actor_id = auth.uid()) with check (actor_id = auth.uid());

create policy "members read matches" on public.matches for select to authenticated using (user_a = auth.uid() or user_b = auth.uid());
create policy "members read messages" on public.messages for select to authenticated using (public.is_match_member(match_id));
create policy "members send as themselves" on public.messages for insert to authenticated
with check (sender_id = auth.uid() and public.is_match_member(match_id));
create policy "recipients mark messages read" on public.messages for update to authenticated
using (public.is_match_member(match_id) and sender_id <> auth.uid())
with check (public.is_match_member(match_id));

create policy "users manage own blocks" on public.blocks for all to authenticated
using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy "users create reports" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "users see own reports" on public.reports for select to authenticated using (reporter_id = auth.uid());

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.profile_photos to authenticated;
grant select, insert, update on public.reactions to authenticated;
grant select on public.matches to authenticated;
grant select, insert, update on public.messages to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant select, insert on public.reports to authenticated;
grant execute on function public.is_match_member(uuid) to authenticated;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do nothing;

create policy "authenticated users read profile photos" on storage.objects for select to authenticated
using (bucket_id = 'profile-photos');
create policy "users upload to own folder" on storage.objects for insert to authenticated
with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users update own photos" on storage.objects for update to authenticated
using (bucket_id = 'profile-photos' and owner_id = auth.uid()::text);
create policy "users delete own photos" on storage.objects for delete to authenticated
using (bucket_id = 'profile-photos' and owner_id = auth.uid()::text);
