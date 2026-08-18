-- Profil ziyaretleri ("profilini kimler görüntüledi").
--
-- Bu özellik daha önce yalnızca arayüzde vardı; hiçbir yere kaydedilmiyordu, liste
-- her zaman boştu. Gerçek hale getirirken alınan gizlilik kararları:
--
-- 1. Ziyaret kaydını yalnızca profil sahibi görebilir. Ziyaretçi, başkasının
--    ziyaretçi listesini okuyamaz.
-- 2. Aynı kişi tekrar bakınca yeni satır açılmaz; sayaç ve zaman güncellenir.
--    Böylece liste tek kişiyle dolmaz.
-- 3. Kayıtlar 30 günden eskiyse gösterilmez — süresiz iz bırakmıyoruz.
-- 4. Karşılıklı engelleme varsa ziyaret kaydedilmez ve görünmez.
-- 5. Kendi profilini görüntülemek kaydedilmez.
-- 6. Ziyaret kaydı yalnızca `record_profile_visit` RPC'siyle oluşur; istemci
--    doğrudan yazamaz, böylece başkası adına sahte ziyaret üretilemez.
--
-- Idempotent.

begin;

create table if not exists public.profile_visits (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  visitor_id uuid not null references public.profiles(id) on delete cascade,
  visit_count integer not null default 1 check (visit_count > 0),
  last_visited_at timestamptz not null default now(),
  primary key (profile_id, visitor_id),
  check (profile_id <> visitor_id)
);

create index if not exists profile_visits_owner_idx
  on public.profile_visits (profile_id, last_visited_at desc);

alter table public.profile_visits enable row level security;

-- Yalnızca profil sahibi kendi ziyaretçilerini görür.
drop policy if exists "owners read own visits" on public.profile_visits;
create policy "owners read own visits" on public.profile_visits
for select to authenticated using (profile_id = auth.uid());

revoke all on public.profile_visits from anon, authenticated;
grant select on public.profile_visits to authenticated;

-- Ziyaret kaydı yalnızca bu RPC üzerinden; istemciye insert/update yetkisi verilmiyor.
create or replace function public.record_profile_visit(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or target is null or target = auth.uid() then return; end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = target)
       or (b.blocker_id = target and b.blocked_id = auth.uid())
  ) then return; end if;
  if not exists (select 1 from public.profiles p where p.id = target and p.is_active) then return; end if;

  insert into public.profile_visits (profile_id, visitor_id)
  values (target, auth.uid())
  on conflict (profile_id, visitor_id) do update
    set visit_count = public.profile_visits.visit_count + 1,
        last_visited_at = now();
end;
$$;

revoke all on function public.record_profile_visit(uuid) from public, anon;
grant execute on function public.record_profile_visit(uuid) to authenticated;

-- Ziyaretçi listesi. Profil alanları kolon bazlı yetkiyle kısıtlı olduğu için
-- (bkz. tighten_privacy) security definer ile okunuyor; yalnızca çağıranın
-- kendi ziyaretçileri döner.
create or replace function public.get_my_profile_visits()
returns table (
  visitor_id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  visit_count integer, last_visited_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, v.visit_count, v.last_visited_at
  from public.profile_visits v
  join public.profiles p on p.id = v.visitor_id
  where v.profile_id = auth.uid()
    and v.last_visited_at > now() - interval '30 days'
    and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by v.last_visited_at desc
  limit 50;
$$;

revoke all on function public.get_my_profile_visits() from public, anon;
grant execute on function public.get_my_profile_visits() to authenticated;

commit;
