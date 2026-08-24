-- Önceki 20260824170000 media_owner_id'yi PUBLIC'ten aldı ve tüm
-- storage SELECT politikasını ona bağladı. Storage RLS bu fonksiyonu
-- çalıştıramazsa profil/post/story medyası 403 olur — PP'ler boş kalır.
--
-- Bu dosya:
-- 1) fonksiyonu SECURITY DEFINER yapıp her role execute verir
-- 2) profile-photos için fonksiyon kullanmayan LIKE politikası koyar
-- 3) post/story okumasını eski güvenli regex + can_read_media'ya döndürür
--
-- Idempotent.

begin;

create or replace function public.media_owner_id(object_name text)
returns uuid
language sql
stable
parallel safe
security definer
set search_path = pg_catalog, public
as $$
  select case
    when split_part(trim(both '/' from object_name), '/', 1)
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(trim(both '/' from object_name), '/', 1)::uuid
    else null
  end;
$$;

grant execute on function public.media_owner_id(text) to public, anon, authenticated, service_role;
grant execute on function public.can_read_media(uuid, text, text) to public, anon, authenticated, service_role;

drop policy if exists "verified members read profile photos" on storage.objects;
create policy "verified members read profile photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and (
    lower(name) like auth.uid()::text || '/%'
    or (
      exists (
        select 1 from public.profiles reader
        where reader.id = auth.uid()
          and reader.is_verified
          and reader.is_active
      )
      and exists (
        select 1 from public.profiles owner
        where owner.is_verified
          and owner.is_active
          and lower(name) like owner.id::text || '/%'
      )
      and not exists (
        select 1
        from public.blocks b
        join public.profiles owner
          on lower(name) like owner.id::text || '/%'
        where (b.blocker_id = auth.uid() and b.blocked_id = owner.id)
           or (b.blocker_id = owner.id and b.blocked_id = auth.uid())
      )
    )
  )
);

drop policy if exists "members read permitted media" on storage.objects;
create policy "members read permitted media"
on storage.objects
for select
to authenticated
using (
  bucket_id in ('profile-photos', 'post-media', 'story-media')
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_read_media(
    ((storage.foldername(name))[1])::uuid,
    bucket_id,
    name
  )
);

commit;
