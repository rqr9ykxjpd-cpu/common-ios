# Common (Campus) — Devir Notu

SwiftUI + Supabase kampüs sosyal/tanışma uygulaması. Bu belge, projeyi devralan
kişi veya araç için mevcut durumu, kurulumu ve karşılaşılan tuzakları anlatır.

---

## 1. Kurulum

```bash
open Campus.xcodeproj
```

**Backend'e bağlanmak için** `Campus/Configuration.local.xcconfig` dosyası gerekir.
Bu dosya `.gitignore`'da — repoda yoktur, elle oluşturulur. Git'e hiç
girmediği için ekibe yeni katılan biri bu dosyayı bir başkasından (Slack/DM,
dosya olarak) elle almak zorunda — repoyu klonlamak yetmez:

```
SUPABASE_SLASH = /
SUPABASE_HOST = ucaatxhjmdfrholysnip.supabase.co
SUPABASE_URL = https:$(SUPABASE_SLASH)$(SUPABASE_SLASH)$(SUPABASE_HOST)

SUPABASE_PUBLISHABLE_KEY = <Supabase panel > Project Settings > API Keys > publishable>

GOOGLE_CLIENT_ID = <Google Cloud Console > iOS OAuth client ID>
GOOGLE_SERVER_CLIENT_ID = <Google Cloud Console > Web application OAuth client ID>
GOOGLE_REVERSED_CLIENT_ID = <GOOGLE_CLIENT_ID'nin ters çevrilmiş hali>
```

> `//` dizisi xcconfig'de yorum başlatır. URL'i doğrudan yazarsan
> (`SUPABASE_URL = https://abc.supabase.co`) değer `https:` olarak kesilir ve
> uygulama sessizce bozuk bir client ile çalışır. Bu yüzden slash'lar
> `SUPABASE_SLASH` değişkenine alınıp birleştiriliyor — yukarıdaki yazım doğrudur.

Bu dosya olmadan uygulama **hiçbir şey yapamaz**: açılır ama her işlem
"Supabase yapılandırması eksik" hatası verir. Demo modu ve örnek veri yoktur.
Yanlış proje URL'siyle de aynı sonuç: uygulama açılır ama giriş dahil hiçbir
şey çalışmaz — hata sessiz olabilir, önce bu dosyadaki `SUPABASE_HOST`'u kontrol edin.

**Supabase projesi:** `ucaatxhjmdfrholysnip.supabase.co`.
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
bkz. "Kurulum adımları"), profil kaydetme/geri yükleme, profil fotoğrafı ve galeri
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

### Kurulum adımları (kod değil, panel işi)

Bunlar tamamlanmadan uygulamaya **hiç giriş yapılamaz**.

1. ✅ **Google Cloud Console** — "iOS" ve "Web application" türünde OAuth
   client ID oluşturuldu (Bundle ID: `com.campus.social`). Üç değer de
   `Campus/Configuration.local.xcconfig`'e yazılı: `GOOGLE_CLIENT_ID` (iOS),
   `GOOGLE_SERVER_CLIENT_ID` (Web — Supabase'in Google provider'ındaki Client ID
   ile AYNI), `GOOGLE_REVERSED_CLIENT_ID` (iOS client ID'nin ters çevrilmiş hali).
2. ✅ **Supabase Auth providers** — Authentication → Providers'ta hem Apple
   (Authorized Client IDs: `com.campus.social`) hem Google (Client ID = Web
   client ID) açık.
3. ✅ **GoogleSignIn-iOS paketi** — `project.pbxproj`'a elle eklendi
   (`XCRemoteSwiftPackageReference "GoogleSignIn-iOS"`), `Package.resolved`'da
   7.1.0'a kilitli. İlk açılışta Xcode paketi otomatik çeker.
4. ✅ **Migration'lar** — `20260818220000_remove_domain_verification.sql`,
   `20260818230000_truthful_active_label.sql`, `20260819000000_drop_profile_prompts.sql`
   sunucuda çalıştırıldı. Üçü de idempotent; yeni bir Supabase projesine
   taşınırsa tekrar sırayla çalıştırmak güvenli.
5. ⬜ **Apple Developer (her makinede ayrı)** — Xcode açan her geliştirici
   kendi makinesinde Signing & Capabilities'te kendi takımını seçmeli; proje
   zaten `Campus/Campus.entitlements` ile "Sign in with Apple" istiyor,
   otomatik imzalama App ID'yi buna göre günceller. Bu, git ile taşınmaz —
   yeni bir Mac'te her seferinde elle yapılır.
6. ⬜ **`Configuration.local.xcconfig` her makinede ayrı** — `.gitignore`'da,
   `git clone`/`git pull` bu dosyayı hiç getirmez. Yeni bir geliştirici repoyu
   çekince uygulama "Supabase yapılandırması eksik" hatasıyla açılır (ya da
   eski/yanlış bir kopyası varsa yanlış projeye bağlanır, hata sessiz kalabilir).
   Dosyanın içeriği (yukarıdaki §1) mevcut bir geliştiriciden elle alınmalı —
   secret değiller (service_role hariç), ama repoya commit edilmemeli.
7. ⬜ **İlk gerçek giriş** — bugüne kadar hiçbir akış canlı sunucuya karşı uçtan
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
URL="https://ucaatxhjmdfrholysnip.supabase.co"
KEY="<publishable key>"
curl -s -o /dev/null -w "%{http_code}\n" \
  "$URL/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
# 401/403 = tablo var, RLS koruyor.  404 = tablo yok.
```

`CODE_REVIEW.md` dosyasında ilk kod incelemesi ve öncelik sırası duruyor;
maddelerin çoğu kapatıldı, tasarım/erişilebilirlik bölümü hâlâ geçerli.
