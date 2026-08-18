-- Gönderi kaydetme (yer imi).
--
-- Akıştaki yer imi butonu yalnızca yerel durumu değiştiriyordu: uygulama kapanınca
-- kayboluyor ve kaydedilenleri görebileceğin bir ekran da yoktu. Yani buton hiçbir
-- işe yaramıyordu.
--
-- Kimin neyi kaydettiği özeldir; post_likes'ın aksine bu tablo yalnızca sahibine açık.
--
-- Idempotent.

begin;

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

commit;
