-- `save_my_profile` hiçbir zaman `university_domain` sütununu set etmiyordu; profil
-- oluşturulurken sütunun `not null default 'yalova.edu.tr'` varsayılanı kullanılıyordu.
-- `profiles_validate_membership` tetikleyicisi ise hesabın gerçek e-posta domain'ini bu
-- sütunla birebir karşılaştırıyor. Sonuç: gerçek öğrenci adresleri (`...@ogrenci.yalova.edu.tr`)
-- varsayılanla eşleşmediği için ilk profil kaydında "A verified university email is
-- required" hatasıyla reddediliyordu — kayıt akışı hiçbir zaman uçtan uca çalışamazdı.
--
-- Ayrıca iş kuralı: yalnızca .edu.tr uzantılı hesaplar profil oluşturabilsin (tek
-- üniversiteye değil, herhangi bir Türkiye yükseköğretim domainine izin verilir).
--
-- Idempotent; tekrar çalıştırılabilir.

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
  profile_interests text[],
  profile_prompts jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  account_domain text;
  prompt jsonb;
  prompt_position integer := 0;
begin
  if account_id is null then raise exception 'Authentication required'; end if;

  select lower(split_part(email, '@', 2)) into account_domain
  from auth.users where id = account_id;

  if account_domain is null or account_domain !~ '\.edu\.tr$' then
    raise exception 'A verified .edu.tr email is required';
  end if;

  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;
  if jsonb_array_length(profile_prompts) <> 3 then raise exception 'Exactly three prompts are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, university_domain, discovery_enabled
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), account_domain, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    university_domain = excluded.university_domain, discovery_enabled = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
  for prompt in select value from jsonb_array_elements(profile_prompts)
  loop
    if char_length(btrim(prompt->>'answer')) = 0 then raise exception 'Prompt answers cannot be empty'; end if;
    insert into public.profile_prompts(profile_id, prompt_key, answer, position)
    values (account_id, prompt->>'prompt_key', btrim(prompt->>'answer'), prompt_position);
    prompt_position := prompt_position + 1;
  end loop;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[], jsonb) to authenticated;

commit;
