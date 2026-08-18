-- Kullanıcının kendi profilini eksiksiz okuması için RPC.
--
-- `tighten_privacy` migration'ı public.profiles üzerindeki genel SELECT yetkisini kaldırıp
-- yalnızca hassas olmayan sütunlara kolon bazlı yetki verdi; gender / dating_preference /
-- relationship_intent bilerek dışarıda bırakıldı. Bu yüzden kullanıcı kendi bu alanlarını da
-- doğrudan sorgulayamıyor. Security definer RPC, başkalarının alanlarını açmadan yalnızca
-- auth.uid()'in kendi kaydını döndürür.
--
-- Forward-only; tekrar çalıştırılabilir.

begin;

create or replace function public.get_my_profile()
returns table (
  name text,
  birth_date date,
  gender public.profile_gender,
  dating_preference public.dating_preference,
  relationship_intent public.relationship_intent,
  university text,
  department text,
  academic_year text,
  bio text,
  interests text[],
  prompt_keys text[],
  prompt_answers text[],
  min_age smallint,
  max_age smallint,
  academic_years text[],
  departments text[],
  require_common_interest boolean,
  campus_only boolean
)
language sql stable security definer set search_path = '' as $$
  select
    p.name, p.birth_date, p.gender, p.dating_preference, p.relationship_intent,
    p.university, p.department, p.academic_year, p.bio,
    coalesce((select array_agg(pi.interest order by pi.interest) from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce(dp.min_age, 18::smallint),
    coalesce(dp.max_age, 30::smallint),
    coalesce(dp.academic_years, '{}'),
    coalesce(dp.departments, '{}'),
    coalesce(dp.require_common_interest, false),
    coalesce(dp.campus_only, true)
  from public.profiles p
  left join public.discovery_preferences dp on dp.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

commit;
