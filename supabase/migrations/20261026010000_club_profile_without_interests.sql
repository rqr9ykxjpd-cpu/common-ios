-- Kulüp hesabı profil fotoğrafını değiştiremiyordu (26 Ekim, bir kulüp
-- yöneticisi): "En az 3 ilgi alanı seçmelisin". Düzenleme ekranı önce metin
-- bilgilerini bu fonksiyonla kaydediyor, fotoğrafı sonra yüklüyor; fonksiyon
-- her hesaptan en az 3 ilgi alanı istiyordu ama kulüp hesabında ilgi alanı
-- yok, ekranda seçme yeri de yok. Kulüp hesapları (club_accounts) bu şarttan
-- muaf; öğrencilerde aynen geçerli. Gövde canlıdaki tanımdan (26 Ekim).
begin;

create or replace function public.save_my_campus_profile(
  profile_name text,
  profile_birth_date date,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
account_id uuid := auth.uid();
begin
if account_id is null then raise exception 'Authentication required'; end if;
if coalesce(cardinality(profile_interests), 0) < 3
   and not exists (select 1 from public.club_accounts ca where ca.profile_id = account_id) then
raise exception 'At least three interests are required';
end if;

insert into public.profiles (
id, name, birth_date, university, department, academic_year, bio,
discovery_enabled, is_verified
) values (
account_id, btrim(profile_name), profile_birth_date, btrim(profile_university),
btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio),
false, true
) on conflict (id) do update set
name = excluded.name,
birth_date = excluded.birth_date,
university = excluded.university,
department = excluded.department,
academic_year = excluded.academic_year,
bio = excluded.bio,
discovery_enabled = false,
is_verified = true;

delete from public.profile_interests where profile_id = account_id;
insert into public.profile_interests(profile_id, interest)
select account_id, btrim(value) from unnest(profile_interests) value;

delete from public.profile_prompts where profile_id = account_id;
end;
$function$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261026010000', 'club_profile_without_interests')
on conflict (version) do nothing;

commit;
