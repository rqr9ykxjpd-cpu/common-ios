// Bu dosya `docs/olustur.py` tarafından üretiliyor. Elle düzenleme —
// kaynak metinler docs/gizlilik.md ve docs/kosullar.md.

enum LegalBlock {
    case baslik(String)
    case altbaslik(String)
    case paragraf(String)
    case madde(String)
}

enum LegalTexts {
    static let gizlilik: [LegalBlock] = [
        .baslik("Gizlilik Politikası"),
        .paragraf("Son güncelleme: 19 Ağustos 2026"),
        .paragraf("Common, Yalova Üniversitesi öğrencilerinin kampüste tanışması için yapılmış bir uygulamadır. Bu metin, uygulamanın hangi bilgileri topladığını, neden topladığını ve bu bilgilerle ne yaptığını anlatır. Sade tutmaya çalıştık."),
        .altbaslik("Topladığımız bilgiler"),
        .paragraf("Hesabını açarken: e-posta adresin (Google veya Apple ile giriş yaptığında bize iletilen adres), adın, doğum tarihin, üniversiten, bölümün ve sınıfın. Doğum tarihini yaşını hesaplamak ve 18 yaş sınırını uygulamak için istiyoruz."),
        .paragraf("Profilini doldururken: kendini anlattığın metin, ilgi alanların, cinsiyetin ve profil fotoğrafların."),
        .paragraf("Uygulamayı kullanırken: paylaştığın gönderiler ve story'ler, yazdığın yorumlar ve mesajlar, beğendiğin ve kaydettiğin gönderiler, katıldığın kulüpler, \"şu an buradayım\" diye seçtiğin kampüs noktası, kimlerle eşleştiğin ve son aktif olduğun zaman."),
        .paragraf("Otomatik olarak: oturumunu açık tutmak için gereken teknik kayıtlar."),
        .paragraf("Konumunu telefondan okumuyoruz. Kampüste nerede olduğun yalnızca senin listeden elle seçtiğin yerdir ve seçtiğin süre dolunca kendiliğinden kalkar."),
        .altbaslik("Bu bilgileri ne için kullanıyoruz"),
        .paragraf("Hesabını açmak ve girişini sürdürmek; profilini ve paylaşımlarını diğer öğrencilere göstermek; sana uygun kişileri önermek; eşleştiğin kişilerle mesajlaşmanı sağlamak; şikayet edilen içerikleri incelemek ve kuralları uygulamak."),
        .paragraf("Reklam göstermiyoruz. Bilgilerini reklam amacıyla kimseye satmıyor, kiralamıyor veya devretmiyoruz."),
        .altbaslik("Kimler neyi görebiliyor"),
        .madde("Profilin, gönderilerin ve story'lerin: uygulamayı kullanan diğer öğrenciler görebilir."),
        .madde("Mesajların: yalnızca yazıştığın kişi görebilir."),
        .madde("Seçtiğin kampüs noktası: yalnızca sen görünür olmayı seçtiğin sürece ve yalnızca uygulamadaki diğer öğrenciler görebilir."),
        .madde("E-posta adresin ve doğum tarihin: diğer kullanıcılara gösterilmez."),
        .madde("Engellediğin kişiler: engellediğin kişi bunu göremez."),
        .altbaslik("Bilgilerin nerede tutuluyor"),
        .paragraf("Veriler, altyapı sağlayıcımız Supabase'in sunucularında saklanır. Bağlantılar şifreli (HTTPS) kurulur. Fotoğraflarına yalnızca giriş yapmış kullanıcılar, süreli ve imzalı bağlantılarla erişebilir."),
        .paragraf("Giriş için Google ve Apple'ın kimlik doğrulama servislerini kullanıyoruz. Bu servisler kendi gizlilik politikalarına tabidir ve bize yalnızca kimliğini doğrulayan asgari bilgiyi iletirler; şifreni hiçbir zaman görmeyiz."),
        .altbaslik("Ne kadar süre tutuyoruz"),
        .paragraf("Hesabın açık olduğu sürece. Story'ler 24 saat sonra kendiliğinden kaybolur."),
        .paragraf("Hesabını uygulama içinden Profil → Hesabı kalıcı olarak sil yolundan silebilirsin. Sildiğinde profilin, gönderilerin, story'lerin, mesajların, fotoğrafların ve eşleşmelerin sunuculardan kaldırılır. Bu işlem geri alınamaz."),
        .altbaslik("Yaş sınırı"),
        .paragraf("Common 18 yaşından küçüklerin kullanımına kapalıdır. 18 yaşından küçük olduğunu öğrendiğimiz hesapları kapatırız."),
        .altbaslik("Hakların"),
        .paragraf("6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında; hangi verilerinin işlendiğini öğrenme, düzeltilmesini veya silinmesini isteme ve işlenmesine itiraz etme hakkına sahipsin. Profil bilgilerini uygulama içinden dilediğin zaman değiştirebilir, hesabını dilediğin zaman silebilirsin. Diğer talepler için aşağıdaki adresten bize yazabilirsin."),
        .altbaslik("Değişiklikler"),
        .paragraf("Bu metni güncellersek en üstteki tarihi değiştirir, önemli bir değişiklik olursa uygulama içinde bildiririz."),
        .altbaslik("İletişim"),
        .paragraf("E-posta: 220207018@yalova.edu.tr"),
        .paragraf("Şikayetlere ve veri taleplerine 24 saat içinde dönüyoruz."),
    ]

    static let kosullar: [LegalBlock] = [
        .baslik("Kullanım Koşulları"),
        .paragraf("Son güncelleme: 19 Ağustos 2026"),
        .paragraf("Common'ı kullanarak bu koşulları kabul etmiş olursun. Kabul etmiyorsan uygulamayı kullanma."),
        .altbaslik("Kimler kullanabilir"),
        .paragraf("Common, Yalova Üniversitesi öğrencileri içindir ve 18 yaşından büyük olman gerekir. Hesabını kendi adına açarsın; başkasının kimliğine bürünemez, sahte profil oluşturamazsın. Hesabını başkasına devredemez, paylaşamazsın."),
        .altbaslik("Paylaştığın içerikten sen sorumlusun"),
        .paragraf("Uygulamaya yüklediğin fotoğraf, yazı ve mesajların sorumluluğu sana aittir. Yalnızca paylaşma hakkına sahip olduğun içerikleri paylaş."),
        .paragraf("Paylaştığın içerik sana ait kalır. Bize yalnızca bu içeriği uygulama içinde diğer kullanıcılara gösterebilmemiz için gereken izni vermiş olursun; bu izin içeriğini sildiğinde sona erer."),
        .altbaslik("Kabul edilmeyen davranışlar"),
        .paragraf("Aşağıdakilere sıfır tolerans uygulanır:"),
        .madde("Taciz, tehdit, hakaret, ısrarlı rahatsız etme"),
        .madde("Nefret söylemi; ırk, etnik köken, din, cinsiyet, cinsel yönelim, engellilik veya benzeri özellikler üzerinden hedef gösterme"),
        .madde("Cinsel içerik, çıplaklık, müstehcen paylaşım"),
        .madde("Şiddet içeren, kendine zarar vermeyi özendiren veya yasa dışı içerik"),
        .madde("Başkasının fotoğrafını, kimliğini veya özel bilgilerini izinsiz paylaşmak"),
        .madde("Sahte hesap, spam, dolandırıcılık, ticari tanıtım"),
        .madde("18 yaşından küçüklere yönelik her türlü içerik veya yaklaşım"),
        .altbaslik("Şikayet, engelleme ve moderasyon"),
        .paragraf("Uygulamadaki her profil ve gönderi için şikayet et ve engelle seçenekleri vardır. Engellediğin kişi seninle iletişim kuramaz."),
        .paragraf("Bize ulaşan şikayetleri 24 saat içinde inceler; kuralları ihlal eden içeriği kaldırır ve gerekirse hesabı kalıcı olarak kapatırız. Ciddi durumlarda hesabı incelemeyi beklemeden askıya alabiliriz. Bu kararlar için ayrıca bildirimde bulunmak zorunda değiliz."),
        .altbaslik("Hesabının kapatılması"),
        .paragraf("Kuralları ihlal ettiğini tespit edersek hesabını uyarı yapmadan kapatabiliriz. Sen de hesabını dilediğin zaman uygulama içinden Profil → Hesabı kalıcı olarak sil yolundan silebilirsin."),
        .altbaslik("Sorumluluk sınırı"),
        .paragraf("Common tanışmayı kolaylaştıran bir araçtır; kullanıcıların kimliğini, söylediklerinin doğruluğunu veya niyetlerini garanti etmez. Tanıştığın kişilerle buluşurken kendi güvenliğinden sen sorumlusun: ilk buluşmaları kalabalık ve açık yerlerde yapmanı, yakınlarından birine haber vermeni öneririz."),
        .paragraf("Uygulama \"olduğu gibi\" sunulur. Kesintisiz veya hatasız çalışacağını taahhüt etmiyoruz. Yasaların izin verdiği ölçüde, uygulamanın kullanımından doğan dolaylı zararlardan sorumlu değiliz."),
        .altbaslik("Değişiklikler"),
        .paragraf("Bu koşulları güncelleyebiliriz. Önemli bir değişiklikte uygulama içinde bildiririz; değişiklikten sonra kullanmaya devam etmen yeni koşulları kabul ettiğin anlamına gelir."),
        .altbaslik("Uygulanacak hukuk"),
        .paragraf("Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır."),
        .altbaslik("İletişim"),
        .paragraf("E-posta: 220207018@yalova.edu.tr"),
        .paragraf("Şikayetlere ve veri taleplerine 24 saat içinde dönüyoruz."),
    ]

}
