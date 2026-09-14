-- Oy gizliliği + kurucu araçları.
-- - Kimin ne oy verdiğini kimse göremez: post_likes / comment_votes artık
--   yalnızca kişinin kendi satırını döndürür (kurucu ve moderatör hepsini görür).
-- - Puan istemcide satır sayarak değil, sunucudaki `score` sütunundan okunur;
--   sütunu oy tetikleyicileri tutar, kullanıcı yazamaz.
-- - Kurucu: gönderiye istediği kadar oy ekler (`boost`), sabitler (`pinned_at`),
--   oy verenleri görür. Hepsi RPC üzerinden, rozet sunucuda kontrol edilir.

begin;

-- --------------------------------------------------------------- sütunlar
alter table public.posts
  add column if not exists score integer not null default 0,
  add column if not exists boost integer not null default 0,
  add column if not exists pinned_at timestamptz;
alter table public.comments
  add column if not exists score integer not null default 0;

update public.posts p
  set score = coalesce((select sum(l.value) from public.post_likes l where l.post_id = p.id), 0);
update public.comments c
  set score = coalesce((select sum(v.value) from public.comment_votes v where v.comment_id = c.id), 0);

create index if not exists posts_pinned_idx on public.posts (pinned_at desc) where pinned_at is not null;

-- ------------------------------------------------- puanı tutan tetikleyiciler
create or replace function public.refresh_post_score()
returns trigger language plpgsql security definer set search_path = '' as $$
declare pid uuid;
begin
  pid := coalesce(new.post_id, old.post_id);
  update public.posts
    set score = coalesce((select sum(value) from public.post_likes where post_id = pid), 0)
    where id = pid;
  return null;
end;
$$;

drop trigger if exists post_likes_score on public.post_likes;
create trigger post_likes_score after insert or update or delete on public.post_likes
for each row execute function public.refresh_post_score();

create or replace function public.refresh_comment_score()
returns trigger language plpgsql security definer set search_path = '' as $$
declare cid uuid;
begin
  cid := coalesce(new.comment_id, old.comment_id);
  update public.comments
    set score = coalesce((select sum(value) from public.comment_votes where comment_id = cid), 0)
    where id = cid;
  return null;
end;
$$;

drop trigger if exists comment_votes_score on public.comment_votes;
create trigger comment_votes_score after insert or update or delete on public.comment_votes
for each row execute function public.refresh_comment_score();

-- ------------------------------------------ kullanıcı bu sütunları yazamaz
-- Tablo düzeyinde update/insert yerine sütun listesi: score, boost, pinned_at
-- yalnızca tetikleyici ve kurucu RPC'leriyle (security definer) değişir.
revoke insert, update on public.posts from authenticated;
grant insert (id, author_id, caption, media_path, place_name, kind) on public.posts to authenticated;
grant update (caption, media_path, place_name, kind) on public.posts to authenticated;

revoke insert, update on public.comments from authenticated;
grant insert (id, post_id, author_id, body) on public.comments to authenticated;
grant update (body) on public.comments to authenticated;

-- ------------------------------------------------------------ oy gizliliği
drop policy if exists "authenticated users view post likes" on public.post_likes;
drop policy if exists "own or staff view post likes" on public.post_likes;
create policy "own or staff view post likes" on public.post_likes
for select to authenticated using (user_id = auth.uid() or public.is_moderator());

drop policy if exists "authenticated users view comment votes" on public.comment_votes;
drop policy if exists "own or staff view comment votes" on public.comment_votes;
create policy "own or staff view comment votes" on public.comment_votes
for select to authenticated using (user_id = auth.uid() or public.is_moderator());

-- ---------------------------------------------------------- kurucu araçları
create or replace function public.is_founder()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and badge = 'founder');
$$;
revoke all on function public.is_founder() from public, anon;
grant execute on function public.is_founder() to authenticated;

-- Gönderiye oy ekler (eksi verilirse geri alır); yeni boost değerini döndürür.
create or replace function public.boost_post(target uuid, extra integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare yeni integer;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.posts set boost = greatest(0, boost + extra) where id = target
    returning boost into yeni;
  if yeni is null then raise exception 'Post not found'; end if;
  return yeni;
end;
$$;
revoke all on function public.boost_post(uuid, integer) from public, anon;
grant execute on function public.boost_post(uuid, integer) to authenticated;

create or replace function public.set_post_pinned(target uuid, pinned boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.posts set pinned_at = case when pinned then now() else null end where id = target;
end;
$$;
revoke all on function public.set_post_pinned(uuid, boolean) from public, anon;
grant execute on function public.set_post_pinned(uuid, boolean) to authenticated;

-- Oy verenler: yalnızca kurucu/moderatör.
create or replace function public.get_post_voters(target uuid)
returns table (id uuid, name text, avatar_path text, value smallint, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_moderator() then raise exception 'STAFF_ONLY'; end if;
  return query
    select p.id, p.name, p.avatar_path, l.value, l.created_at
    from public.post_likes l join public.profiles p on p.id = l.user_id
    where l.post_id = target
    order by l.created_at desc;
end;
$$;
revoke all on function public.get_post_voters(uuid) from public, anon;
grant execute on function public.get_post_voters(uuid) to authenticated;

commit;
