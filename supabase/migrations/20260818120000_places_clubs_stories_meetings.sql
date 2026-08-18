-- Story'ler, buluşma istekleri, kulüpler ve kampüs yerleri.
--
-- Bunların hiçbirinin tablosu yoktu: hepsi yalnızca uygulamanın belleğinde yaşıyor,
-- uygulama kapanınca kayboluyordu. Kulüpler ve yerler ise kodda sabit listeydi, yani
-- herkese aynı görünüyor ve yönetilemiyordu.
--
-- Bu dosya baştan idempotent yazıldı; tekrar çalıştırmak güvenlidir.

begin;

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

commit;
