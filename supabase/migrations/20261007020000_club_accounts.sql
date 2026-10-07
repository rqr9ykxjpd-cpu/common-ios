-- Kulüp yöneticileri ve kulüp hesapları.
--
-- Common hesabı (ya da kurucu) bir kişinin kartından onu bir kulübün
-- yöneticisi yapar. Yönetici kendi profilinden "Kulüp hesabına geç" ile
-- kulübün hesabına şifresiz geçer, kulüp hesabında "Ana hesaba geç" ile
-- döner. Kulüp hesabının kendi giriş yöntemi yok: ilk geçişte
-- club-account-switch fonksiyonu açar (auth kullanıcısı + aşağıdaki
-- provision_club_account), her geçişte tek kullanımlık bir giriş anahtarı
-- verir. Kim geçebilir kararı burada; fonksiyon yalnızca uygular.
--
-- Kulüp hesabı: adı kulübün adı (kulüp yeniden adlandırılınca o da), tikli,
-- öğrenci doğrulamasından muaf, önerilerde çıkmaz, kulübün üyesi ve
-- yöneticisi (kulüp sayfasını düzenleyebilir). Eski sürümlerde de profili
-- "Öğrenci kulübü · Resmi hesap" görünür.
begin;

-- Yönetici atayabilen: kurucu ve Common. SQL editörü (oturumsuz) da.
create or replace function public.can_assign_club_managers()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is null
    or public.is_founder()
    or auth.uid() = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b';
$$;
revoke all on function public.can_assign_club_managers() from public, anon, authenticated;

create table if not exists public.club_accounts (
  club_id uuid primary key references public.clubs (id) on delete cascade,
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.club_accounts enable row level security;
revoke all on public.club_accounts from public, anon, authenticated;

-- Ad kilidi (20261006050000): kulüp yeniden adlandırılınca hesabın adı da
-- değişir. İstisna yalnızca aşağıdaki tetikleyicinin açtığı işlem ayarıyla
-- çalışır; kullanıcı bu ayarı API'den değiştiremez.
create or replace function public.profiles_name_lock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    -- Kayıtta ad sağlayıcıdan gelir; gelmediyse kullanıcı adı yazılır.
    -- (Kullanıcı adı bu tetikleyiciden önce profiles_default_username ile dolar.)
    new.name_locked := not (new.name ~ '^[a-z0-9_.]+$' or lower(new.name) = lower(coalesce(new.username, '')));
    return new;
  end if;
  if auth.uid() is null or current_setting('app.club_account_rename', true) = 'on' then
    return new;
  end if;
  if new.name is not distinct from old.name then
    new.name_locked := old.name_locked;
    return new;
  end if;
  if public.is_founder() then
    return new;
  end if;
  if old.name_locked then
    raise exception 'NAME_LOCKED';
  end if;
  new.name_locked := true;
  return new;
end;
$$;

create or replace function public.clubs_rename_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.club_account_rename', 'on', true);
  update public.profiles p
  set name = new.name
  from public.club_accounts a
  where a.club_id = new.id and p.id = a.profile_id;
  perform set_config('app.club_account_rename', 'off', true);
  return new;
end;
$$;
drop trigger if exists clubs_rename_account on public.clubs;
create trigger clubs_rename_account
after update of name on public.clubs
for each row when (new.name is distinct from old.name)
execute function public.clubs_rename_account();

-- Kulüp listesi (seçici için): Common da görür. Gövde canlıdaki tanımdan,
-- tek fark yetki kontrolü.
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
  if auth.uid() is null or not public.can_assign_club_managers() then
    raise exception 'FOUNDER_ONLY';
  end if;
  return query
  select c.id, c.name, c.summary, c.icon, c.next_event, c.place_id, c.accent_hex,
         c.is_active, c.logo_path, c.instagram, c.contact_email,
         (select count(*)::integer from public.club_members cm where cm.club_id = c.id),
         (select count(*)::integer from public.club_managers m where m.club_id = c.id)
  from public.clubs c
  order by c.is_active desc, c.name;
end;
$$;

-- Yönetici ata / kaldır: Common da yapar. Gövde canlıdaki tanımdan; yeni
-- olan yetki ve kulüp hesabı kontrolü (kulüp hesabı başka kulübü yönetmez,
-- kendi kulübündeki yöneticiliği de buradan alınmaz).
create or replace function public.founder_set_club_manager(club_id uuid, user_id uuid, enabled boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_assign_club_managers() then raise exception 'FOUNDER_ONLY'; end if;
  if exists (select 1 from public.club_accounts a where a.profile_id = founder_set_club_manager.user_id) then
    raise exception 'NOT_ALLOWED';
  end if;
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

-- Kişinin yönettiği kulüpler (Common'un kartındaki seçici için).
create or replace function public.club_manager_clubs(target uuid)
returns setof uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_assign_club_managers() then
    raise exception 'FOUNDER_ONLY';
  end if;
  return query select m.club_id from public.club_managers m where m.user_id = target;
end;
$$;
revoke all on function public.club_manager_clubs(uuid) from public, anon;
grant execute on function public.club_manager_clubs(uuid) to authenticated;

-- Oturumdaki hesap bir kulübün hesabıysa kulübü ve `manager` hâlâ o
-- kulübün yöneticisi mi (uygulama kulüp hesabındayken ana hesabın
-- yöneticiliği alınmışsa ana hesaba döner). Kulüp hesabı değilse boş.
create or replace function public.my_club_account(manager uuid)
returns table (club_id uuid, manager_ok boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select a.club_id,
         exists (select 1 from public.club_managers m where m.club_id = a.club_id and m.user_id = manager)
           or exists (select 1 from public.profiles p where p.id = manager and p.badge = 'founder')
           or manager = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b'
  from public.club_accounts a
  where a.profile_id = auth.uid();
$$;
revoke all on function public.my_club_account(uuid) from public, anon;
grant execute on function public.my_club_account(uuid) to authenticated;

-- Geçiş kararı (yalnızca club-account-switch): kulübün yöneticisi, kurucu
-- ya da Common geçebilir; kulüp hesabının kendisi başka hesaba geçemez.
-- Hesap henüz açılmadıysa `account` boş döner.
create or replace function public.club_account_switch_target(caller uuid, club uuid)
returns table (account uuid, club_name text, logo_path text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.club_accounts a where a.profile_id = caller) then
    raise exception 'CLUB_ACCOUNT';
  end if;
  if not exists (select 1 from public.clubs c where c.id = club) then
    raise exception 'CLUB_NOT_FOUND';
  end if;
  if not (
    exists (select 1 from public.club_managers m where m.club_id = club and m.user_id = caller)
    or exists (select 1 from public.profiles p where p.id = caller and p.badge = 'founder' and p.is_active)
    or caller = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b'
  ) then
    raise exception 'CLUB_MANAGER_ONLY';
  end if;
  return query
  select (select a.profile_id from public.club_accounts a where a.club_id = c.id), c.name, c.logo_path
  from public.clubs c
  where c.id = club;
end;
$$;
revoke all on function public.club_account_switch_target(uuid, uuid) from public, anon, authenticated;
grant execute on function public.club_account_switch_target(uuid, uuid) to service_role;

-- Hesabı açar (yalnızca club-account-switch, auth kullanıcısı açıldıktan
-- sonra): profil, kulüp bağı, üyelik ve yöneticilik. Tekrar çağrılırsa
-- eksik kalanı tamamlar, var olanı değiştirmez.
create or replace function public.provision_club_account(club uuid, account uuid, avatar text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  kulup public.clubs;
begin
  select * into kulup from public.clubs c where c.id = club;
  if not found then
    raise exception 'CLUB_NOT_FOUND';
  end if;
  if exists (select 1 from public.club_accounts a where a.club_id = club and a.profile_id <> account) then
    raise exception 'CLUB_ACCOUNT_EXISTS';
  end if;

  insert into public.profiles (
    id, name, birth_date, university, department, academic_year, bio,
    avatar_path, badge, edu_exempt, is_test_account
  )
  values (
    account,
    kulup.name,
    date '2000-01-01',
    coalesce((select p.university from public.profiles p where p.id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b'), 'Common'),
    'Öğrenci kulübü',
    'Resmi hesap',
    left(coalesce(kulup.summary, ''), 500),
    case when avatar like account::text || '/%' then avatar end,
    'verified',
    true,
    true
  )
  on conflict (id) do nothing;

  insert into public.club_accounts (club_id, profile_id) values (club, account)
  on conflict (club_id) do nothing;
  insert into public.club_members (club_id, user_id) values (club, account) on conflict do nothing;
  insert into public.club_managers (club_id, user_id) values (club, account) on conflict do nothing;
end;
$$;
revoke all on function public.provision_club_account(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.provision_club_account(uuid, uuid, text) to service_role;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261007020000', 'club_accounts')
on conflict (version) do nothing;

commit;
