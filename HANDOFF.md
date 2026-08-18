# Common (Campus) — Devir Notu

SwiftUI + Supabase kampüs sosyal/tanışma uygulaması. Bu belge, projeyi devralan
kişi veya araç için mevcut durumu, kurulumu ve karşılaşılan tuzakları anlatır.

---

## 1. Kurulum

```bash
open Campus.xcodeproj
```

**Backend'e bağlanmak için** `Campus/Configuration.local.xcconfig` dosyası gerekir.
Bu dosya `.gitignore`'da — repoda yoktur, elle oluşturulur:

```
SUPABASE_URL = https:/$()/dddfioyzdguafjpsfscs.supabase.co
SUPABASE_PUBLISHABLE_KEY = <Supabase panel > Project Settings > API Keys > publishable>
```

> `//` dizisi xcconfig'de yorum başlatır. URL'deki çift eğik çizgi bu yüzden
> `$()` ile bölünerek kaçırılmak zorunda. Yukarıdaki yazım doğrudur.

Bu dosya olmadan uygulama **hiçbir şey yapamaz**: açılır ama her işlem
"Supabase yapılandırması eksik" hatası verir. Demo modu ve örnek veri yoktur.

**Supabase projesi:** `campus`, bölge West EU (Ireland).
Migration'lar `supabase/migrations/` altında, uygulanma sırası dosya adındaki
zaman damgasına göre.

---

## 2. Mimari

- `ProductService` protokolü backend'i soyutlar.
  - `SupabaseProductService` — tek gerçek uygulama
  - `UnconfiguredProductService` — yapılandırma eksikken net hata verir
- `AppState` (`@Observable`) tüm uygulama durumunu tutar, servisi enjekte alır.
- Güvenlik **veritabanı seviyesinde** (RLS + `security definer` RPC'ler).
  İstemciye güvenilmez: bildirimler trigger'larla üretilir, engelleme RPC ile
  yapılır, hassas profil alanları kolon bazlı yetkiyle korunur.

---

## 3. Durum

### Çalışan (backend'e bağlı)
Kimlik doğrulama (Apple + Google, native `id_token` değişimi — e-posta/OTP kaldırıldı,
bkz. "Bekleyen kurulum adımları"), profil kaydetme/geri yükleme, profil fotoğrafı ve galeri
(Storage + imzalı URL), keşif ve eşleşme, gerçek zamanlı mesajlaşma, mesaj
reaksiyonları, gönderi/yorum/beğeni, gönderi kaydetme, engelleme ve şikayet,
bildirimler, story'ler, buluşma istekleri, kulüpler, kampüs yerleri,
yer görünürlüğü, profil ziyaretleri (7 gün saklanır, kişi başına tek satır),
eşleşmeyi bitirme.

**Görünüm:** Koyu mod bir tercih olarak var (Profil > Görünüm: Sistem/Açık/Koyu,
`UserDefaults`'ta saklanır). Karşılama ve kayıt akışı bilinçli olarak her zaman
açık modda — kullanıcı o aşamada ayara ulaşamıyor. Tanış, story, eşleşme anı ve
kayıt sonu ekranları tasarımı gereği her iki modda da koyu (`CampusTheme.canvasDark`).

**Demo modu yoktur.** `Configuration.local.xcconfig` olmadan uygulama açılır ama
her işlem "Supabase yapılandırması eksik" hatası verir (`UnconfiguredProductService`).
Örnek/sahte veri, demo girişi ve demo yönetici yetkileri tamamen kaldırıldı.

### Eksik
- **Push bildirimi** — `device_tokens` tablosu ve `registerDeviceToken` servis
  metodu hazır. Eksik: iOS izin akışı, token kaydı, APNs'e istek atan Edge
  Function. Apple Developer hesabı ve APNs `.p8` anahtarı gerekiyor.
- **Akış performansı** — `fetchFeed` 100 gönderiyi `limit(100)` ile çekiyor ve
  her görseli **tek tek, sırayla** indiriyor (N+1). Sayfalama yok.
  Çözüm: `createSignedUrls` toplu çağrısı + `AsyncImage` ile tembel yükleme.
- **Erişilebilirlik** — Dynamic Type desteklenmiyor (~228 sabit punto),
  lokalizasyon altyapısı yok (tüm metinler Türkçe hardcoded), bazı kontrast
  oranları WCAG AA altında. İkon butonlarının etiketleri tamamlandı.
- **Test yok** — test target'ı bulunmuyor. `ProductService` protokolü zaten
  enjekte edilebilir olduğu için `AppState` testleri düşük maliyetle yazılabilir.
- **Üniversite doğrulaması yok** — `save_my_profile` artık hesabın e-posta
  domain'ini kontrol etmiyor (`20260818220000_remove_domain_verification.sql`).
  Apple/Google hesap e-postaları .edu.tr olmak zorunda değil; bu bilinçli bir
  ürün kararı, geri getirmek istenirse RPC'ye tekrar bir domain kontrolü eklenir.

### Bekleyen kurulum adımları (kod değil, panel işi)

Bunlar tamamlanmadan uygulamaya **hiç giriş yapılamaz**.

1. **Apple Developer** — Xcode → Signing & Capabilities'te takımı seç; proje
   zaten `Campus/Campus.entitlements` ile "Sign in with Apple" iste­ğinde
   bulunuyor, otomatik imzalama App ID'yi buna göre günceller.
2. **Google Cloud Console** — bir "iOS" ve bir "Web application" türünde OAuth
   client ID oluştur (Bundle ID: `com.campus.social`). Üçünü de
   `Campus/Configuration.local.xcconfig`'e yaz: `GOOGLE_CLIENT_ID` (iOS),
   `GOOGLE_SERVER_CLIENT_ID` (Web — Supabase'in Google provider'ındaki Client ID
   ile AYNI olmalı), `GOOGLE_REVERSED_CLIENT_ID` (iOS client ID'nin ters çevrilmiş
   hali).
3. **Supabase Auth providers** — Dashboard → Authentication → Providers →
   Apple'ı aç (Authorized Client IDs'e `com.campus.social` ekle) ve Google'ı aç
   (Client ID = yukarıdaki Web client ID).
4. **GoogleSignIn-iOS paketi** — `project.pbxproj`'a elle eklendi
   (`XCRemoteSwiftPackageReference "GoogleSignIn-iOS"`); ilk açılışta Xcode
   paketi otomatik çeker, elle eklemeye gerek yok.
5. **Bekleyen migration'lar** — sunucuda henüz uygulanmamışsa SQL Editor'de
   sırayla çalıştırın; ikisi de idempotent:
   - `20260818220000_remove_domain_verification.sql`
   - `20260818230000_truthful_active_label.sql` — aktiflik etiketi ("Bu hafta
     aktif" her şeyi yakalıyordu, üç ay girmeyen de öyle görünüyordu).
     Uygulanmazsa uygulama çalışır, yalnızca etiket yanlış kalır.
6. **Apple sağlayıcısı** — Supabase'de şu an **kapalı**. Uygulamada Apple
   düğmesi var; açılmadan basılırsa hata veriyor. Authentication → Providers →
   Apple → aç, Authorized Client IDs'e `com.campus.social`. App Store için de
   gerekli: Google gibi üçüncü taraf girişi sunan uygulamalarda Apple girişi
   zorunlu.
7. **İlk gerçek giriş** — bugüne kadar hiçbir akış canlı sunucuya karşı uçtan
   uca çalıştırılmadı. Kayıt → fotoğraf → eşleşme → mesaj yolu ilk kez burada
   denenecek.

---

## 4. Karşılaşılan tuzaklar

Bunlar bu projede bizzat yaşandı; tekrar düşmemek için not edildi.

1. **`INFOPLIST_KEY_*` özel anahtarları taşımıyor.** Xcode'un bu mekanizması
   yalnızca Apple'ın tanıdığı anahtarlar için çalışıyor. `SUPABASE_URL` gibi
   özel anahtarlar build ayarında doğru çözümlense de Info.plist'e hiç
   yazılmıyordu; uygulama demo modundan çıkamıyordu. Çözüm: gerçek bir
   `Info.plist` (repo kökünde) + `INFOPLIST_FILE`. Dosya `Campus/` klasörünün
   **dışında** olmalı, aksi halde senkronize grup onu kaynak olarak da
   kopyalayıp "Multiple commands produce" hatası veriyor.

2. **OTP doğrulama tipi.** Supabase, kodu hangi akışın ürettiğine göre farklı
   tiplerle doğruluyor: ilk kayıt `signup`, sonraki girişler `magiclink`.
   Tek tip denemek ilk kayıtta "geçersiz kod" hatasına yol açıyor.
   `verifyOTP` artık `.email`, `.signup`, `.magiclink` sırasıyla deniyor.

3. **`RETURNS TABLE` içinde `order by` takma adı.** Hesaplanan sütuna takma ad
   verilmezse `order by compatibility` "column does not exist" hatası veriyor
   ve tüm migration geri alınıyor.

4. **Terminal `pbcopy` UTF-8 bozabiliyor.** Kabuğun `LC_CTYPE` ayarı UTF-8
   değilse Türkçe karakterler tek bayta düşüyor (`ı` → `0xDD`). SQL'i panoya
   kopyalayıp yapıştırmak yerine dosyayı bir editörde açıp kopyalayın.

5. **Migration 1 idempotent değil.** `20260817133000_common_unified_backend.sql`
   içindeki `create type` ifadeleri `if not exists` almıyor; ikinci kez
   çalıştırılamaz. Sonraki migration'ların hepsi idempotent yazıldı.

---

## 5. Doğrulama

Şemanın canlıda doğru olduğunu publishable anahtarla dışarıdan kontrol
edebilirsiniz (DDL çalıştıramaz, yalnızca okur):

```bash
URL="https://dddfioyzdguafjpsfscs.supabase.co"
KEY="<publishable key>"
curl -s -o /dev/null -w "%{http_code}\n" \
  "$URL/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
# 401/403 = tablo var, RLS koruyor.  404 = tablo yok.
```

`CODE_REVIEW.md` dosyasında ilk kod incelemesi ve öncelik sırası duruyor;
maddelerin çoğu kapatıldı, tasarım/erişilebilirlik bölümü hâlâ geçerli.
