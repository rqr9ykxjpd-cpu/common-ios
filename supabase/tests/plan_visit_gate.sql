-- Synthetic fixtures only. Every write is rolled back.
begin;

create temporary table visit_gate_ids(
  label text primary key,
  id uuid default gen_random_uuid()
);
insert into visit_gate_ids(label) values ('free'), ('plus');
grant select on visit_gate_ids to authenticated, anon;

insert into auth.users(id, email)
select id, id::text || '@example.com' from visit_gate_ids;

insert into public.profiles(
  id, name, birth_date, university, department, academic_year,
  is_verified, is_active, badge
)
select
  id,
  initcap(label),
  '2002-01-01',
  'Yalova',
  'Test',
  '3',
  true,
  true,
  'none'
from visit_gate_ids;

insert into public.subscriptions(user_id, plan, expires_at)
select id, 'plus', timestamptz '2030-01-01'
from visit_gate_ids
where label = 'plus';

insert into public.profile_visits(profile_id, visitor_id)
select f.id, p.id
from visit_gate_ids f, visit_gate_ids p
where f.label = 'free' and p.label = 'plus';

select set_config(
  'request.jwt.claim.sub',
  (select id::text from visit_gate_ids where label = 'free'),
  true
);
do $$
begin
  assert (
    select count(*) from public.get_my_profile_visits()
  ) = 0, 'Free plan must not read profile visitors';
end $$;

select set_config(
  'request.jwt.claim.sub',
  (select id::text from visit_gate_ids where label = 'plus'),
  true
);
insert into public.profile_visits(profile_id, visitor_id)
select p.id, f.id
from visit_gate_ids p, visit_gate_ids f
where p.label = 'plus' and f.label = 'free';

do $$
begin
  assert (
    select count(*) from public.get_my_profile_visits()
  ) = 1, 'Plus plan must read profile visitors';
end $$;

rollback;
