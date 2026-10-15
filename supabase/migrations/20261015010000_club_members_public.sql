-- Kulübün üyeleri herkese açık (kurucunun isteği, 15 Ekim).
--
-- Kulüp sayfasında herkes kulüpte kim olduğunu görüyor; bir üyeye dokununca
-- kartı açılıyor ve kart her zamanki gibi sağa-sola kaydırılıyor. Yönetimdeki
-- liste (`get_club_people`) yöneticiye özel kalıyor: kapalı kulüpleri de
-- gösteriyor ve üye çıkarmaya yarıyor.
--
-- Görünürlük `person_clubs` ile aynı (kartın altındaki kulüpler zaten herkese
-- açık): kulüp açık, profil aktif, iki yönden engel yok. Kulüp hesabının
-- profili de üye olarak kayıtlı; o kişi değil, sayfada ayrıca "Kulüp hesabı"
-- satırı var, listeye girmiyor. Yöneticiler önce, sonra katılış sırası.
-- Kart ilk açılışta beklemesin diye profil alanları da dönüyor
-- (`clubAccountProfile` ile aynı alanlar).
begin;

create or replace function public.get_club_members(club_id uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge, is_manager boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name, p.birth_date, p.university, p.department,
         p.academic_year, p.bio, p.avatar_path, p.is_verified, p.badge,
         exists (
           select 1 from public.club_managers m
            where m.club_id = cm.club_id and m.user_id = p.id
         )
    from public.club_members cm
    join public.clubs c on c.id = cm.club_id and c.is_active
    join public.profiles p on p.id = cm.user_id and p.is_active
   where cm.club_id = get_club_members.club_id
     and auth.uid() is not null
     and not exists (select 1 from public.club_accounts ca where ca.profile_id = p.id)
     and not exists (
       select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = auth.uid())
     )
   order by 11 desc, cm.created_at, p.name
   limit 500;
$$;

revoke all on function public.get_club_members(uuid) from public, anon;
grant execute on function public.get_club_members(uuid) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261015010000', 'club_members_public')
on conflict (version) do nothing;

commit;
