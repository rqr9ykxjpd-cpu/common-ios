-- Uygulama içi bildirimler. Bu ekran şimdiye kadar yalnızca demo örneklerinden besleniyordu;
-- gerçek kullanıcı eşleşme, mesaj, yorum veya beğeni aldığında hiçbir iz kalmıyordu.
--
-- Bildirimleri istemci oluşturmaz: hepsi veritabanı trigger'larıyla üretilir. Aksi halde
-- istemci başkasının adına bildirim yazabilirdi ve içerik uydurulabilirdi.
--
-- Forward-only; tekrar çalıştırılabilir.

begin;

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

commit;
