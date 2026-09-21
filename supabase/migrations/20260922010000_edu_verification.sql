-- Öğrenci e-postası doğrulaması (Build 6).
--
-- Akış: kullanıcı Apple/Google ile girer, sonra edu adresini yazar. İstemci
-- Supabase Auth'un e-posta değişikliği akışını kullanır (auth.updateUser(email)):
-- yeni adrese doğrulama bağlantısı gider, tıklanınca auth.users.email o adres
-- olur. Uygulama öne gelince `sync_edu_verification()` çağırır; adres izinli bir
-- alan adındaysa profil "doğrulanmış öğrenci" olur.
--
-- Kapı yok: doğrulanmamış hesap uygulamayı kullanmaya devam eder (App Review
-- kendi Apple ID'siyle girebilsin). Doğrulama şimdilik rozet + ileride kapı.
-- Kurucu/moderatör ve inceleme hesabı muaf (edu_exempt).
begin;

-- ------------------------------------------------------------ izinli alan adları
create table if not exists public.edu_domains (
  domain text primary key,
  created_at timestamptz not null default now()
);
alter table public.edu_domains enable row level security;
drop policy if exists "edu domains are public" on public.edu_domains;
create policy "edu domains are public" on public.edu_domains for select to authenticated using (true);
-- Alt alan adları da geçerli: ogrenci.<domain>, std.<domain> vb.
insert into public.edu_domains (domain) values ('yalova.edu.tr') on conflict do nothing;

create or replace function public.is_edu_email(address text)
returns boolean language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.edu_domains d
    where lower(split_part(address, '@', 2)) = d.domain
       or lower(split_part(address, '@', 2)) like '%.' || d.domain
  );
$$;

-- ------------------------------------------------------------ profil sütunları
alter table public.profiles
  add column if not exists edu_email text,
  add column if not exists edu_verified_at timestamptz,
  add column if not exists edu_exempt boolean not null default false;

-- Aynı edu adresi iki hesapta doğrulanamaz (auth.users.email zaten tekil; bu da
-- profil tarafında ikinci kilit).
create unique index if not exists profiles_edu_email_idx
  on public.profiles (lower(edu_email)) where edu_email is not null;

-- ------------------------------------------------------------ durum + eşitleme
create or replace function public.get_my_edu_status()
returns table (edu_email text, edu_verified_at timestamptz, edu_exempt boolean)
language sql stable security definer set search_path = '' as $$
  select p.edu_email, p.edu_verified_at,
         (p.edu_exempt or p.badge in ('founder', 'moderator'))
  from public.profiles p where p.id = auth.uid();
$$;
revoke all on function public.get_my_edu_status() from public, anon;
grant execute on function public.get_my_edu_status() to authenticated;

-- auth.users'taki onaylı e-posta izinli bir alan adındaysa profili doğrular.
-- Doğrulama bir kez kazanılır; sonradan e-posta değişse de geri alınmaz.
create or replace function public.sync_edu_verification()
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  adres text;
  onay timestamptz;
  bekleyen text;
begin
  select u.email, u.email_confirmed_at, nullif(u.email_change, '')
    into adres, onay, bekleyen
  from auth.users u where u.id = auth.uid();
  if adres is null or onay is null then return false; end if;
  if not public.is_edu_email(adres) then return false; end if;
  update public.profiles
     set edu_email = lower(adres),
         edu_verified_at = coalesce(edu_verified_at, now())
   where id = auth.uid();
  return true;
end;
$$;
revoke all on function public.sync_edu_verification() from public, anon;
grant execute on function public.sync_edu_verification() to authenticated;

-- ------------------------------------------------------------ inceleme hesabı muafiyeti
-- Kurucu/moderatör rozetten muaf. Google inceleme hesabı için (Test acc) kullanıcı
-- şunu bir kez çalıştırır (uuid'yi Authentication > Users'tan alır):
--   update public.profiles set edu_exempt = true where id = '<uuid>';

commit;
