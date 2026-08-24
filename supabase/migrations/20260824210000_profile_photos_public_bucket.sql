-- Profil fotoğrafları üye CDN gibi açılsın. Yol UUID içeriyor, klasör
-- listesi anonime kapalı kalır. Uygulama zaten bu fotoğrafları üyelere
-- gösteriyor; GET'in JWT/RLS'e takılması PP'leri boş bırakıyordu.
--
-- Idempotent.

begin;

update storage.buckets
set public = true
where id = 'profile-photos';

commit;
