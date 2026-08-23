-- Profil fotoğrafı: gönderisi olan biri profilde görünürken PP boş kalıyordu.
--
-- `can_read_media` profil fotoğrafları için `discovery_enabled` istiyordu.
-- Gönderi/story paylaşmış hesaplar profil satırında görünür (bkz.
-- `users view relevant profiles`) ama keşiften kapalıysa storage imzası
-- reddediliyordu. Sahibi kendi PP'sini görüyor (owner bypass), başkası
-- gradient placeholder görüyordu.
--
-- Düzeltme: profil-photos için discovery şartı kalkar; doğrulanmış + aktif
-- sahip ve kayıtlı avatar/galeri yolu yeterli. Engelli çiftler hâlâ kapalı.
--
-- Idempotent.

begin;

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
          where p.id = owner_uuid
            and p.is_verified
            and p.is_active
            and (
              p.avatar_path = media_name
              or exists (
                select 1 from public.profile_photos photo
                where photo.profile_id = owner_uuid and photo.storage_path = media_name
              )
            )
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

commit;
