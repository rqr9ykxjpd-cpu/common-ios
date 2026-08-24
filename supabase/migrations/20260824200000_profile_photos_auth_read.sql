-- Profil fotoğrafları hâlâ 403: önceki kural okuyan ve sahibi
-- is_verified + is_active istiyordu. E-posta doğrulaması düşmüş
-- hesaplarda PP boş kalıyordu. Gönderisi görünen birinin fotoğrafı
-- da görünmeli.
--
-- Giriş yapmış kullanıcı profile-photos okuyabilir. Engellenen çift
-- uygulamanın kendi listesinde zaten yok; dosya yolu UUID.
--
-- Idempotent.

begin;

drop policy if exists "verified members read profile photos" on storage.objects;
drop policy if exists "members read profile photos" on storage.objects;
drop policy if exists "authenticated read profile photos" on storage.objects;

create policy "authenticated read profile photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-photos');

commit;
