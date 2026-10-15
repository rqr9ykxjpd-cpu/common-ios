-- Kulüp sayfasındaki "Kulübün hesabı" satırı açılmıyordu (kurucu, 15 Ekim).
--
-- Uygulama hesabı doğrudan `profiles` tablosundan okuyordu. Profil okuma
-- kuralı bir profili ancak paylaşımı, story'si, yorumu ya da seninle
-- bağlantısı varsa gösteriyor; henüz bir şey paylaşmamış kulüp hesabı kurucuya
-- bile görünmüyordu ve "Kulübün hesabı açılamadı." çıkıyordu.
--
-- Satır artık yalnızca kulübü yönetenlere (kurucu ve kulübün yöneticileri)
-- gösteriliyor; hesabı bu fonksiyon getiriyor, aynı yetkiyle. Kulüp açık ve
-- hesap aktif olmalı. Profil okuma kuralı değişmiyor.
begin;

create or replace function public.club_account_profile(club_id uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name, p.birth_date, p.university, p.department,
         p.academic_year, p.bio, p.avatar_path, p.is_verified, p.badge
    from public.club_accounts a
    join public.clubs c on c.id = a.club_id and c.is_active
    join public.profiles p on p.id = a.profile_id and p.is_active
   where a.club_id = club_account_profile.club_id
     and public.can_manage_club(club_account_profile.club_id);
$$;

revoke all on function public.club_account_profile(uuid) from public, anon;
grant execute on function public.club_account_profile(uuid) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261015030000', 'club_account_profile')
on conflict (version) do nothing;

commit;
