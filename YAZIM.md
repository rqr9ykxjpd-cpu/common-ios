# Common — Yazım Kılavuzu

Uygulamadaki her metin (`Bond/Resources/*.xcstrings`), bildirimler, App Store
sayfası ve inceleme notu bu kurallara uyar. Yeni metin eklerken önce buraya bak;
bir terim burada yoksa ekle, sonra kullan.

## Terimler

| Kullan | Kullanma | Not |
|---|---|---|
| Story | Hikâye, durum | Özelliğin adı. Ekler: Story’yi, Story’ye, Story’n, Story’ni. "Hayat hikâyesi" gönderi türü ayrı kavram, o "hikâye" kalır. |
| gönderi | post, paylaşım | "Paylaşım yap" düğmesi eylem, istisna. |
| bağlantı, bağlantı isteği | eşleşme, eşleş, match | Tanışma uygulaması izlenimi vermemek için kesin kural. |
| sohbet (sekme), mesaj | DM, chat | |
| mesaj isteği | | Story’ye yanıt ya da profilden yazınca giden istek. |
| çalışma grubu | etüt, study group | |
| kulüp | topluluk | |
| Kim nerede | Kampüste, Places | Sekmenin adı. Cümle içinde yer anlamında "kampüste" küçük harfle yazılır. |
| şikâyet | şikayet | TDK yazımı. |
| Plus, Pro, Common Plus, Common Pro | premium, VIP | |
| YÜ | Yalova, Yalova Üniversitesi | Kampüs adı uygulamada yalnızca "YÜ". İletişim e-postası istisna, değişmez. |

## Kurallar

- **Cümle düzeni.** Başlık ve düğmelerde yalnızca ilk harf büyük: "Devam et",
  "Bir sorun oluştu", "Buluşma istekleri". Özel adlar (bölüm adları, Kullanım
  Koşulları, Gizlilik Politikası) ve Apple'ın kendi düğme metni ("Apple ile Devam
  Et") ile yan yana duran "Google ile Devam Et" istisna.
- **Düğmeler cümle düzeninde.** "Kulübe katıl", "Pro’ya geç", "Buradayım". Büyük
  harf yalnızca küçük üst başlıklarda (ÇALIŞMA GRUPLARI, PAKET İÇERİĞİ).
- **El yazısı yok.** Notlar uygulamanın kendi yazı tipinde, küçük ve gri.
  (İstisna: kurucu unvan satırı.)
- **Sen dili.** Kullanıcıya "sen" diye hitap edilir, kısa ve sakin. "Lütfen"
  yalnızca kullanıcıdan bir şey istenirken.
- **Ünlem yok.** Yalnızca karşılamada ("Hoş geldin!").
- **Hata metinleri:** ne oldu + ne yapabilirsin. "Fotoğraf yüklenemedi. Başka bir
  tane dene." Sunucu hatası, kod ya da İngilizce teknik terim gösterilmez
  (`UserFacingError` bunu sağlar).
- **Tipografi.** Kesme işareti tipografik (’), üç nokta tek karakter (…), aralık
  ve açıklama için uzun tire (—), ayırıcı olarak orta nokta (·).
- **Sayılar.** Metne gömülmez, `%lld` ile gelir; çoğul biçimi tabloda tanımlanır.
- **Emoji yok.**
- **İngilizce karşılık.** Her yeni anahtarın `en` çevirisi de yazılır. Kaynak dil
  İngilizce; yalnızca biçim anahtarları (`%@ · %@` gibi) çevirisiz kalabilir.

## Kodda

- Arayüzde görünen hiçbir metin Swift içinde sabit yazılmaz; `L10n` üzerinden
  tablodan gelir.
- Tabloları düzenlerken dosyayı baştan yazan araçlar kullanılmaz (JSON yeniden
  biçimlenir ve fark okunmaz hale gelir). Xcode'un metin düzenleyicisi ya da
  yalnızca değeri değiştiren hedefli düzenleme.
