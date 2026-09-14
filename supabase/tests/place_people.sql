-- Synthetic fixtures only. Every write is rolled back.
begin;

create temporary table place_people_ids(
  label text primary key,
  id uuid default gen_random_uuid()
);
insert into place_people_ids(label) values ('viewer'), ('visible'), ('ghost'), ('blocked');
grant select on place_people_ids to authenticated, anon;

insert into auth.users(id, email)
select id, id::text || '@example.com' from place_people_ids;

insert into public.places(name, area) values ('Ghost Test Kantin', 'YÜ')
on conflict (name) do nothing;

insert into public.profiles(
  id, name, birth_date, university, department, academic_year,
  is_verified, is_active, ghost_mode, visible_place_id, visible_until
)
select
  ids.id,
  initcap(ids.label),
  '2002-01-01',
  'Yalova',
  'Test',
  '3',
  true,
  true,
  ids.label = 'ghost',
  (select id from public.places where name = 'Ghost Test Kantin'),
  now() + interval '2 hours'
from place_people_ids ids;

insert into public.blocks(blocker_id, blocked_id)
select v.id, b.id
from place_people_ids v, place_people_ids b
where v.label = 'viewer' and b.label = 'blocked';

select set_config(
  'request.jwt.claim.sub',
  (select id::text from place_people_ids where label = 'viewer'),
  true
);
set local role authenticated;

do $$
declare
  seen text[];
  place uuid;
begin
  select id into place from public.places where name = 'Ghost Test Kantin';
  select array_agg(name order by name) into seen from public.get_people_at_place(place);
  assert 'Visible' = any(seen), 'A visible person at the place must appear';
  assert not ('Ghost' = any(seen)), 'Ghost mode must hide the account from the place list';
  assert not ('Blocked' = any(seen)), 'Blocks must hide the account from the place list';
  assert not ('Viewer' = any(seen)), 'The viewer must not see themself';
end $$;

reset role;
rollback;
