-- Synthetic fixtures only. Every write is rolled back.
begin;
create temporary table media_test_ids(label text primary key, id uuid default gen_random_uuid());
insert into media_test_ids(label) values ('owner'), ('reader');
grant select on media_test_ids to authenticated, anon;
insert into auth.users(id,email) select id, id::text || '@example.com' from media_test_ids;
insert into public.profiles(id,name,birth_date,gender,dating_preference,university,department,academic_year,is_verified,is_active,avatar_path)
select id, 'Media test', '2000-01-01', 'male', 'everyone', 'Yalova', 'Test', '3', true,true,id::text || '/avatar.jpg' from media_test_ids;
insert into storage.objects(bucket_id,name)
select 'profile-photos',id::text || suffix from media_test_ids cross join (values('/avatar.jpg'),('/unpublished.jpg')) f(suffix) where label='owner';

select set_config('request.jwt.claim.sub',(select id::text from media_test_ids where label='owner'),true);
set local role authenticated;
do $$ begin
  assert (select count(*)=2 from storage.objects where bucket_id='profile-photos'), 'Owner must see own uploads';
end $$;
reset role;

select set_config('request.jwt.claim.sub',(select id::text from media_test_ids where label='reader'),true);
set local role authenticated;
do $$ begin
  assert (select count(*)=1 from storage.objects where bucket_id='profile-photos'), 'Member may see registered avatar only';
end $$;
reset role;
insert into public.blocks(blocker_id,blocked_id)
select o.id,r.id from media_test_ids o,media_test_ids r where o.label='owner' and r.label='reader';
set local role authenticated;
do $$ begin
  assert not exists(select 1 from storage.objects where bucket_id='profile-photos'), 'Block must prevent new photo reads';
end $$;
reset role;

select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
  assert not exists(select 1 from storage.objects where bucket_id='profile-photos'), 'Anonymous access must be denied';
end $$;
reset role;
do $$ begin
  assert (select public=false from storage.buckets where id='profile-photos'), 'Bucket must be private';
end $$;
rollback;
