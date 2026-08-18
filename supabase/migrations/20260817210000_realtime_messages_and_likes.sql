-- Turns on live message delivery and makes post likes persist server-side.
-- Forward-only; safe to re-run.

begin;

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

commit;
