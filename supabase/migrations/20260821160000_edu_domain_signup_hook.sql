-- E-posta/OTP ile hesap oluşturmayı .edu.tr'ye kısıtlar — mail gönderilmeden önce.
--
-- SMTP zaten panelde Resend üzerinden yapılandırılı (Authentication → Emails →
-- Custom SMTP, host smtp.resend.com); bu migration o gönderimin yerine geçmiyor,
-- sadece önüne bir kapı koyuyor. Supabase Auth'un "Before User Created" hook'u,
-- GoTrue yeni bir `auth.users` satırı oluşturmadan (dolayısıyla kod maili
-- gönderilmeden) hemen önce çalışıyor. Reddedilirse ne satır oluşuyor ne mail gidiyor.
--
-- Kontrol yalnızca `provider = 'email'` olan girişlere uygulanıyor — Apple/Google'a
-- DOKUNMUYOR. Apple/Google hesap e-postaları (kişisel Gmail/iCloud) zaten .edu.tr
-- olmak zorunda değil; bunu buraya da uygulamak `20260818220000_remove_domain_
-- verification.sql`'de düzeltilen sorunu ("her girişi bloke ediyordu") aynen geri
-- getirirdi. Apple/Google için kontrol `save_my_profile` içinde (profil tamamlanırken)
-- kalmaya devam ediyor; ikisi birbirinin yerine geçmiyor, farklı girişleri süzüyor.
--
-- Supabase'in kuralı: bu fonksiyon hata FIRLATAMAZ (`raise exception` GoTrue
-- tarafından bir hook cevabı olarak yorumlanmıyor); ya `{}` (izin ver) ya da
-- `{"error": {"http_code":..., "message":...}}` (reddet) döndürmesi gerekiyor.
--
-- Panelde ayrıca yapılması gereken: Authentication → Auth Hooks → "Before User
-- Created" → Enable, tür Postgres Function, şema `public`, fonksiyon
-- `restrict_signup_to_edu_tr`.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

create or replace function public.restrict_signup_to_edu_tr(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  account_provider text := event->'user'->'app_metadata'->>'provider';
  account_email text := lower(event->'user'->>'email');
begin
  if account_provider is distinct from 'email' then
    return '{}'::jsonb;
  end if;

  if account_email is null or account_email !~ '\.edu\.tr$' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Yalnızca .edu.tr uzantılı e-postalar kabul ediliyor.'
      )
    );
  end if;

  return '{}'::jsonb;
end;
$$;

grant execute on function public.restrict_signup_to_edu_tr(jsonb) to supabase_auth_admin;
revoke execute on function public.restrict_signup_to_edu_tr(jsonb) from authenticated, anon, public;

commit;
