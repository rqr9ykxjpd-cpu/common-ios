-- Öğrenci e-postası doğrulamasını görünür profil rozetiyle tamamlar.
--
-- `is_verified` üyeliğin uygulamayı kullanma kapısıdır; öğrenci doğrulaması
-- değildir. Doğrulanan öğrencilere mevcut, sunucu kontrollü `verified` rozeti
-- verilir. Kurucu/moderatör rozetleri korunur.
begin;

-- RLS tek başına tablo erişimi vermez; canlı projedeki varsayılan ayrıcalıklara
-- güvenmeden yalnızca alan adı listesini oturum açmış kullanıcılara aç.
revoke all on public.edu_domains from anon;
grant select on public.edu_domains to authenticated;

create or replace function public.sync_edu_verification()
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  address text;
  confirmed_at timestamptz;
  changed integer;
begin
  select lower(u.email), u.email_confirmed_at
    into address, confirmed_at
  from auth.users u
  where u.id = auth.uid();

  if address is null or confirmed_at is null or not public.is_edu_email(address) then
    return false;
  end if;

  update public.profiles
     set edu_email = address,
         edu_verified_at = coalesce(edu_verified_at, now()),
         badge = case when badge = 'none' then 'verified' else badge end
   where id = auth.uid();
  get diagnostics changed = row_count;
  return changed = 1;
end;
$$;

revoke all on function public.sync_edu_verification() from public, anon;
grant execute on function public.sync_edu_verification() to authenticated;

-- Migration daha önce çalıştıysa mevcut doğrulanmış hesapları da görünür
-- rozetle eşitle. Yetkili hesapların özel rozetlerine dokunma.
update public.profiles
set badge = 'verified'
where edu_verified_at is not null and badge = 'none';

commit;
