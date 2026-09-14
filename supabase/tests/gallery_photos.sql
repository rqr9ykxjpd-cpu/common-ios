-- Synthetic fixtures only. Every write is rolled back.
begin;

create temporary table gallery_ids(
  label text primary key,
  id uuid default gen_random_uuid()
);
insert into gallery_ids(label) values ('owner'), ('other');
grant select on gallery_ids to authenticated, anon;

insert into auth.users(id, email)
select id, id::text || '@example.com' from gallery_ids;

insert into public.profiles(
  id, name, birth_date, university, department, academic_year,
  is_verified, is_active
)
select
  id,
  initcap(label),
  '2002-01-01',
  'Yalova',
  'Test',
  '3',
  true,
  true
from gallery_ids;

select set_config(
  'request.jwt.claim.sub',
  (select id::text from gallery_ids where label = 'owner'),
  true
);
set local role authenticated;

do $$
declare
  owner uuid := (select id from gallery_ids where label = 'owner');
  other uuid := (select id from gallery_ids where label = 'other');
  i integer;
  pos smallint;
begin
  for i in 0..4 loop
    pos := public.append_gallery_photo(owner::text || '/gallery-' || i::text || '.jpg');
    assert pos = i, 'append must assign the next free card slot';
  end loop;

  begin
    perform public.append_gallery_photo(owner::text || '/gallery-overflow.jpg');
    raise exception 'sixth card should fail';
  exception
    when others then
      if sqlerrm not like '%gallery_full%' then raise; end if;
  end;

  begin
    insert into public.profile_photos (profile_id, storage_path, position)
    values (owner, owner::text || '/direct.jpg', 4);
    raise exception 'direct sixth insert should fail';
  exception
    when others then
      if sqlerrm not like '%gallery_full%' then raise; end if;
  end;

  begin
    perform public.append_gallery_photo(other::text || '/stolen.jpg');
    raise exception 'foreign storage path should fail';
  exception
    when others then
      if sqlerrm not like '%photo_owned_path%' then raise; end if;
  end;

  assert (
    select count(*) from public.profile_photos where profile_id = owner
  ) = 5, 'owner must keep exactly five card photos';
end $$;

reset role;
rollback;
