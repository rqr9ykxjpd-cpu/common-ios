begin;

create extension if not exists pgcrypto;

create type public.profile_gender as enum ('female', 'male');
create type public.dating_preference as enum ('women', 'men', 'everyone');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  birth_date date not null check (birth_date <= (current_date - interval '18 years')::date),
  gender public.profile_gender not null,
  dating_preference public.dating_preference not null,
  university text not null check (char_length(btrim(university)) between 1 and 120),
  department text not null check (char_length(btrim(department)) between 1 and 120),
  academic_year text not null check (char_length(btrim(academic_year)) between 1 and 40),
  bio text not null default '' check (char_length(bio) <= 220),
  avatar_path text,
  is_verified boolean not null default false,
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

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  caption text not null default '' check (char_length(caption) <= 2200),
  media_path text,
  place_name text check (place_name is null or char_length(btrim(place_name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint post_has_content check (char_length(btrim(caption)) > 0 or media_path is not null),
  constraint post_media_owned_path check (media_path is null or media_path like author_id::text || '/%')
);

create index posts_created_at_idx on public.posts (created_at desc);
create index posts_author_created_at_idx on public.posts (author_id, created_at desc);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index comments_post_created_at_idx on public.comments (post_id, created_at asc);
create index comments_author_idx on public.comments (author_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger posts_set_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

create trigger comments_set_updated_at
before update on public.comments
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.profile_interests enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;

revoke all on public.profiles, public.profile_interests, public.posts, public.comments from anon;
grant select, insert, update, delete on public.profiles, public.profile_interests, public.posts, public.comments to authenticated;

create policy "authenticated users can view profiles"
on public.profiles for select to authenticated
using ((select auth.uid()) is not null);

create policy "users can create their own profile"
on public.profiles for insert to authenticated
with check ((select auth.uid()) = id);

create policy "users can update their own profile"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "users can delete their own profile"
on public.profiles for delete to authenticated
using ((select auth.uid()) = id);

create policy "authenticated users can view interests"
on public.profile_interests for select to authenticated
using ((select auth.uid()) is not null);

create policy "users can add their own interests"
on public.profile_interests for insert to authenticated
with check ((select auth.uid()) = profile_id);

create policy "users can delete their own interests"
on public.profile_interests for delete to authenticated
using ((select auth.uid()) = profile_id);

create policy "authenticated users can view posts"
on public.posts for select to authenticated
using ((select auth.uid()) is not null);

create policy "users can create their own posts"
on public.posts for insert to authenticated
with check ((select auth.uid()) = author_id);

create policy "users can update their own posts"
on public.posts for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

create policy "users can delete their own posts"
on public.posts for delete to authenticated
using ((select auth.uid()) = author_id);

create policy "authenticated users can view comments"
on public.comments for select to authenticated
using ((select auth.uid()) is not null);

create policy "users can create their own comments"
on public.comments for insert to authenticated
with check ((select auth.uid()) = author_id);

create policy "users can update their own comments"
on public.comments for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

create policy "authors and post owners can delete comments"
on public.comments for delete to authenticated
using (
  (select auth.uid()) = author_id
  or exists (
    select 1 from public.posts
    where posts.id = comments.post_id
      and posts.author_id = (select auth.uid())
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('post-media', 'post-media', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "authenticated users can view common media"
on storage.objects for select to authenticated
using (bucket_id in ('avatars', 'post-media'));

create policy "users can upload media to their folder"
on storage.objects for insert to authenticated
with check (
  bucket_id in ('avatars', 'post-media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "users can update media in their folder"
on storage.objects for update to authenticated
using (
  bucket_id in ('avatars', 'post-media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id in ('avatars', 'post-media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "users can delete media in their folder"
on storage.objects for delete to authenticated
using (
  bucket_id in ('avatars', 'post-media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

commit;
