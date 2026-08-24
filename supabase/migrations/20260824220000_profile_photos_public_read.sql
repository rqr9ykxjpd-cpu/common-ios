-- Profil fotoğrafları Tanış kartında da boş: public GET 400, oturumlu
-- download da SDK yol kodlamasına takılabiliyor. Bucket public olsun;
-- UUID'li yol listelenmez. Anon/authenticated SELECT, SDK indirmesini
-- de açar.
--
-- Idempotent.

begin;

update storage.buckets
set public = true
where id = 'profile-photos';

drop policy if exists "public read profile photos" on storage.objects;
create policy "public read profile photos"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'profile-photos');

commit;
