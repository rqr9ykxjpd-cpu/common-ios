Common iOS uygulamasına ilk açılışta bir kez gösterilen bir tanıtım (intro) akışı ekleyeceksin. Kullanıcı giriş ekranını (`WelcomeView`) görmeden önce, 4 sayfada uygulamanın ne olduğunu anlatan, kaydırılabilir, sakin ve animasyonlu bir ekran. Sınırlar kesin.

## Uygulama ne — bunu anlatacaksın

Common, üniversite kampüsleri için bir sosyal ağ. Açık bir tanışma pazarı değil; herkes yalnızca kendi kampüsünü görür. Şu an tek kampüs var: YÜ.

- **Akış:** Soru sor, ders notu paylaş, etkinlik ve duyuru geç. Gönderi türleri: Soru, Duyuru, Ders notu, Etkinlik. 10 saat sonra kaybolan fotoğraf/video Story'ler.
- **Çalışma grubu:** "Bugün 15.00'te Merkez Kütüphane'de Veri Yapıları çalışıyorum" de; katılmak tek dokunuş. Grup başlayınca ev sahibi oturduğu yerin fotoğrafını katılanlarla paylaşır, kimse kimseyi aramaz.
- **Kim nerede:** Kütüphane, kantin, yemekhane… Bir kampüs noktası seç, görünür ol, orada kim var gör. Telefon konumu okunmaz; yalnızca listeden seçtiğin yer görünür.
- **Kulüpler:** Öğrenci kulüplerine tek dokunuşla katıl, etkinlikleri kaçırma.
- **Bağlantı ve sohbet:** Tanımak istediğin birine bağlantı isteği gönder; karşılıklı olursa sohbet açılır. Rahatsız edeni tek dokunuşla engelle, şikâyet et.
- **Öğrenci doğrulaması:** Okul e-postası isteğe bağlı doğrulanır; adres gizli kalır, profilde Öğrenci rozeti görünür.

## Proje

- Yol: `~/Desktop/Campus`, proje `Bond.xcodeproj`, şema `Bond`, bundle `com.campus.social`, iOS 18.
- Derleme:
  `xcodebuild -project Bond.xcodeproj -scheme Bond -configuration Debug -destination 'id=CC26C955-19CB-474E-A66E-40B61B50882B' -derivedDataPath .derived-sim build`
- Simülatör: `CC26C955-19CB-474E-A66E-40B61B50882B`. Uygulama `.derived-sim/Build/Products/Debug-iphonesimulator/Bond.app`; `xcrun simctl install` ile kur.
- Karşılama ekranı sunucusuz: `xcrun simctl launch <udid> com.campus.social -welcome`. Giriş yapma.

## Git kuralları — pazarlık yok

- Çalışma ağacında commit edilmemiş büyük bir iş var, başka biri de aynı ağaçta çalışıyor.
- `git commit`, `git add`, `git reset`, `git checkout`, `git stash`, `git restore`, `git clean` — hiçbirini çalıştırma. Sadece `git status` ve `git diff` serbest.

## Dokunabileceğin dosyalar

- **Yeni:** `Bond/App/AppIntroView.swift` — tanıtım ekranının tamamı burada.
- **Yeni:** `Bond/Core/Localization/L10n+AppIntro.swift` — `L10n.AppIntro.*`, tablo adı `AppIntro`.
- **Yeni:** `Bond/Resources/AppIntro.xcstrings` — metinler, `tr` + `en`. `Localizable.xcstrings`'e **dokunma** (başkası düzenliyor).
- `Bond/App/RootView.swift` — **yalnızca** `case .welcome:` dalı. Dosyada commit edilmemiş başka değişiklikler var; onlara dokunma, sadece hedefli düzenleme.
- `Bond/App/BondApp.swift` — yalnızca `-intro` başlatma argümanı (aşağıda).

## Dokunamayacağın dosyalar

- `Bond/App/WelcomeView.swift`, `Bond/Features/Onboarding/**` — okuyabilirsin, değiştirme.
- `Bond/Core/Design/DesignSystem.swift` — oku, ekleme yapma.
- `Bond/Resources/Localizable.xcstrings`, mevcut `L10n+*.swift` dosyaları.
- `Bond/Core/Services/**`, `Bond/Core/Models/**`, `Bond/Features/**`, `supabase/**`, `store/**`, `docs/**`.

## Elindeki araçlar (`DesignSystem.swift` — hepsi hazır)

- Renkler: `BondTheme.paper / .surface / .ink / .muted / .acid / .onAccent`. Kimlik **siyah-beyaz**. Tek vurgu `BondTheme.burntOrange` (yazıda `burntOrangeText`) — seyrek, en fazla sayfa göstergesinin aktif noktası ya da tek bir ikon. Mavi, mor, gradyan yok.
- `Wordmark(size:)` — logo.
- `.editorialTitle(_:)` — başlık tipi (serif). `BondTheme.Typography.*` gövde metni.
- `PrimaryActionButton` / `PrimaryEditorialButton` — `WelcomeView`'daki ana düğme hangisiyse onu kullan, aynı görünsün.
- `BondTheme.Motion.snappy / .bouncy / .smooth`, `.buttonStyle(.pressable)`, `BondTheme.Space.xs…xxl`, `BondTheme.Radius.surface` / `.media`.
- `Haptics.selection()` sayfa değişince, `Haptics.success()` "Başla"ya basınca.
- Giriş animasyonu kalıbı: `WelcomeView`'daki `appeared` + `.opacity` + `.offset(y:)` + `Motion.smooth.delay(...)` kademeli yapısı. **Kopyala**, o dosyayı değiştirme.
- `RootView` karşılamayı her zaman açık modda zorluyor; intro da açık modda kalsın (aynı `case .welcome` dalında olduğu için kendiliğinden olur).

## Yapılacaklar

1. **Akış yeri.** `RootView` → `case .welcome:` içinde: `@AppStorage("hasSeenAppIntro")` false ise `AppIntroView`, true ise mevcut `WelcomeView`. Geçiş `.transition(.opacity)` + `Motion.smooth`. Intro yalnızca bir kez görünür; çıkış yapan kullanıcı tekrar görmez.
2. **Yapı.** `TabView` + `.tabViewStyle(.page(indexDisplayMode: .never))`, 4 sayfa. Kendi sayfa göstergen: alt kısımda küçük noktalar, aktif olan kapsüle uzar (`Motion.snappy`). Sağ üstte "Geç" (muted, küçük) — son sayfada gizli. Altta tam genişlik ana düğme: ilk 3 sayfada "Devam et", sonda "Başla". Basınca flag true, `WelcomeView`'a geç.
3. **Sayfalar.** Her sayfa: üstte büyük görsel alan (SF Symbols ile kurulmuş sade bir kompozisyon, `surface` zemin üstünde, `Radius.media` köşe), altında editoryal başlık, altında 1–2 cümle muted gövde.
   - **1 · Kampüsün ortak alanı.** `Wordmark` büyük. Başlık: "Kampüsün ortak alanı". Gövde: herkes yalnızca kendi kampüsünü görür; soru, not, etkinlik, sohbet tek yerde.
   - **2 · Akış ve Story.** Görsel: üst üste hafif kaymış 3 mini gönderi kartı, her birinde gönderi türü rozeti (Soru / Ders notu / Etkinlik — `PostKind` renklerini **oku**, rozetlerde yalnızca bu renkleri kullan, %12 zemin + tam ton yazı). Gövde: soru sor, ders notu paylaş; Story'ler 10 saat sonra kaybolur.
   - **3 · Kim nerede ve çalışma grubu.** Görsel: 3 yer çipi (kütüphane, kantin, yemekhane — `PlaceIcon`'daki sembolleri kullan) ve birinde küçük avatar yığını. Gövde: bir yer seç, orada kim var gör; telefon konumun okunmaz. Çalışma grubu kur, katılmak tek dokunuş.
   - **4 · Kulüpler ve bağlantı.** Görsel: kulüp daireleri + bir bağlantı isteği kartı. Gövde: kulübüne katıl; tanımak istediğine bağlantı isteği gönder, karşılıklıysa sohbet açılır. Engelle/şikâyet et her zaman bir dokunuş uzakta.
4. **Hareket.** Sayfa ilk göründüğünde görsel → başlık → gövde sırayla belirsin (opacity 0→1, y 12→0, 60ms kademe). Görsel içinde hafif bir canlılık olabilir (kartlar yerine oturur, çip seçilir) — tek sefer, döngü yok. Kaydırırken görsel hafif paralaks (`scrollTransition` veya `GeometryReader`). **Reduce Motion açıkken hiçbir animasyon ve paralaks yok**; içerik direkt görünür.
5. **Erişilebilirlik.** Dynamic Type'ta taşmasın (küçük iPhone'da `WelcomeView`'daki `compact` mantığı gibi sıkışsın). Görseller `accessibilityHidden(true)`, başlık `.isHeader`. VoiceOver sayfa numarasını okusun ("Sayfa 2 / 4" — metin tablodan). iPad'de `adaptivePageWidth(BondTheme.Layout.onboardingMaxWidth)`.
6. **Test argümanı.** `BondApp.swift`: `-intro` argümanı varsa `hasSeenAppIntro` sıfırlanır ve karşılama rotası açılır (mevcut `-welcome` dalına bak, aynı mantık).

## Metin kuralları (`YAZIM.md` — önce oku)

- Sen dili, kısa, sakin. Cümle düzeni: yalnızca ilk harf büyük.
- **Ünlem yok, emoji yok.** "Lütfen" yok.
- "bağlantı" — asla eşleşme/match. "gönderi" — asla post. "Story" (Story’ye, Story’n). "Kim nerede" sekmenin adı. "şikâyet". Kampüs adı yalnızca "YÜ".
- Tipografik kesme (’), tek karakter üç nokta (…), ayırıcı orta nokta (·).
- Her anahtarın `en` çevirisi de olsun. Arayüzde Swift içinde sabit metin yok; hepsi `L10n.AppIntro.*`.
- Tanışma uygulaması izlenimi verme. Common bir kampüs aracı; ton "okul arkadaşın sana uygulamayı gösteriyor".

## Yapmayacakların

- Giriş, kayıt, onboarding akışını değiştirme. Bildirim/konum izni isteme — intro sadece anlatır.
- Yeni renk, yeni font, `DesignSystem.swift`'e ekleme.
- Görsel/asset dosyası ekleme; her şey SwiftUI + SF Symbols.
- Lottie, video, üçüncü parti paket.

## Doğrulama — sonunda

1. Derleme temiz (`error:` yok).
2. `-intro` ile aç → 4 sayfa kaydır, noktalar doğru, "Geç" çalışıyor, "Başla" → `WelcomeView`. Uygulamayı kapat, `-welcome` ile aç → intro **tekrar görünmüyor**.
3. Ayarlar → Erişilebilirlik → Hareketi Azalt açıkken tekrar dene; hiçbir şey kaymamalı.
4. En büyük Dynamic Type'ta ve iPhone SE boyutunda ekran görüntüsü al; taşma yok.
5. Video: `xcrun simctl io <udid> recordVideo --codec h264 --force ~/Desktop/intro-demo.mp4 &` — 4 sayfa + Başla. 15–20 sn, `kill -INT` ile durdur.

## Rapor

Eklediğin/değiştirdiğin dosyalar ve ne yaptığın (kısa), yazdığın tüm metinler (tr + en tablo), `RootView`'daki diff'in tamamı, videonun yolu, yapamadığın ya da emin olmadığın şeyler. Kararsızsan tahmin etme, dur ve sor.
