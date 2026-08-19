-- Gönderi ve story silme çalışmıyordu.
--
-- Cihazdan alınan ham hata:
--   42501 "Direct deletion from storage tables is not allowed.
--          Use the Storage API instead."
--   hint: "This prevents accidental data loss from orphaned objects."
--
-- `cleanup_post_media` ve `cleanup_story_media` tetikleyicileri, satır silinince
-- `storage.objects`'ten de doğrudan siliyordu. Supabase bunu artık veritabanı
-- seviyesinde engelliyor; tetikleyici hata verince silme işleminin tamamı geri
-- sarılıyor ve kullanıcı "Gönderi silinemedi" görüyordu.
--
-- Dosya silme işi istemciye alınıyor: uygulama önce Storage API ile dosyayı
-- siliyor, sonra satırı siliyor. Tetikleyiciler tamamen kaldırılıyor — boş bir
-- gövdeyle bırakmak, ileride okuyan birine hâlâ bir temizlik yapıldığını
-- düşündürürdü.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

drop trigger if exists posts_cleanup_media on public.posts;
drop trigger if exists stories_cleanup_media on public.stories;

drop function if exists public.cleanup_post_media();
drop function if exists public.cleanup_story_media();

commit;

-- Not: bu değişiklikten önce silinmiş gönderilerin dosyaları depolamada kalmış
-- olabilir. Zararsız (kimse erişemiyor, yalnızca yer kaplıyor); istenirse
-- Storage panelinden elle temizlenebilir.
