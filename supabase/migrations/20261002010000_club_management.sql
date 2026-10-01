-- Kulüp yönetimi (1.2).
--
-- Kurucu kulüp açar, düzenler, kapatır ve kulübe yönetici atar. Yönetici
-- yalnızca kendi kulübünü düzenler (adı ve açık/kapalı durumu kurucuda kalır),
-- logosunu değiştirir, üyelerini görür ve gerekirse birini çıkarır.
--
-- Yalnızca ekleme: mevcut `clubs` ve `club_members` kuralları değişmiyor;
-- yayındaki 1.0 ve incelemedeki 1.1 bu fonksiyonları çağırmıyor, eklenen
-- kolonları da seçmiyor. Yetki her işlemde sunucuda kontrol ediliyor.
begin;

alter table public.clubs
  add column if not exists logo_path text,
  add column if not exists instagram text,
  add column if not exists contact_email text,
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by uuid references auth.users (id) on delete set null;

alter table public.clubs drop constraint if exists clubs_instagram_check;
alter table public.clubs add constraint clubs_instagram_check
  check (instagram is null or instagram ~ '^[A-Za-z0-9._]{1,30}$');
alter table public.clubs drop constraint if exists clubs_contact_email_check;
alter table public.clubs add constraint clubs_contact_email_check
  check (contact_email is null or (char_length(contact_email) <= 120 and contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'));

create table if not exists public.club_managers (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  granted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);
alter table public.club_managers enable row level security;
revoke all on public.club_managers from anon, authenticated;

-- Kulübü yönetebilir mi: kurucu ya da o kulübün yöneticisi.
create or replace function public.can_manage_club(club uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and (
    public.is_founder()
    or exists (select 1 from public.club_managers m where m.club_id = club and m.user_id = auth.uid())
  );
$$;
revoke all on function public.can_manage_club(uuid) from public, anon;
grant execute on function public.can_manage_club(uuid) to authenticated;

-- Yönettiğim kulüpler (kulüp sayfasında "Düzenle" için). Kurucu hepsini yönetir;
-- uygulama bunu rozetten zaten biliyor, burada yalnızca atanmışlar.
create or replace function public.get_my_managed_clubs()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.club_id from public.club_managers m where m.user_id = auth.uid();
$$;
revoke all on function public.get_my_managed_clubs() from public, anon;
grant execute on function public.get_my_managed_clubs() to authenticated;

-- Kurucu listesi: kapalılar dahil, üye ve yönetici sayısıyla.
create or replace function public.founder_list_clubs()
returns table (
  id uuid, name text, summary text, icon text, next_event text, place_id uuid,
  accent_hex text, is_active boolean, logo_path text, instagram text,
  contact_email text, member_count integer, manager_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select c.id, c.name, c.summary, c.icon, c.next_event, c.place_id, c.accent_hex,
           c.is_active, c.logo_path, c.instagram, c.contact_email,
           (select count(*)::integer from public.club_members cm where cm.club_id = c.id),
           (select count(*)::integer from public.club_managers m where m.club_id = c.id)
      from public.clubs c
     order by c.is_active desc, c.name;
end;
$$;
revoke all on function public.founder_list_clubs() from public, anon;
grant execute on function public.founder_list_clubs() to authenticated;

-- Kaydet. Kurucu yeni kulüp açar ya da her alanı değiştirir; yönetici adı ve
-- açık/kapalı durumu değiştiremez (gönderdiği değerler yok sayılır).
create or replace function public.save_club(
  club_id uuid,
  name text,
  summary text,
  icon text,
  next_event text,
  place_id uuid,
  accent_hex text,
  instagram text,
  contact_email text,
  is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  kurucu boolean := public.is_founder();
  hedef uuid := save_club.club_id;
  ig text := nullif(btrim(regexp_replace(coalesce(save_club.instagram, ''), '^@', '')), '');
  posta text := nullif(btrim(coalesce(save_club.contact_email, '')), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if hedef is null then
    if not kurucu then raise exception 'FOUNDER_ONLY'; end if;
    insert into public.clubs (name, summary, icon, next_event, place_id, accent_hex,
                              instagram, contact_email, is_active, updated_at, updated_by)
    values (btrim(save_club.name), coalesce(btrim(save_club.summary), ''),
            coalesce(nullif(btrim(save_club.icon), ''), 'person.3.fill'),
            coalesce(btrim(save_club.next_event), ''), save_club.place_id,
            coalesce(nullif(btrim(save_club.accent_hex), ''), '7C5CFF'),
            ig, posta, coalesce(save_club.is_active, true), now(), auth.uid())
    returning id into hedef;
    return hedef;
  end if;

  if not public.can_manage_club(hedef) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  update public.clubs c
     set name = case when kurucu then btrim(save_club.name) else c.name end,
         is_active = case when kurucu then coalesce(save_club.is_active, c.is_active) else c.is_active end,
         summary = coalesce(btrim(save_club.summary), ''),
         icon = coalesce(nullif(btrim(save_club.icon), ''), c.icon),
         next_event = coalesce(btrim(save_club.next_event), ''),
         place_id = save_club.place_id,
         accent_hex = coalesce(nullif(btrim(save_club.accent_hex), ''), c.accent_hex),
         instagram = ig,
         contact_email = posta,
         updated_at = now(),
         updated_by = auth.uid()
   where c.id = hedef;
  if not found then raise exception 'Club not found'; end if;
  return hedef;
end;
$$;
revoke all on function public.save_club(uuid, text, text, text, text, uuid, text, text, text, boolean) from public, anon;
grant execute on function public.save_club(uuid, text, text, text, text, uuid, text, text, text, boolean) to authenticated;

-- Logo: dosya önce `club-media/<kulüp>/...` altına yüklenir, sonra yolu buraya.
create or replace function public.set_club_logo(club_id uuid, path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_club(set_club_logo.club_id) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  if path is not null and split_part(path, '/', 1) <> set_club_logo.club_id::text then
    raise exception 'Invalid logo path';
  end if;
  update public.clubs set logo_path = path, updated_at = now(), updated_by = auth.uid()
   where id = set_club_logo.club_id;
end;
$$;
revoke all on function public.set_club_logo(uuid, text) from public, anon;
grant execute on function public.set_club_logo(uuid, text) to authenticated;

-- Yöneticiler ve üyeler (kurucu ya da o kulübün yöneticisi görür).
create or replace function public.get_club_people(club_id uuid)
returns table (id uuid, name text, username text, avatar_path text, is_manager boolean, joined_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_club(get_club_people.club_id) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  return query
    select p.id, p.name, p.username, p.avatar_path,
           exists (select 1 from public.club_managers m where m.club_id = get_club_people.club_id and m.user_id = p.id),
           cm.created_at
      from public.club_members cm
      join public.profiles p on p.id = cm.user_id
     where cm.club_id = get_club_people.club_id
    union
    select p.id, p.name, p.username, p.avatar_path, true, m.created_at
      from public.club_managers m
      join public.profiles p on p.id = m.user_id
     where m.club_id = get_club_people.club_id
       and not exists (select 1 from public.club_members cm2 where cm2.club_id = m.club_id and cm2.user_id = m.user_id)
     order by 5 desc, 6;
end;
$$;
revoke all on function public.get_club_people(uuid) from public, anon;
grant execute on function public.get_club_people(uuid) to authenticated;

-- Kurucu: yönetici ata / kaldır. Yönetici aynı zamanda üye olur.
create or replace function public.founder_set_club_manager(club_id uuid, user_id uuid, enabled boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if coalesce(enabled, false) then
    insert into public.club_managers (club_id, user_id, granted_by)
    values (founder_set_club_manager.club_id, founder_set_club_manager.user_id, auth.uid())
    on conflict do nothing;
    insert into public.club_members (club_id, user_id)
    values (founder_set_club_manager.club_id, founder_set_club_manager.user_id)
    on conflict do nothing;
    return true;
  end if;
  delete from public.club_managers m
   where m.club_id = founder_set_club_manager.club_id and m.user_id = founder_set_club_manager.user_id;
  return false;
end;
$$;
revoke all on function public.founder_set_club_manager(uuid, uuid, boolean) from public, anon;
grant execute on function public.founder_set_club_manager(uuid, uuid, boolean) to authenticated;

-- Yönetici ya da kurucu: üyeyi kulüpten çıkar (yönetici başka yöneticiyi çıkaramaz).
create or replace function public.club_remove_member(club_id uuid, user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_club(club_remove_member.club_id) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  if not public.is_founder() and exists (
    select 1 from public.club_managers m
     where m.club_id = club_remove_member.club_id and m.user_id = club_remove_member.user_id
  ) then
    raise exception 'CLUB_MANAGER_PROTECTED';
  end if;
  delete from public.club_members cm
   where cm.club_id = club_remove_member.club_id and cm.user_id = club_remove_member.user_id;
end;
$$;
revoke all on function public.club_remove_member(uuid, uuid) from public, anon;
grant execute on function public.club_remove_member(uuid, uuid) to authenticated;

-- Logolar: herkese açık okunur (kulüp kimliği gizli değil); yükleme ve silme
-- yalnızca kurucu ya da o kulübün yöneticisi, kendi kulübünün klasörüne.
insert into storage.buckets (id, name, public)
values ('club-media', 'club-media', true)
on conflict (id) do nothing;

drop policy if exists "club managers upload club media" on storage.objects;
create policy "club managers upload club media" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'club-media'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_manage_club(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "club managers update club media" on storage.objects;
create policy "club managers update club media" on storage.objects
for update to authenticated
using (
  bucket_id = 'club-media'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_manage_club(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "club managers delete club media" on storage.objects;
create policy "club managers delete club media" on storage.objects
for delete to authenticated
using (
  bucket_id = 'club-media'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_manage_club(((storage.foldername(name))[1])::uuid)
);

commit;
