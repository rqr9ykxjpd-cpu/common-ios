# Bond — Kod İncelemesi

**Tarih:** 17 Ağustos 2026
**Kapsam:** 26 Swift dosyası (~6.900 satır) + Supabase şeması (unified migration)

Genel değerlendirme: mimari sağlam. `ProductService` protokolü + demo/backend ayrımı temiz, RLS politikaları düşünülerek yazılmış, RPC'lerde `security definer` ve `search_path` doğru kullanılmış. Asıl problem **UI'ın backend'in çok ilerisinde olması** — ekranların yaklaşık yarısı hâlâ mock veriyle çalışıyor.

---

## 🔴 Kritik — yayına engel

### 1. Sample data production'da görünüyor
`AppState.swift:38-41, 77-79`

`posts`, `stories`, `profileVisits`, `notifications` property initializer'da sample veriyle doluyor ve **demo/backend ayrımı yapılmıyor**. `init` içinde sadece `profiles` ve `conversations` temizleniyor (satır 59-62).

Dahası satır 77-79 koşulsuz çalışıyor: her gerçek kullanıcı uygulamayı açtığında sahte bir "Ece buluşmak istiyor" bildirimi ve buluşma isteği görüyor.

```swift
let incoming = MeetingRequest(profile: StudentProfile.samples[1], ...)
meetingRequests = [incoming]
notifications.insert(AppNotification(kind: .meetingRequest, title: "Ece buluşmak istiyor", ...), at: 0)
```

**Yapılacak:** tüm sample atamalarını `service.isDemo` arkasına al.

### 2. Profil fotoğrafı hiç yok
`Models.swift:53` · `SupabaseProductService.swift:425-464`

DB tarafı hazır: `profile_photos` tablosu, `profile-photos` bucket'ı, `get_discovery_candidates` `avatar_path` döndürüyor. Ama Swift tarafında `avatar_path` hiç decode edilmiyor, hiç upload edilmiyor, `imageURL` her yerde `nil`. Fotoğrafsız bir keşif akışı çalışmaz.

### 3. Avatar ve galeri UserDefaults'ta ham `Data`
`AppState.swift:596-598`

```swift
defaults.set(avatarData, forKey: SessionKey.avatar)
defaults.set(try? JSONEncoder().encode(profileGalleryData), forKey: SessionKey.gallery)
```

UserDefaults binary blob için tasarlanmadı. Birkaç fotoğraf sonrası uygulama açılışı yavaşlar, cihazlar arası senkronizasyon olmaz, hesap silindiğinde sunucuda iz kalmaz. Supabase Storage'a taşınmalı.

### 4. Gizlilik — profil RLS politikası fazla geniş
`migration:381`

```sql
or exists (select 1 from public.posts p where p.author_id = profiles.id)
```

Bir kez gönderi paylaşan herkesin **doğum tarihi, cinsiyeti ve tanışma tercihi** tüm kayıtlı kullanıcılara açık hale geliyor. Akış için yalnızca ad + bölüm + avatar gerekiyor — hassas alanları ayrı bir view'a çıkar veya politikayı daralt.

### 5. Gizlilik — storage herkese açık
`migration:434`

```sql
create policy "authenticated users read common media" on storage.objects
for select to authenticated using (bucket_id in ('profile-photos', 'post-media'));
```

Kayıtlı her kullanıcı, eşleşmediği kişilerin profil fotoğrafları dahil **her dosyayı** indirebiliyor. Signed URL + eşleşme kontrolü gerekiyor.

### 6. Engelleme ve şikayet arayüzü yok
`blocks` ve `reports` tabloları + RLS politikaları hazır, ancak Swift tarafında tek satır kullanım yok. Apple, kullanıcı içeriği barındıran uygulamalarda (App Store Review Guideline 1.2) engelleme, şikayet ve içerik moderasyonunu zorunlu tutuyor. Bu haliyle inceleme reddedilir.

---

## 🟠 Yüksek — özellik yarım kalmış

### 7. Beğeniler kalıcı değil
`AppState.swift:230-235, 622`

`toggleLike` sadece local state'i değiştiriyor. DB'de `post_likes` tablosu yok, backend'den gelen `likeCount` sabit `0`. Uygulama kapanınca beğeniler sıfırlanıyor.

### 8. Mesaj reaksiyonları kalıcı değil
`AppState.swift:510-516` · `migration:418`

`react(to messageID:)` async bile değil, servis çağrısı yok. `messages.reaction` kolonu mevcut ama grant yalnızca `update (read_at)` — yazılmaya çalışılsa RLS reddeder.

### 9. Story / buluşma isteği / kulüpler tamamen mock
Hiçbirinin tablosu yok. `publishStory`, `deleteStory`, `markStoryViewed`, `sendMeetingRequest`, `respondToMeetingRequest`, `toggleClubMembership`, `joinedClubIDs`, `profileVisits` — hepsi yalnızca RAM'de. Uygulama kapanınca kayboluyor.

### 10. Bildirim altyapısı yok
`AppNotification.samples` dışında hiçbir şey yok. APNs entegrasyonu, push token kaydı, sunucu tarafı tetikleyici — hiçbiri mevcut değil. Yeni mesaj veya eşleşmede kullanıcı haberdar olmuyor.

### 11. Realtime yok — sohbet pratikte tek yönlü
Supabase Realtime hiç kullanılmıyor. `loadConversations` yalnızca `PremiumScreens.swift:37`'de, ekran açılırken bir kez çalışıyor. Karşı taraf mesaj gönderdiğinde ekranda görünmüyor.

### 12. Yanıtlanan mesajın bağlamı kayboluyor
`SupabaseProductService.swift:207` + `330-334`

```swift
return row.message(currentUserID: userID, allRows: [row], peerName: "")
```

`replyTo` lookup'ı yalnızca yeni satırı içeren listede arama yapıyor → gönderdiğin yanıt anında "reply" bilgisini kaybediyor.

---

## 🟡 Orta — performans ve dayanıklılık

### 13. `fetchFeed` N+1 + seri indirme
`SupabaseProductService.swift:229-237` — 100 gönderi için 100 ayrı `storage.download`, sırayla. İlk akış yüklemesi çok yavaş. `createSignedUrls` toplu çağrısı + `AsyncImage` ile tembel yükleme gerekiyor.

### 14. `fetchConversations` N+1
`SupabaseProductService.swift:171-187` — her eşleşme için ayrı mesaj sorgusu. Tek sorgu + client-side gruplama, ya da "son mesaj" view'ı olmalı.

### 15. Akışta sayfalama yok
`limit(100)` sabit, sonsuz kaydırma yok.

### 16. Tüm görseller bellekte `Data` olarak tutuluyor
`SocialPost.localImageData` — 100 gönderi × ~2 MB bellek baskısı yaratır, düşük RAM'li cihazlarda çökme riski.

### 17. `last_active_at` hiç güncellenmiyor
`migration:300-302`'deki "Yakın zamanda aktif / Bugün aktif" etiketi herkes için sürekli "Bu hafta aktif" gösteriyor.

### 18. Eşleşme bozma (unmatch) yok
`matches.unmatched_at` kolonu tanımlı ama hiçbir fonksiyon set etmiyor. Kullanıcı bir eşleşmeden çıkamıyor.

---

## 🔵 Altyapı ve süreç

### 19. Hiç test yok
Projede test target'ı bulunmuyor. `ProductService` protokolü ve `DemoProductService` zaten enjekte edilebilir olduğu için `AppState` testleri çok düşük maliyetle yazılabilir — bu fırsat kullanılmamış.

### 20. Migration idempotent değil, geçmiş yeniden yazılmış
`create type` ve `create policy` ifadeleri `if not exists` / `drop if exists` olmadan yazılmış — dosya iki kez çalıştırılamaz. Ayrıca 3 eski migration `supabase/archive/`'a taşınıp tek dosyada birleştirilmiş. Bu migration'lar herhangi bir ortama uygulandıysa o ortamda `supabase db push` bozulur.

### 21. Tek üniversiteye sabitlenmiş
`ProductModels.swift:126` (`accepted = ["yalova.edu.tr"]`) ve `migration:19` (aynı default). Yeni kampüs eklemek hem kod hem migration değişikliği gerektiriyor — `universities` tablosu olmalı.

### 22. `SupabaseProductService` `@unchecked Sendable`
`SupabaseProductService.swift:47` — derleyici eşzamanlılık kontrolü devre dışı bırakılmış. `actor` ya da gerçek `Sendable` uyumu tercih edilmeli.

### 23. `place_name` metinle eşleştiriliyor
`AppState.swift:621` — `CampusPlace.samples.first { $0.name == name }`. Yer adı değişirse bağ kopar; `place_id` foreign key olmalı.

### 24. Versiyon kontrolü
Tek commit var, 11 dosya commit'lenmemiş durumda bekliyor. Migration silme/ekleme işlemleri de commit'lenmemiş.

---

---

## 🎨 Tasarım, erişilebilirlik ve kullanıcı deneyimi

Görsel dil güçlü — editöryel serif başlıklar, asit yeşili aksan, kâğıt dokusu. Tutarlı bir marka kimliği var. Sorun estetikte değil, **sistemleştirmede**: tasarım token'ları tanımlanmış ama tutarlı uygulanmamış, platform standartları atlanmış.

### 25. Dynamic Type hiç desteklenmiyor
Kod tabanında **228 adet** sabit punto (`.font(.system(size: N))`). Kullanıcı iOS ayarlarından yazı boyutunu büyüttüğünde arayüzde hiçbir şey değişmiyor. Erişilebilirlik denetiminden geçmez. Semantik stiller (`.font(.system(.body, design: .rounded))`) veya `@ScaledMetric` kullanılmalı.

### 26. Dark mode yok
`RootView.swift:20, 23, 26` — her rota `.preferredColorScheme(.light)` ile aydınlık moda kilitli. Renkler `Color(hex:)` ile hardcoded, Asset Catalog color set'i yok. Sosyal uygulamalar en yoğun akşam saatlerinde kullanılıyor; bu ciddi bir eksik.

### 27. Lokalizasyon altyapısı yok
Sıfır `LocalizedStringKey` / `String(localized:)` kullanımı — tüm metinler Türkçe hardcoded. Erasmus öğrencileri veya ikinci bir kampüs için İngilizce gerekecek. String Catalog (`.xcstrings`) ile şimdi başlamak, sonradan 200+ string'i dönüştürmekten çok daha ucuz.

### 28. Reduce Motion dikkate alınmıyor
`RootView.swift:151-152` — `repeatForever` ile sürekli dönen float ve glow animasyonları. `accessibilityReduceMotion` hiçbir yerde kontrol edilmiyor. Vestibüler duyarlılığı olan kullanıcılar için rahatsız edici; ayrıca sürekli animasyon pil tüketiyor.

### 29. Kontrast oranları yetersiz
`BondTheme.muted` (#77746D), `paper` (#F2EFE7) üzerinde yaklaşık **4.0:1** — WCAG AA'nın küçük metin için istediği 4.5:1'in altında. Ayrıca `ink.opacity(0.40)`–`0.52` kombinasyonları yaygın kullanılıyor (`RootView.swift:120, 214`) ve bunlar net şekilde başarısız.

### 30. Mesajlar ana navigasyonda yok
`MainTabView.swift:21-23` — sekmeler yalnızca Akış / Tanış / Profil. Sohbetler `PremiumDiscoverView` içine gömülü. Mesajlaşma bir tanışma uygulamasının en sık kullanılan ekranıdır; ana sekme olmalı ve okunmamış rozeti taşımalı.

### 31. `TabView` yerine manuel `switch`
`MainTabView.swift:7-13` — sekme değişiminde ekran state'i sıfırlanıyor (kaydırma pozisyonu, açık sheet'ler), kaydırarak geçiş yok, VoiceOver sekme semantiği yok. Native `TabView` bunların hepsini hazır veriyor.

### 32. Okunmamış rozetleri gösterilmiyor
`unreadNotificationCount` ve `pendingIncomingMeetingRequestCount` `AppState`'te hesaplanıyor ama arayüzde hiç kullanılmıyor.

### 33. Yükleme, boş ve hata durumları eksik
`ProgressView` yalnızca keşif ekranında var (`PremiumScreens.swift:227-235`). Akış ekranında ne yükleme göstergesi ne hata durumu var — `loadFeed` başarısız olursa kullanıcı boş ekran görüyor, hata sadece 2,4 saniyelik toast olarak geçip kayboluyor. Skeleton (`.redacted(reason: .placeholder)`) hiç kullanılmamış.

### 34. Pull-to-refresh yok
Hiçbir listede `.refreshable` yok. Realtime de olmadığı için kullanıcının akışı veya sohbetleri yenilemek için **hiçbir yolu yok** — uygulamayı kapatıp açmak gerekiyor.

### 35. Hata geri bildirimi tutarsız
Aynı sınıftaki hatalar bazen `toast`, bazen `discoveryError` alanına yazılıyor (`AppState.swift:189` / `243` / `446`). `loadConversations` hatası `discoveryError`'a düşüyor — keşif ekranında konuyla alakasız bir hata mesajı beliriyor. Tek bir hata sunum katmanı gerekiyor.

### 36. `GrainOverlay` her çizimde 180 elips üretiyor
`DesignSystem.swift:82-93` — `Canvas` içindeki döngü her yeniden çizimde tekrar koşuyor. Statik doku görseline ya da `drawingGroup()`'a alınmalı.

### 37. Onboarding sonunda kayıt beklenmiyor
`AppState.swift:153-165` — son adımda `saveProfile` bir `Task` içinde ateşlenip sonucu beklenmeden `route = .app` yapılıyor. Kayıt başarısız olursa kullanıcı uygulamaya girmiş ama profili sunucuda yok; keşif boş gelir ve sebebi anlaşılmaz. Sonucu bekleyip hata durumunda adımda kalmalı.

---

## Önerilen sıra

**Faz 1 — Yayın engelleri**

1. Sample data sızıntısını kapat (#1)
2. Profil fotoğrafı: upload, storage, görüntüleme (#2, #3)
3. RLS ve storage gizliliğini daralt (#4, #5)
4. Engelleme ve şikayet akışı (#6)

**Faz 2 — Yarım kalan özellikler**

5. Beğeni tablosu ve kalıcı beğeni (#7)
6. Realtime mesajlaşma + pull-to-refresh (#11, #34)
7. Yanıt bağlamı hatası (#12) ve mesaj reaksiyonları (#8)
8. Story, buluşma isteği, kulüp için tablo ve servis katmanı (#9)
9. Push bildirim altyapısı (#10)

**Faz 3 — Performans**

10. Signed URL + tembel görsel yükleme (#13, #16)
11. Akış sayfalama (#15), sohbet N+1 (#14)

**Faz 4 — Tasarım ve erişilebilirlik**

12. Dynamic Type (#25) ve kontrast düzeltmeleri (#29)
13. Dark mode (#26)
14. Navigasyon: `TabView`, mesaj sekmesi, rozetler (#30, #31, #32)
15. Yükleme / boş / hata durumları ve tutarlı hata sunumu (#33, #35)
16. VoiceOver etiketleri ve Reduce Motion (#28)
17. Lokalizasyon altyapısı (#27)

**Faz 5 — Altyapı**

18. Test target'ı ve `AppState` testleri (#19)
19. Migration idempotency (#20), çoklu üniversite (#21)
20. Eşzamanlılık temizliği (#22), `place_id` FK (#23)
