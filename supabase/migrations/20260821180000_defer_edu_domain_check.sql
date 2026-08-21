-- .edu.tr şartı ilk sürümde kapalı.
--
-- Ürün kararı: v1'de herkes kolayca girebilsin. Kısıtlama tamamen silinmiyor,
-- yalnızca devre dışı bırakılıyor — geri açmak için `20260821150000` ve
-- `20260821160000` dosyalarını tekrar çalıştırmak yeterli.
--
-- Ayrıca App Store incelemesi için zorunluydu: şart açıkken inceleyen kişi
-- kendi Apple hesabıyla girebiliyor ama kayıt akışının son adımında
-- `save_my_profile` onu reddediyor ve uygulamayı hiç göremiyor. Gördüğü tek
-- şey bir hata mesajı olan bir uygulama reddedilir.
--
-- İki yerde kapatılıyor, çünkü iki ayrı yerde açılmıştı:
--   1. `save_my_profile` içindeki domain kontrolü (Apple/Google dahil herkese)
--   2. `restrict_signup_to_edu_tr` kayıt hook'u (yalnızca e-posta girişi)
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

-- ------------------------------------------------------ 1. profil kaydı
--
-- Gövde `20260821150000` ile birebir aynı; yalnızca en baştaki domain
-- kontrolü çıkarıldı. Rozet/is_verified davranışı aynen korunuyor.
create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;

  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, discovery_enabled, is_verified
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    discovery_enabled = true, is_verified = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;

-- ------------------------------------------------------ 2. kayıt hook'u
--
-- Hook'u panelden kapatmak da işe yarardı ama tek başına yeterli değil:
-- panel ayarı bu dosyada görünmüyor, unutulursa kimse fark etmiyor.
-- Fonksiyonun kendisi herkese izin verir hale getiriliyor; panelde açık
-- kalsa bile kimseyi engellemiyor.
create or replace function public.restrict_signup_to_edu_tr(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  return '{}'::jsonb;
end;
$$;

grant execute on function public.restrict_signup_to_edu_tr(jsonb) to supabase_auth_admin;
revoke execute on function public.restrict_signup_to_edu_tr(jsonb) from authenticated, anon, public;

commit;
