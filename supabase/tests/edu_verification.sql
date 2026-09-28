-- Synthetic fixtures only. Every write is rolled back.
begin;

alter table auth.users add column if not exists email_confirmed_at timestamptz;

create temporary table edu_test_ids(
  label text primary key,
  id uuid default gen_random_uuid()
);
insert into edu_test_ids(label) values ('student'), ('personal'), ('moderator');
grant select on edu_test_ids to authenticated, anon;

insert into auth.users(id, email, email_confirmed_at)
select id,
  case label
    when 'student' then 'student@ogrenci.yalova.edu.tr'
    when 'moderator' then 'moderator@yalova.edu.tr'
    else 'person@gmail.com'
  end,
  now()
from edu_test_ids;

insert into public.profiles(
  id, name, birth_date, university, department, academic_year,
  is_verified, is_active, badge
)
select id, initcap(label), date '2002-01-01', 'YÜ', 'Test', '3', true, true,
  (case when label = 'moderator' then 'moderator' else 'none' end)::public.profile_badge
from edu_test_ids;

do $$
begin
  assert public.is_edu_email('student@yalova.edu.tr');
  assert public.is_edu_email('student@ogrenci.yalova.edu.tr');
  assert not public.is_edu_email('student@gmail.com');
  assert not public.is_edu_email('student@fakeyalova.edu.tr');
  assert not has_function_privilege('anon', 'public.sync_edu_verification()', 'EXECUTE');
end $$;

select set_config('request.jwt.claim.sub', (select id::text from edu_test_ids where label = 'student'), true);
set local role authenticated;
do $$
begin
  assert public.sync_edu_verification();
end $$;
reset role;
do $$
begin
  assert (select edu_email = 'student@ogrenci.yalova.edu.tr' from public.profiles where id = auth.uid());
  assert (select edu_verified_at is not null from public.profiles where id = auth.uid());
  assert (select badge = 'verified' from public.profiles where id = auth.uid());
end $$;

select set_config('request.jwt.claim.sub', (select id::text from edu_test_ids where label = 'personal'), true);
set local role authenticated;
do $$
begin
  assert not public.sync_edu_verification();
end $$;
reset role;
do $$
begin
  assert (select edu_verified_at is null from public.profiles where id = auth.uid());
  assert (select badge = 'none' from public.profiles where id = auth.uid());
end $$;

select set_config('request.jwt.claim.sub', (select id::text from edu_test_ids where label = 'moderator'), true);
set local role authenticated;
do $$
begin
  assert public.sync_edu_verification();
end $$;
reset role;
do $$
begin
  assert (select badge = 'moderator' from public.profiles where id = auth.uid()),
    'student verification must not replace a staff badge';
end $$;
rollback;
