-- Normal kullanıcı kendine yetki veremesin.
--
-- 20260821170000, `profiles` üzerindeki UPDATE yetkisini daraltmıştı: artık
-- yalnızca `avatar_path` yazılabiliyor, dolayısıyla kimse kendi satırındaki
-- `badge`'i değiştiremiyor.
--
-- Ama INSERT yetkisi duruyordu (20260817133000'de verilmiş, hiç geri
-- alınmamış) ve izin kuralı da kendi satırını eklemeye açıktı:
-- "users insert own profile ... with check (id = auth.uid())".
--
-- Yani kullanıcı satırını UPDATE edemiyor ama INSERT edebiliyordu. Sonuç,
-- güncelleme yasağını tamamen delen bir yol:
--
--   1. Yeni kayıt olan biri, `save_my_profile` çalışmadan önce doğrudan
--      /rest/v1/profiles'a badge='founder', is_verified=true yazabiliyordu.
--   2. Var olan biri de yapabiliyordu: DELETE yetkisi de açıktı, kendi
--      satırını silip yerine kurucu rozetli yenisini koyabiliyordu.
--
-- Kurucu rozeti moderasyon yetkisi (bkz. is_moderator) ve otomatik Pro
-- demek. Yani bu, tam yetki yükseltmesiydi.
--
-- Profil oluşturmanın ve silmenin zaten tek meşru yolu var ve ikisi de
-- security definer: `save_my_profile` ve `delete_my_account`. İstemci
-- `profiles` tablosuna doğrudan yalnızca `avatar_path` yazıyor. Dolayısıyla
-- INSERT ve DELETE yetkilerine hiç gerek yok.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

revoke insert, delete on public.profiles from authenticated, anon;

-- Artık işlevsiz kalan izin kurallarını da kaldırıyoruz. Yetki ve izin kuralı
-- birlikte gerekiyor, dolayısıyla yukarıdaki revoke tek başına yeterli. Ama bu
-- açık tam olarak "eski bir migration'daki yetkinin niyetten uzun yaşaması"
-- yüzünden oluştu; kural da dururken ileride biri yetkiyi geri verirse kapı
-- sessizce açılır. İkisini birden kapatıyoruz.
drop policy if exists "users insert own profile" on public.profiles;
drop policy if exists "users delete own profile" on public.profiles;

-- ------------------------------------------------- aynı sınıftan iki küçük iş
--
-- Bu açığın sınıfı şu: "sütunu güncelleyemiyorsun ama satırı eklerken
-- istediğin değeri verebiliyorsun". Aynı desen iki yerde daha vardı.

-- 1) Şikayet, kapatılmış olarak eklenebiliyordu. Yetki kazandırmıyor ama
--    moderatör kaydını taklit ediyor; şikayet kutusundaki geçmişe güvenmek
--    isteriz.
create or replace function public.reports_force_open()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.handled_at := null;
  new.handled_by := null;
  new.resolution := null;
  return new;
end;
$$;

drop trigger if exists reports_force_open on public.reports;
create trigger reports_force_open before insert on public.reports
for each row execute function public.reports_force_open();

-- 2) Yanıt isteği 'accepted' olarak eklenebiliyordu. Bekleyen ikinci isteği
--    engelleyen tekil indeks yalnızca 'pending' satırları kapsıyor;
--    'accepted' yazan biri aynı kişiye günlük tavana kadar üst üste istek
--    gönderebiliyordu. Kabul, eşleşmeyi kuran fonksiyonun işi.
create or replace function public.message_requests_force_pending()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.status := 'pending';
  return new;
end;
$$;

drop trigger if exists message_requests_force_pending on public.message_requests;
create trigger message_requests_force_pending before insert on public.message_requests
for each row execute function public.message_requests_force_pending();

commit;
