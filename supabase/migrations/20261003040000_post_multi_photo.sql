-- Gönderide birden fazla fotoğraf (en fazla 6), profil kartındaki gibi kaydırılır.
--
-- `media_paths` sıralı listenin tamamı; ilk eleman eski `media_path` ile aynı.
-- Böylece 1.1 ve 1.1.1 tek fotoğraflı gönderiyi aynen, çoklu gönderinin de ilk
-- fotoğrafını gösterir; hiçbir şey kırılmaz. Tek fotoğrafta liste boş kalır.
begin;

alter table public.posts add column if not exists media_paths text[];

-- Kontrol kısıtında alt sorgu olmaz; her yolun yazarın klasöründe olduğunu bu söyler.
create or replace function public.paths_owned_by(paths text[], owner uuid)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(p like owner::text || '/%'), true) from unnest(paths) as p;
$$;

alter table public.posts drop constraint if exists post_media_paths_valid;
alter table public.posts add constraint post_media_paths_valid check (
  media_paths is null or (
    cardinality(media_paths) between 1 and 6
    and media_path is not distinct from media_paths[1]
    and public.paths_owned_by(media_paths, author_id)
  )
);

-- Kolon bazlı yetki: diğer kolonlar gibi okunur ve yeni gönderide yazılır.
grant select (media_paths), insert (media_paths) on public.posts to authenticated;

-- Fotoğraf okuma izni listedeki her fotoğrafı kapsasın. Gövde canlıdaki
-- tanımdan alındı, tek fark post-media satırı.
create or replace function public.can_read_media(owner_uuid uuid, media_bucket text, media_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select owner_uuid = auth.uid()
    or (
      exists (
        select 1 from public.profiles reader
        where reader.id = auth.uid() and reader.is_active
      )
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = owner_uuid)
           or (b.blocker_id = owner_uuid and b.blocked_id = auth.uid())
      )
      and (
        (media_bucket = 'post-media' and exists (
          select 1 from public.posts p
          where p.author_id = owner_uuid
            and (p.media_path = media_name or media_name = any(p.media_paths))
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

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261003040000', 'post_multi_photo')
on conflict (version) do nothing;

commit;
