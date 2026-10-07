-- Kulüp sayfası ↔ kulüp hesabı. Kulüp sayfasında "Kulübün hesabı",
-- kulüp hesabının profilinde "Kulüp sayfası" bağlantısı bundan çıkar.
-- Hangi hesabın hangi kulübün olduğu herkese açık bilgi; yalnızca açık
-- kulüpler ve etkin hesaplar.
begin;

create or replace function public.club_account_links()
returns table (club_id uuid, profile_id uuid, username text)
language sql
stable
security definer
set search_path = ''
as $$
  select a.club_id, a.profile_id, p.username
  from public.club_accounts a
  join public.clubs c on c.id = a.club_id
  join public.profiles p on p.id = a.profile_id
  where c.is_active and p.is_active;
$$;
revoke all on function public.club_account_links() from public, anon;
grant execute on function public.club_account_links() to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261007030000', 'club_account_links')
on conflict (version) do nothing;

commit;
