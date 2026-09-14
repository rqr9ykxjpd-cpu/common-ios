-- Soru gönderilerinde cevaplar oylanır: en çok oy alan cevap üste çıkar ve
-- kartta "En iyi cevap" olarak görünür. post_likes ile aynı biçim; kişi başı
-- yorum başına bir oy, kendi cevabına oy yok.

begin;

create table if not exists public.comment_votes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.comment_votes enable row level security;

drop policy if exists "authenticated users view comment votes" on public.comment_votes;
create policy "authenticated users view comment votes" on public.comment_votes
for select to authenticated using (true);

drop policy if exists "users manage own comment votes" on public.comment_votes;
create policy "users manage own comment votes" on public.comment_votes
for all to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and not exists (
    select 1 from public.comments c
    where c.id = comment_id and c.author_id = auth.uid()
  )
);

revoke all on public.comment_votes from anon;
grant select, insert, delete on public.comment_votes to authenticated;

commit;
