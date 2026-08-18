-- Common social layer: campus posts, stories, comments and optional profile visits.
-- Places are human-readable labels only; exact coordinates are intentionally not stored.

create table public.campus_places (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  area text not null check (char_length(area) between 2 and 80),
  created_at timestamptz not null default now()
);

create table public.social_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  image_path text not null,
  caption text not null default '' check (char_length(caption) <= 2200),
  place_id uuid references public.campus_places(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.post_likes (
  post_id uuid not null references public.social_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create table public.stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  image_path text not null,
  caption text not null default '' check (char_length(caption) <= 500),
  place_id uuid references public.campus_places(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create table public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

create table public.profile_visit_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  sharing_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.profile_visits (
  visitor_id uuid not null references public.profiles(id) on delete cascade,
  visited_id uuid not null references public.profiles(id) on delete cascade,
  visited_at timestamptz not null default now(),
  primary key (visitor_id, visited_id, visited_at),
  check (visitor_id <> visited_id)
);

alter table public.campus_places enable row level security;
alter table public.social_posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.profile_visit_settings enable row level security;
alter table public.profile_visits enable row level security;

create policy "authenticated users read places" on public.campus_places for select to authenticated using (true);
create policy "authenticated users read posts" on public.social_posts for select to authenticated using (true);
create policy "authors manage posts" on public.social_posts for all to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "authenticated users read likes" on public.post_likes for select to authenticated using (true);
create policy "users manage own likes" on public.post_likes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "authenticated users read comments" on public.post_comments for select to authenticated using (true);
create policy "authors create comments" on public.post_comments for insert to authenticated with check (author_id = auth.uid());
create policy "authors delete comments" on public.post_comments for delete to authenticated using (author_id = auth.uid());
create policy "authenticated users read active stories" on public.stories for select to authenticated using (expires_at > now());
create policy "authors manage stories" on public.stories for all to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "story viewers insert own view" on public.story_views for insert to authenticated with check (viewer_id = auth.uid());
create policy "story authors read views" on public.story_views for select to authenticated using (exists (select 1 from public.stories s where s.id = story_id and s.author_id = auth.uid()));
create policy "users manage visit setting" on public.profile_visit_settings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "visitors insert opted-in visits" on public.profile_visits for insert to authenticated with check (
  visitor_id = auth.uid() and coalesce((select sharing_enabled from public.profile_visit_settings where user_id = auth.uid()), true)
);
create policy "visited users read visible visits" on public.profile_visits for select to authenticated using (
  visited_id = auth.uid() and coalesce((select sharing_enabled from public.profile_visit_settings where user_id = visitor_id), true)
);
create policy "visitors delete own visits" on public.profile_visits for delete to authenticated using (visitor_id = auth.uid());

create index social_posts_created_at_idx on public.social_posts(created_at desc);
create index post_comments_post_created_idx on public.post_comments(post_id, created_at);
create index stories_expires_at_idx on public.stories(expires_at);
create index profile_visits_visited_at_idx on public.profile_visits(visited_id, visited_at desc);

insert into storage.buckets (id, name, public)
values ('social-media', 'social-media', false)
on conflict (id) do nothing;

create policy "authenticated social media read" on storage.objects for select to authenticated using (bucket_id = 'social-media');
create policy "users upload own social media" on storage.objects for insert to authenticated with check (
  bucket_id = 'social-media' and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "users update own social media" on storage.objects for update to authenticated using (
  bucket_id = 'social-media' and owner_id = auth.uid()::text
);
create policy "users delete own social media" on storage.objects for delete to authenticated using (
  bucket_id = 'social-media' and owner_id = auth.uid()::text
);
