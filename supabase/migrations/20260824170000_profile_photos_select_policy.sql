-- Profil fotoğrafları: SELECT politikası foldername::uuid hata verince
-- tüm satırı reddediyordu. İmzalı URL GET bazen çalışır, Storage download
-- (JWT) ise bu yüzden 403 olur — hesap değişince PP boş kalıyordu.
--
-- Yeni politika: uuid cast yok. Doğrulanmış üye, engelli değilse başka
-- doğrulanmış üyenin profile-photos klasörünü okur. Sahip kendi klasörünü
-- her zaman okur. Mevcut "members read permitted media" OR ile duruyor.
--
-- Idempotent.

begin;

create or replace function public.media_owner_id(object_name text)
returns uuid
language sql
stable
parallel safe
set search_path = ''
as $$
  select case
    when split_part(trim(both '/' from object_name), '/', 1)
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(trim(both '/' from object_name), '/', 1)::uuid
    else null
  end;
$$;

revoke all on function public.media_owner_id(text) from public, anon;
grant execute on function public.media_owner_id(text) to authenticated;

drop policy if exists "verified members read profile photos" on storage.objects;
create policy "verified members read profile photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and public.media_owner_id(name) is not null
  and (
    public.media_owner_id(name) = auth.uid()
    or (
      exists (
        select 1 from public.profiles reader
        where reader.id = auth.uid() and reader.is_verified and reader.is_active
      )
      and exists (
        select 1 from public.profiles owner
        where owner.id = public.media_owner_id(name)
          and owner.is_verified
          and owner.is_active
      )
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = public.media_owner_id(name))
           or (b.blocker_id = public.media_owner_id(name) and b.blocked_id = auth.uid())
      )
    )
  )
);

-- Eski politika uuid cast'te patlamasın.
drop policy if exists "members read permitted media" on storage.objects;
create policy "members read permitted media" on storage.objects
for select to authenticated using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and public.media_owner_id(name) is not null
  and public.can_read_media(public.media_owner_id(name), bucket_id, name)
);

commit;
