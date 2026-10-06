-- Kurucu ve moderatör doğrulanmamış hesapların fotoğraflarını da görür.
--
-- Doğrulanmamış hesap herkesten gizlendiğinden beri (20261003010000) profil
-- fotoğrafları kurucu panelinde ve şikâyet incelemesinde de boş görünüyordu.
-- Diğer kullanıcılar için kural aynı; engelleme yine geçerli. Gövde canlıdaki
-- tanımdan alındı, tek fark `is_verified or is_moderator()`.
begin;

create or replace function public.can_read_profile_photo(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and (
    public.media_owner_id(object_name) = auth.uid()
    or (
      exists(select 1 from public.profiles r
             where r.id = auth.uid() and r.is_active)
      and exists(select 1 from public.profiles p
                 where p.id = public.media_owner_id(object_name)
                   and p.is_active
                   and (p.is_verified or public.is_moderator())
                   and (p.avatar_path = object_name or exists(
                     select 1 from public.profile_photos ph
                     where ph.profile_id = p.id and ph.storage_path = object_name)))
      and not exists(select 1 from public.blocks b
                     where (b.blocker_id = auth.uid() and b.blocked_id = public.media_owner_id(object_name))
                        or (b.blocked_id = auth.uid() and b.blocker_id = public.media_owner_id(object_name)))
    )
  );
$$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261003030000', 'staff_sees_unverified_photos')
on conflict (version) do nothing;

commit;
