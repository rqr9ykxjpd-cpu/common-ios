# Bond — Devir Notu

SwiftUI + Supabase kampüs sosyal/tanışma uygulaması. Bu belge, projeyi devralan
kişi veya araç için mevcut durumu, kurulumu ve karşılaşılan tuzakları anlatır.

---

## 1. Kurulum

```bash
cp .env.example .env
# .env içindeki SUPABASE_* ve GOOGLE_* değerlerini doldur
./Scripts/sync-env.sh
open Bond.xcodeproj
```

**Backend'e bağlanmak için** kökteki `.env` gerekir. Bu dosya `.gitignore`'da —
repoda yoktur. Git'e hiç girmediği için ekibe yeni katılan biri değerleri
bir başkasından almak zorunda; `cp .env.example .env` tek başına yetmez.

```
SUPABASE_HOST=<proje-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<Supabase panel > Project Settings > API Keys > publishable>

GOOGLE_CLIENT_ID=<Google Cloud Console > iOS OAuth client ID>
GOOGLE_SERVER_CLIENT_ID=<Google Cloud Console > Web application OAuth client ID>
GOOGLE_REVERSED_CLIENT_ID=<GOOGLE_CLIENT_ID'nin ters çevrilmiş hali>
```

`Scripts/sync-env.sh` üç çıktı üretir (üçü de gitignore'da):

- `Bond/Core/Generated/AppSecrets.swift` — uygulama Supabase URL/key ve Google
  client ID'leri buradan okur. Xcode her derlemede bu script'i Compile Sources'tan
  önce çalıştırır.
- `Config/Generated.xcconfig` — `GOOGLE_CLIENT_ID` Info.plist'teki `GIDClientID`'ye
  (SDK'nın aradığı anahtar).
- `Config/GeneratedInfo.plist` — `Config/Info.plist` kopyası; Google URL scheme
  aynı derlemede literal basılır (`INFOPLIST_FILE`). xcconfig derleme başında
  okunduğu için `$(GOOGLE_REVERSED_CLIENT_ID)` bir build geride kalırdı.
  Paketlenmiş Info.plist'i sonradan yamamak Xcode 26'da "mutable output"
  hatası verir; bu yüzden yalnızca `GeneratedInfo.plist` kullanılır.
  `GOOGLE_REVERSED_CLIENT_ID` boşsa script iOS client ID'den üretir. xcconfig
  `//` dizisini yorum saydığı için `https://` doğrudan yazılmaz; script slash'ı
  `SUPABASE_SLASH` ile birleştirir.

`.env` olmadan uygulama **hiçbir şey yapamaz**: açılır ama her işlem
"Supabase yapılandırması eksik" hatası verir. Demo modu ve örnek veri yoktur
(Release'de). Yanlış proje host'uyla da aynı sonuç: uygulama açılır ama giriş
dahil hiçbir şey çalışmaz — önce `.env` içindeki `SUPABASE_HOST`'u kontrol edin.

**Supabase projesi:** `.env` içindeki host. Migration'lar `supabase/migrations/`
altında, uygulanma sırası dosya adındaki zaman damgasına göre.

Swift kaynakları özellik klasörlerinde durur (`Bond/App`, `Bond/Core`,
`Bond/Features`). Xcode 16 senkronize grup kullandığı için yeni dosyalar
`Bond/` altına konunca hedefe kendiliğinden eklenir. `Config/Info.plist`
bilinçli olarak `Bond/` dışındadır — aksi halde "Multiple commands produce"
hatası çıkar.

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
açık modda — kullanıcı o aşamada ayara ulaşamıyor. Tanış, story ve eşleşme anı
ekranları medya tuvali olarak koyu kalır (`BondTheme.canvasDark`).

Tasarım dili Apple ürün sayfası token'larında: beyaz tuval (`#FFFFFF`),
bölüm yüzeyi (`#F5F5F7`), `#1D1D1F` yazı, `#0071E3` birincil eylem, `#0066CC`
bağlantı. İsimler (`ink`, `paper`, `acid`, `violet`) semantik kaldı; değerler
bu palete çekildi. Kartlarda border/gölge yok, düğmeler pill, SF Pro + Dynamic Type.

**Demo modu yoktur.** `.env` olmadan uygulama açılır ama
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
   client ID oluşturuldu (Bundle ID: `com.bond.social`). Üç değer de
   `.env`'e yazılı: `GOOGLE_CLIENT_ID` (iOS),
   `GOOGLE_SERVER_CLIENT_ID` (Web — Supabase'in Google provider'ındaki Client ID
   ile AYNI), `GOOGLE_REVERSED_CLIENT_ID` (iOS client ID'nin ters çevrilmiş hali).
2. ✅ **Supabase Auth providers** — Authentication → Providers'ta hem Apple
   (Authorized Client IDs: `com.bond.social`) hem Google (Client ID = Web
   client ID) açık.
3. ✅ **GoogleSignIn-iOS paketi** — `project.pbxproj`'a elle eklendi
   (`XCRemoteSwiftPackageReference "GoogleSignIn-iOS"`), `Package.resolved`'da
   **9.2.0**'a kilitli. İlk açılışta Xcode paketi otomatik çeker.

   > 7.1.0'dan yükseltildi ve **geri düşürülmemeli**: nonce'u dışarıdan vermek
   > yalnızca 9.x'te mümkün (`signIn(withPresenting:hint:additionalScopes:nonce:)`).
   > 7.1'de AppAuth kendiliğinden nonce üretiyor, Supabase ise gönderilen nonce'un
   > SHA256'sını token'daki değerle karşılaştırdığı için giriş "nonces mismatch"
   > ile reddediliyordu.
4. ✅ **Migration'lar** — `20260818220000_remove_domain_verification.sql`,
   `20260818230000_truthful_active_label.sql`, `20260819000000_drop_profile_prompts.sql`
   sunucuda çalıştırıldı. Üçü de idempotent; yeni bir Supabase projesine
   taşınırsa tekrar sırayla çalıştırmak güvenli.
5. ⬜ **Apple Developer (her makinede ayrı)** — Xcode açan her geliştirici
   kendi makinesinde Signing & Capabilities'te kendi takımını seçmeli; proje
   zaten `Bond/Resources/Bond.entitlements` ile "Sign in with Apple" istiyor,
   otomatik imzalama App ID'yi buna göre günceller. Bu, git ile taşınmaz —
   yeni bir Mac'te her seferinde elle yapılır.
6. ⬜ **`.env` her makinede ayrı** — `.gitignore`'da,
   `git clone`/`git pull` bu dosyayı hiç getirmez. Yeni bir geliştirici repoyu
   çekince uygulama "Supabase yapılandırması eksik" hatasıyla açılır (ya da
   eski/yanlış bir kopyası varsa yanlış projeye bağlanır, hata sessiz kalabilir).
   Değerler (yukarıdaki §1) mevcut bir geliştiriciden alınmalı —
   publishable key secret değildir (service_role hariç), ama repoya commit edilmemeli.
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
   `Config/Info.plist` şablonu; `INFOPLIST_FILE` derlemede üretilen
   `Config/GeneratedInfo.plist`. Şablon `Bond/` klasörünün **dışında** olmalı,
   aksi halde senkronize grup onu kaynak olarak da kopyalayıp "Multiple commands
   produce" hatası veriyor. Supabase anahtarları artık Info.plist yerine derlemede
   üretilen `AppSecrets.swift` üzerinden okunur; Google URL scheme
   `GeneratedInfo.plist`'e literal basılır (xcconfig bir build geriden gelir).

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

6. **GoogleSignIn `GIDClientID` ister, `GOOGLE_CLIENT_ID` değil.** SDK Info.plist'te
   yalnızca `GIDClientID` / `GIDServerClientID` anahtarlarına bakıyor. Yanlış
   isimle yazılırsa (veya `.env` içindeki `GOOGLE_*` boşsa) giriş
   `NSException`: "No active configuration. Make sure GIDClientID is set in
   Info.plist." ile çöker; Swift `catch` bunu yakalamaz. Değerler `.env` →
   `Generated.xcconfig` → Info.plist yolundan gelir; xcconfig bir build geriden
   kalabileceği için `WelcomeView` aynı değerleri `AppSecrets`'ten de basar.

7. **Google URL scheme xcconfig'ten bir derleme geride kalır.** `AppSecrets`
   (dolayısıyla `GIDConfiguration`) aynı derlemede güncellenir; Info.plist'teki
   `$(GOOGLE_REVERSED_CLIENT_ID)` ise derleme başında okunan xcconfig'i kullanır.
   `.env`'e iOS client ID yazılıp ilk kez derlenince SDK
   "Your app is missing support for the following URL schemes" fırlatır —
   Swift `catch` bunu da yakalamaz. `sync-env.sh` şemayı `GeneratedInfo.plist`'e
   literal basar (`INFOPLIST_FILE`). Paketlenmiş kopyayı yamayan ikinci bir
   script fazı Xcode 26'da "mutable output but no other virtual output node"
   hatası verir; bu yüzden yoktur.

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
