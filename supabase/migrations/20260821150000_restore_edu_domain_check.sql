-- Ürün kararı geri geldi: yalnızca .edu.tr uzantılı hesaplar profil oluşturabilsin.
--
-- `20260818220000_remove_domain_verification.sql` bu kontrolü tamamen kaldırmıştı,
-- çünkü eski tetikleyici `profiles.university_domain` sütununun varsayılan değeriyle
-- (`yalova.edu.tr`) hesabın gerçek e-posta domain'ini karşılaştırıyordu ve
-- `save_my_profile` bu sütunu hiç set etmediği için ilk kayıtta herkesi reddediyordu.
--
-- Kontrol şimdi `university_domain` sütununa hiç dokunmadan, doğrudan
-- `auth.users.email` üzerinden geri getiriliyor: Apple/Google girişinde hesabın
-- taşıdığı e-posta `.edu.tr` ile bitmiyorsa `save_my_profile` reddeder. Test etmek
-- için hesabın gerçek e-postasının (kişisel Gmail/iCloud değil, üniversitenin
-- verdiği `...@ogrenci.<üniversite>.edu.tr` gibi bir Google hesabının) OAuth
-- token'ında gelmesi gerekiyor.
--
-- Gövde `20260819120000_badges_and_places.sql` ile birebir aynı (10 parametre,
-- is_verified); yalnızca en başa domain kontrolü eklendi. Geri almak istenirse
-- o migration'daki gövde tekrar `create or replace` ile uygulanır.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

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
  account_domain text;
begin
  if account_id is null then raise exception 'Authentication required'; end if;

  select lower(split_part(email, '@', 2)) into account_domain
  from auth.users where id = account_id;

  if account_domain is null or account_domain !~ '\.edu\.tr$' then
    raise exception 'A verified .edu.tr email is required';
  end if;

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

commit;
