-- Story videosu. Gönderi (post-media) bilinçli olarak dokunulmuyor:
-- akış hâlâ yalnızca fotoğraf.
--
-- Yeni kolonlar varsayılan 'image': mevcut fotoğraf story'leri ve eski
-- istemci aynı insert ile çalışmaya devam eder. Video satırında süre
-- (en fazla 15 sn) ve kapak JPEG zorunlu.
--
-- Idempotent.

begin;

alter table public.stories
  add column if not exists media_kind text not null default 'image';

alter table public.stories
  add column if not exists duration_ms integer;

alter table public.stories
  add column if not exists poster_path text;

update public.stories set media_kind = 'image' where media_kind is null or media_kind = '';

alter table public.stories drop constraint if exists stories_media_kind_check;
alter table public.stories
  add constraint stories_media_kind_check
  check (media_kind in ('image', 'video'));

alter table public.stories drop constraint if exists stories_video_fields;
alter table public.stories
  add constraint stories_video_fields check (
    (media_kind = 'image'
      and duration_ms is null
      and poster_path is null)
    or (media_kind = 'video'
      and duration_ms between 1 and 15000
      and poster_path is not null
      and poster_path like author_id::text || '/%')
  );

alter table public.stories drop constraint if exists story_poster_owned_path;
alter table public.stories
  add constraint story_poster_owned_path check (
    poster_path is null or poster_path like author_id::text || '/%'
  );

-- Kapak dosyası da story medyası gibi okunabilsin.
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
          where s.author_id = owner_uuid
            and s.expires_at > now()
            and (s.media_path = media_name or s.poster_path = media_name)
        ))
        or (media_bucket = 'profile-photos' and exists (
          select 1 from public.profiles p
          where p.id = owner_uuid and p.is_verified and p.is_active
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

-- Yalnızca story bucket: mp4 + 30 MB. post-media aynı (görsel, 10 MB).
update storage.buckets
set
  file_size_limit = 31457280,
  allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/heic', 'image/webp', 'video/mp4'
  ]
where id = 'story-media';

commit;
