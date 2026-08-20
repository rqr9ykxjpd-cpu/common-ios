-- Bir hesabın attığı story diğer hesapta hiç görünmüyordu.
--
-- Story izin kuralı serbest; sorun yazarın profilinde. Profil okuma kuralı
-- şuydu: "bir profili ancak kendinsen, eşleştiysen ya da o kişi GÖNDERİ
-- paylaştıysa görebilirsin." Story sorgusu yazarın profilini de çektiği için,
-- hiç gönderi paylaşmamış birinin story'sinde profil null dönüyor ve uygulama
-- yazarsız story'yi sessizce atıyordu. Yani "yeni hesap açtım, story attım,
-- diğer hesapta görünmüyor" tam olarak beklenen davranıştı.
--
-- Aynı kural altı yeri birden bozuyordu:
--   - story'ler (yazar okunamıyor → story kayboluyor)
--   - yorumlar (yazar okunamıyor → yorum adsız)
--   - story izleyici listesi (izleyen okunamıyor → listede eksik)
--   - bildirimler (bildirimi doğuran kişi okunamıyor)
--   - buluşma istekleri (gönderen/alan okunamıyor)
--
-- Kuralın amacı rastgele profil taramasını engellemekti; o amaç korunuyor.
-- Eklenen maddelerin hepsi ya kişinin kendi isteğiyle herkese açık bir şey
-- yapmış olması (story, yorum) ya da seninle kurulmuş somut bir ilişki
-- (buluşma isteği, story'ni izlemiş olması, sana düşen bir bildirim).
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

drop policy if exists "users view relevant profiles" on public.profiles;

create policy "users view relevant profiles" on public.profiles
for select to authenticated using (
  id = auth.uid()

  -- Eşleştiklerin
  or exists (
    select 1 from public.matches m
    where m.unmatched_at is null
      and ((m.user_a = auth.uid() and m.user_b = profiles.id)
        or (m.user_b = auth.uid() and m.user_a = profiles.id))
  )

  -- Herkese açık içerik paylaşmış olanlar
  or exists (select 1 from public.posts p where p.author_id = profiles.id)
  or exists (
    select 1 from public.stories s
    where s.author_id = profiles.id and s.expires_at > now()
  )
  or exists (select 1 from public.comments c where c.author_id = profiles.id)

  -- Seninle somut ilişkisi olanlar
  or exists (
    select 1 from public.meeting_requests mr
    where (mr.requester_id = auth.uid() and mr.recipient_id = profiles.id)
       or (mr.recipient_id = auth.uid() and mr.requester_id = profiles.id)
  )
  or exists (
    select 1 from public.story_views sv
    join public.stories s on s.id = sv.story_id
    where sv.viewer_id = profiles.id and s.author_id = auth.uid()
  )
  or exists (
    select 1 from public.notifications n
    where n.user_id = auth.uid() and n.actor_id = profiles.id
  )
);

commit;
