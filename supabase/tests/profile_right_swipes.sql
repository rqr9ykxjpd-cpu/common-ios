-- Profile-card right swipe is a connection request, not the revoked campus
-- directory. Verify that an authenticated student can create one safely.
begin;

create temporary table swipe_test_ids(
  label text primary key,
  id uuid default gen_random_uuid()
);
insert into swipe_test_ids(label) values ('actor'), ('subject');
grant select on swipe_test_ids to authenticated;

insert into auth.users(id, email)
select id, label || '@example.com' from swipe_test_ids;

insert into public.profiles(
  id, name, birth_date, university, department, academic_year,
  is_verified, is_active
)
select id, initcap(label), '2002-01-01', 'Yalova', 'Test', '3', true, true
from swipe_test_ids;

select set_config(
  'request.jwt.claim.sub',
  (select id::text from swipe_test_ids where label = 'actor'),
  true
);
set local role authenticated;

do $$
declare
  target_id uuid;
  did_match boolean;
begin
  select id into target_id from swipe_test_ids where label = 'subject';
  select matched into did_match
  from public.swipe_right_on_profile(target_id);

  assert did_match is false, 'A one-way connection request must not create a match';
  assert exists (
    select 1 from public.profile_right_swipes s
    where s.actor_id = auth.uid() and s.subject_id = target_id
  ), 'The connection request must be stored';
end $$;

reset role;
rollback;
