-- Build 3 retires gender-based discovery. Existing legacy values are preserved
-- for compatibility, but new campus profiles do not collect or require them.
begin;

alter table public.profiles
  alter column gender drop not null,
  alter column dating_preference drop not null,
  alter column relationship_intent drop not null,
  alter column relationship_intent drop default;

-- Old discovery clients must not keep existing accounts visible after the
-- feature has been removed from the product.
update public.profiles set discovery_enabled = false where discovery_enabled;

create or replace function public.save_my_campus_profile(
  profile_name text,
  profile_birth_date date,
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
  if coalesce(cardinality(profile_interests), 0) < 3 then
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
$$;

revoke all on function public.save_my_campus_profile(
  text, date, text, text, text, text, text[]
) from public, anon;
grant execute on function public.save_my_campus_profile(
  text, date, text, text, text, text, text[]
) to authenticated;

commit;
