# Öğrenci e-postası doğrulaması — Supabase kurulumu (Build 6)

Kod tarafı `20260922010000_edu_verification.sql` + uygulamadaki `EduVerificationCard`.
Dashboard'da bir kez yapılacaklar (sırayla):

1. **SMTP** — Project Settings → Authentication → SMTP Settings → Enable Custom SMTP
   - Host `smtp.gmail.com`, Port `465`, User: Gmail adresi, Pass: Gmail **uygulama şifresi**
     (Google Hesabı → Güvenlik → 2 Adımlı Doğrulama → Uygulama şifreleri). Şifreyi yalnızca
     hesap sahibi girer.
   - Sender email: aynı Gmail; Sender name: `Common`.
   - Rate limits → "Rate limit for sending emails": 60/saat yeterli (Gmail günde ~500).
2. **Secure email change KAPALI** — Authentication → Providers → Email → "Secure email change"
   kapalı. Açık kalırsa eski adrese de (Apple gizli aktarma adresi olabilir) onay ister.
3. **Redirect URL** — Authentication → URL Configuration → Redirect URLs listesine ekle:
   `https://rqr9ykxjpd-cpu.github.io/common-ios/dogrulandi.html`
   (`bond://login-callback` zaten listede olmalı.)
4. **Şablon** — Authentication → Email Templates → **Change Email Address**:
   Subject `Common — öğrenci e-postanı doğrula`, Body: `change-email.html` içeriği.
5. **Muafiyet** — inceleme (Test acc) hesabı için SQL Editor'da:
   `update public.profiles set edu_exempt = true where id = '<uuid>';`
   Kurucu/moderatör rozetten zaten muaf.

Akış: uygulama `auth.updateUser(email:)` → yeni adrese bağlantı → tıklanınca
`auth.users.email` değişir ve `dogrulandi.html` açılır → uygulama öne gelince ya da
"Common'a dön" (`bond://edu-verified`) ile `sync_edu_verification()` profili damgalar.
