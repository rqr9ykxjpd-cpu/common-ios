-- Keep historical migrations intact; close all legacy public-photo paths.
begin;

update storage.buckets set public = false where id = 'profile-photos';
drop policy if exists "public read profile photos" on storage.objects;
drop policy if exists "authenticated read profile photos" on storage.objects;

create or replace function public.can_read_profile_photo(object_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    public.media_owner_id(object_name) = auth.uid()
    or (
      exists(select 1 from public.profiles r
        where r.id = auth.uid() and r.is_active and r.is_verified)
      and exists(select 1 from public.profiles p
        where p.id = public.media_owner_id(object_name)
          and p.is_active and p.is_verified
          and (p.avatar_path = object_name or exists(
            select 1 from public.profile_photos ph
            where ph.profile_id = p.id and ph.storage_path = object_name)))
      and not exists(select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = public.media_owner_id(object_name))
           or (b.blocked_id = auth.uid() and b.blocker_id = public.media_owner_id(object_name)))
    )
  );
$$;
revoke all on function public.can_read_profile_photo(text) from public, anon;
grant execute on function public.can_read_profile_photo(text) to authenticated;

-- Restrictive guards intersect with every legacy permissive SELECT/ALL policy.
drop policy if exists "profile photo member guard" on storage.objects;
create policy "profile photo member guard" on storage.objects as restrictive
for select to authenticated
using (bucket_id <> 'profile-photos' or public.can_read_profile_photo(name));
drop policy if exists "profile photo anonymous guard" on storage.objects;
create policy "profile photo anonymous guard" on storage.objects as restrictive
for select to anon using (bucket_id <> 'profile-photos');
drop policy if exists "members read registered profile photos" on storage.objects;
create policy "members read registered profile photos" on storage.objects
for select to authenticated
using (bucket_id = 'profile-photos' and public.can_read_profile_photo(name));

commit;
