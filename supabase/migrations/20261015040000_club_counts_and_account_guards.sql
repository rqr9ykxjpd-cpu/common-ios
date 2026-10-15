-- Kulüp tarafındaki tutarsızlıklar (kurucu: "kulüp tarafı buglarla dolu", 15 Ekim).
--
-- Kulübün hesabı açılırken (provision_club_account) kulübe hem üye hem
-- yönetici olarak ekleniyor; kendi kulübünü düzenleyebilsin diye yönetici
-- olması doğru. Ama:
--   * Kulüp listesindeki sayı `club_members` satırlarını sayıyordu: kulüp
--     hesabı ve kapatılmış hesaplar da sayılıyordu. Kartta 9, sayfadaki
--     listede 8 görünüyordu. Sayı artık tek yerden: aktif, kulüp hesabı
--     olmayan üyeler (`club_member_count`); liste, kurucu listesi ve sayfa
--     aynı sayıyı gösteriyor.
--   * Yönetimdeki üye listesinde kulübün hesabı "Yönetici" olarak çıkıyordu
--     ve çıkarılabiliyordu. Listede yok; çıkarılamıyor.
--   * Kulüp hesabı kendi kulübünden "Kulüpten ayrıl" diyebiliyordu (doğrudan
--     `club_members` silme). Kulüp hesabının üyeliği silinemiyor.
--
-- Fonksiyon gövdeleri canlıdaki tanımlardan kopyalandı (15 Ekim);
-- değişen yerler yorumlu.
begin;

create or replace function public.club_member_count(club uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
    from public.club_members cm
    join public.profiles p on p.id = cm.user_id and p.is_active
   where cm.club_id = club
     and not exists (select 1 from public.club_accounts a where a.profile_id = cm.user_id);
$$;
revoke all on function public.club_member_count(uuid) from public, anon;
grant execute on function public.club_member_count(uuid) to authenticated;

-- Kulüp listesi (1.1.5): açık kulüpler, tutarlı üye sayısı ve benim üyeliğim.
create or replace function public.get_campus_clubs()
returns table (
  id uuid, name text, summary text, icon text, next_event text, accent_hex text,
  place_id uuid, place_name text, place_area text, member_count integer, joined boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.summary, c.icon, c.next_event, c.accent_hex,
         pl.id, pl.name, pl.area,
         public.club_member_count(c.id),
         exists (select 1 from public.club_members cm where cm.club_id = c.id and cm.user_id = auth.uid())
    from public.clubs c
    left join public.places pl on pl.id = c.place_id
   where c.is_active and auth.uid() is not null
   order by c.name;
$$;
revoke all on function public.get_campus_clubs() from public, anon;
grant execute on function public.get_campus_clubs() to authenticated;

-- Kurucu listesi: üye sayısı aynı kuraldan.
create or replace function public.founder_list_clubs()
 returns table(id uuid, name text, summary text, icon text, next_event text, place_id uuid, accent_hex text, is_active boolean, logo_path text, instagram text, contact_email text, member_count integer, manager_count integer)
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
begin
  if auth.uid() is null or not public.can_assign_club_managers() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select c.id, c.name, c.summary, c.icon, c.next_event, c.place_id, c.accent_hex, c.is_active,
           c.logo_path, c.instagram, c.contact_email,
           public.club_member_count(c.id),
           -- Kulübün hesabı yönetici sayılmıyor.
           (select count(*)::integer from public.club_managers m
             where m.club_id = c.id
               and not exists (select 1 from public.club_accounts a where a.profile_id = m.user_id))
      from public.clubs c
     order by c.is_active desc, c.name;
end;
$function$;

-- Yönetimdeki üye listesi: kulübün hesabı yok.
create or replace function public.get_club_people(club_id uuid)
 returns table(id uuid, name text, username text, avatar_path text, is_manager boolean, joined_at timestamp with time zone)
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
begin
  if not public.can_manage_club(get_club_people.club_id) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  return query
    select p.id, p.name, p.username, p.avatar_path,
           exists (select 1 from public.club_managers m where m.club_id = get_club_people.club_id and m.user_id = p.id),
           cm.created_at
      from public.club_members cm
      join public.profiles p on p.id = cm.user_id
     where cm.club_id = get_club_people.club_id
       and not exists (select 1 from public.club_accounts a where a.profile_id = p.id)
    union
    select p.id, p.name, p.username, p.avatar_path, true, m.created_at
      from public.club_managers m
      join public.profiles p on p.id = m.user_id
     where m.club_id = get_club_people.club_id
       and not exists (select 1 from public.club_members cm2 where cm2.club_id = m.club_id and cm2.user_id = m.user_id)
       and not exists (select 1 from public.club_accounts a where a.profile_id = p.id)
     order by 5 desc, 6;
end;
$function$;

-- Üye çıkarma: kulübün hesabı çıkarılamaz.
create or replace function public.club_remove_member(club_id uuid, user_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if not public.can_manage_club(club_remove_member.club_id) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  if exists (select 1 from public.club_accounts a where a.profile_id = club_remove_member.user_id) then
    raise exception 'CLUB_ACCOUNT_PROTECTED';
  end if;
  if not public.is_founder() and exists (
    select 1 from public.club_managers m
     where m.club_id = club_remove_member.club_id and m.user_id = club_remove_member.user_id
  ) then
    raise exception 'CLUB_MANAGER_PROTECTED';
  end if;
  delete from public.club_members cm
   where cm.club_id = club_remove_member.club_id and cm.user_id = club_remove_member.user_id;
end;
$function$;

-- Kulüp hesabı kendi üyeliğini silemez ("Kulüpten ayrıl"). Doğrudan silmeyi
-- izin kuralı yalnızca satırın sahibine bırakıyor; yani tek yol kulüp
-- hesabının kendisi. `security definer`: `club_accounts` kullanıcıya kapalı,
-- tetikleyici kullanıcı yetkisiyle çalışınca herkesin ayrılması hata
-- veriyordu (provada yakalandı).
create or replace function public.club_members_keep_account()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if auth.uid() is not null and auth.uid() = old.user_id
     and exists (select 1 from public.club_accounts a where a.profile_id = old.user_id and a.club_id = old.club_id) then
    raise exception 'CLUB_ACCOUNT_PROTECTED';
  end if;
  return old;
end;
$function$;

drop trigger if exists club_members_keep_account on public.club_members;
create trigger club_members_keep_account before delete on public.club_members
for each row execute function public.club_members_keep_account();

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261015040000', 'club_counts_and_account_guards')
on conflict (version) do nothing;

commit;
