-- Profil soruları ("Kampüste beni nerede bulursun?", "İlk buluşma fikrim",
-- "Beraber deneyelim") ürün kararıyla kaldırıldı. Kayıt akışı kısaldı.
--
-- `save_my_profile` bunları hâlâ ZORUNLU tutuyordu:
--   - tam üç soru gelmeli
--   - üçünün de cevabı boş olmamalı
-- Uygulama artık soru göndermediği için bu haliyle her kayıt denemesi
-- "Exactly three prompts are required" hatasıyla reddedilirdi.
--
-- Ayrıca `profile_dating_preference` de artık cinsiyetten türetiliyor (kadın →
-- erkekleri görür, erkek → kadınları). Parametre imzada kalıyor: sunucu tarafında
-- bir şey değişmiyor, uygulama sadece hesaplanmış değeri gönderiyor.
--
-- Eski imza (11 parametre) düşürülüp 10 parametreli yenisi oluşturuluyor; aksi
-- halde iki aşırı yükleme yan yana kalır ve PostgREST hangisini çağıracağını
-- seçemez.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

drop function if exists public.save_my_profile(
  text, date, public.profile_gender, public.dating_preference,
  public.relationship_intent, text, text, text, text, text[], jsonb
);

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
    university, department, academic_year, bio, discovery_enabled
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio, discovery_enabled = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  -- Özellik kalktığı için eski cevaplar da bırakılmıyor: profilde görünmeyen
  -- ama sunucuda duran veri, ileride yanlışlıkla geri sızabilecek bir yük.
  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;

commit;
