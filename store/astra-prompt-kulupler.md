Common iOS uygulamasında Kulüpler ekranlarını (liste + detay sheet) kartlı ve animasyonlu hale getireceksin. Az önce "Kim nerede" ekranında yaptığın işin aynısı; aynı primitifler, aynı his. Sınırlar aynı derecede kesin.

## Proje

- Yol: `~/Desktop/Campus`, proje `Bond.xcodeproj`, şema `Bond`, bundle `com.campus.social`, iOS 18.
- Derleme:
  `xcodebuild -project Bond.xcodeproj -scheme Bond -configuration Debug -destination 'id=CC26C955-19CB-474E-A66E-40B61B50882B' -derivedDataPath .derived-sim build`
- Simülatör: `CC26C955-19CB-474E-A66E-40B61B50882B`. Uygulama `.derived-sim/Build/Products/Debug-iphonesimulator/Bond.app`; `xcrun simctl install` ile kur.
- Ekranları açmak (örnek veri, sunucusuz — bu argümanlar olmadan giriş ekranına düşersin, giriş yapma):
  - Kulüp listesi: `xcrun simctl launch <udid> com.campus.social -sample -tab places` → ekrandaki "Kulüpler" satırına dokun
  - Kulüp detayı doğrudan: `xcrun simctl launch <udid> com.campus.social -sample -club`

## Git kuralları — pazarlık yok

- Çalışma ağacında commit edilmemiş büyük bir iş var, başka biri de aynı ağaçta çalışıyor.
- `git commit`, `git add`, `git reset`, `git checkout`, `git stash`, `git restore`, `git clean` — hiçbirini çalıştırma. Sadece `git status` ve `git diff` serbest.

## Dokunabileceğin dosyalar

- `Bond/Features/Places/CampusClubsView.swift` — liste
- `Bond/Features/Places/ClubDetailView.swift` — detay sheet

## Dokunamayacağın dosyalar

- `Bond/Features/Places/PlacesWallView.swift`, `PlacePeopleView.swift` — bitti, dokunma
- `Bond/Features/Profile/**`, `Bond/Features/Feed/**` — üzerinde çalışılıyor
- `Bond/Core/Design/DesignSystem.swift` — oku, ekleme yapma
- `Bond/Resources/*.xcstrings`, `Bond/Core/Localization/**` — yeni metin ekleme; mevcut `L10n.Club.*` ve `L10n.CampusNavigation.*` dizelerini kullan (önce `L10n+Club.swift`'i oku, ne var gör)
- `Bond/Core/Services/**`, `Bond/Core/Models/**`, `Bond/App/**`, `supabase/**`, `store/**`, `docs/**`

## Elindeki araçlar (`DesignSystem.swift` — hepsi hazır)

- `BondTheme.Motion.snappy / .bouncy / .smooth / .interactive`
- `.buttonStyle(.pressable)` ve `.pressableCard`
- `Skeleton(height:cornerRadius:)`, `SkeletonRow()`
- `BondTheme.paper / .surface / .ink / .muted / .hairline`, `BondTheme.Radius.surface` (16) / `.media` (24), `BondTheme.Space.xs…xxl` (4…32)
- `Haptics.selection()`, `Haptics.success()`
- `PlacesWallView.swift`'teki giriş animasyonu kalıbını (`entranceIsHidden`, `.task(id:)`, `Motion.smooth.delay(...)`) ve `.transaction` hilesini oradan **kopyala** — o dosyayı değiştirme, sadece oku.
- `CampusClub` modeli: `name`, `summary`, `icon` (SF Symbol adı), `memberCount`, `nextEvent` (metin), `meetingPlace?`, `accentHex` (kulübün kendi rengi, `Color(hex:)` ile). Bu rengi liste hiç kullanmıyor; detay kullanıyor.

## Yapılacaklar — liste (`CampusClubsView`)

1. **`List` yerine `ScrollView` + kartlar.** Her kulüp bir kart: `BondTheme.surface` zemin, 16 köşe, `.shadow(color: .black.opacity(0.06), radius: 12, y: 4)`, 12pt iç boşluk, kartlar arası 10pt, yatay kenar `BondTheme.Space.lg`. `.pressable` ile basılabilir. `refreshable` ve `task` davranışı aynen kalsın.
2. **Kulüp rengi görünsün.** Sol tarafta 44×44 daire: `Color(hex: club.accentHex).opacity(0.14)` zemin, ikon aynı rengin tam tonu. Şu an ikon düz siyah.
3. **İkinci satır bilgi taşısın.** Ad (headline), altında özet (subheadline, 2 satır), altında küçük bir satır: üye sayısı + yaklaşan etkinlik (`nextEvent`), `footnote`, `.secondary`. Üyelik ikonu `person.2`, etkinlik ikonu `calendar`. Katıldıysa sağda `checkmark.circle.fill` kulüp renginde.
4. **Giriş animasyonu** — Kim nerede'deki kalıbın aynısı: opacity 0→1, offset y 12→0, 40ms kademe, sadece ilk görünüm, Reduce Motion gözetilir.
5. **Yükleme** — `ProgressView` yerine 4 adet `SkeletonRow()`.

## Yapılacaklar — detay (`ClubDetailView`)

6. **Sheet cilası:** `.presentationCornerRadius(28)`, `.presentationDragIndicator(.visible)`. İçerik ekranın ~%60'ını dolduruyor ve altı boş kalıyor; `.presentationDetents([.fraction(0.72), .large])` ile sheet içeriğe yakın açılsın (oranı içeriğe göre ayarla — boşluk kalmasın ama içerik de kesilmesin).
7. **Katıl düğmesi:** şu an düz dolgulu. Kapsül olsun (`Capsule()`), kulüp rengi zemin, beyaz metin. Katılınca `BondTheme.Motion.bouncy` ile "katıldın" durumuna dönüşsün (mevcut `L10n.Club.*` dizelerinden uygun olanı bul; ikon `checkmark` → `.contentTransition(.symbolEffect(.replace))`), `Haptics.success()`. Ayrılınca `Haptics.selection()`.
8. **Üye sayısı canlı:** `infoCard`'daki sayı `.contentTransition(.numericText())` + `.animation(BondTheme.Motion.snappy, value: joined)` ile katılınca bir artıp ayrılınca bir düşsün.
9. **Etkinlik kartı:** `nextEvent` bloğu surface zemin, 16 köşe; takvim ikonu kulüp renginde. Sol kenar çizgisi **yapma**.
10. Tüm düğmelere `.pressable`.

## Yapmayacakların

- Model, veri, servis, navigasyon değişikliği.
- Yeni dize ekleme. Gereken metin yoksa ikonla çöz ya da raporda yaz.
- Kulüp üyeleri listesi, etkinlik takvimi, yeni ekran — kapsam dışı.
- Reduce Motion açıkken hiçbir animasyon oynamamalı.

## Doğrulama — sonunda

1. Derleme temiz (`error:` yok).
2. `-sample -tab places` → Kulüpler'e dokun → liste kartlı ve sırayla belirsin. Bir karta dokun → detay sheet. "Katıl"a bas → düğme dönüşsün, üye sayısı artsın. Tekrar bas → geri dönsün.
3. Video: `xcrun simctl io <udid> recordVideo --codec h264 --force ~/Desktop/kulupler-demo.mp4 &` — liste açılışı, karta dokunma, katıl/ayrıl. 10–20 sn, `kill -INT` ile durdur.

## Rapor

Değiştirdiğin iki dosyada ne yaptığın (kısa), hangi `L10n.Club.*` dizelerini kullandığın, seçtiğin sheet oranı ve neden, videonun yolu, yapamadığın ya da emin olmadığın şeyler. Kararsızsan tahmin etme, dur ve sor.
