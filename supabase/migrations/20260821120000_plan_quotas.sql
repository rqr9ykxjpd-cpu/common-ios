-- Abonelik kademeleri ve sayılı sınırlar.
--
-- Sınırlar sunucuda uygulanmak zorunda: istemcideki bir sayaç, uygulamayı
-- kurcalayan biri için hiçbir engel değil.
--
-- Kurallar:
--   Tanış beğenisi (48 saatte)   ücretsiz 5 · plus 10 · pro sınırsız
--   Buluşma isteği (7 günde)     ücretsiz 3 · plus  5 · pro sınırsız
--   Buluşma kabulü (7 günde)     ücretsiz 2 · plus  5 · pro sınırsız
--
-- Uygulama, sınıra takıldığını hata mesajından anlıyor: QUOTA_LIKE,
-- QUOTA_MEETING_REQUEST, QUOTA_MEETING_ACCEPT. Metne göre değil bu koda göre
-- davranıyor, çünkü metin değişebilir.
--
-- `react_to_profile` gibi büyük fonksiyonlar yeniden yazılmıyor; sınırlar
-- tetikleyicilerle uygulanıyor. Böylece mevcut mantığa hiç dokunulmuyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

-- ------------------------------------------------------------------- kademe
alter table public.profiles
  add column if not exists plan text not null default 'free'
  check (plan in ('free', 'plus', 'pro'));

-- Kullanıcı kendi kademesini doğrudan yazamamalı. Yazma yetkisi yalnızca bu
-- fonksiyonda; ileride Apple'ın sunucu bildirimleri devreye girince burası
-- makbuz doğrulamasıyla değiştirilecek.
create or replace function public.plan_of(account uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((select plan from public.profiles where id = account), 'free');
$$;

create or replace function public.set_my_plan(new_plan text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if new_plan not in ('free', 'plus', 'pro') then raise exception 'Invalid plan'; end if;
  -- Aşağıdaki tetikleyicinin bu değişikliğe izin vermesi için işaret. İşlem
  -- sonunda kendiliğinden siliniyor (üçüncü parametre: yalnızca bu işlem).
  perform set_config('app.plan_change', '1', true);
  update public.profiles set plan = new_plan where id = auth.uid();
end;
$$;

-- `profiles` üzerinde authenticated rolünün UPDATE yetkisi var (profil
-- düzenleme için gerekli) ve sütun bazında kısıtlamak mevcut yetkileri
-- yeniden kurmayı gerektirirdi. Bunun yerine `plan` sütununu tetikleyiciyle
-- koruyoruz: yalnızca `set_my_plan` içinden değiştirilebiliyor. Aksi halde
-- herkes kendini 'pro' yapar ve bütün sınırlar anlamsızlaşırdı.
create or replace function public.guard_plan_column()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.plan is distinct from old.plan
     and coalesce(current_setting('app.plan_change', true), '') <> '1' then
    raise exception 'Plan cannot be changed directly';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_plan on public.profiles;
create trigger profiles_guard_plan before update on public.profiles
for each row execute function public.guard_plan_column();

revoke all on function public.set_my_plan(text) from public, anon;
grant execute on function public.set_my_plan(text) to authenticated;
revoke all on function public.plan_of(uuid) from public, anon;

-- ------------------------------------------------------- beğeni sınırı (48s)
create or replace function public.enforce_like_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  -- Yalnızca yeni bir 'like' sayılıyor. 'pass' sınırsız; 'like'ı tekrar
  -- kaydetmek (aynı kişi) yeni hak harcamamalı.
  if new.kind <> 'like' then return new; end if;
  if tg_op = 'UPDATE' and old.kind = 'like' then return new; end if;

  sinir := case public.plan_of(new.actor_id)
             when 'pro'  then null
             when 'plus' then 10
             else 5
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.reactions
  where actor_id = new.actor_id
    and kind = 'like'
    and updated_at > now() - interval '48 hours'
    and subject_id <> new.subject_id;

  if kullanilan >= sinir then
    raise exception 'QUOTA_LIKE' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists reactions_like_quota on public.reactions;
create trigger reactions_like_quota before insert or update on public.reactions
for each row execute function public.enforce_like_quota();

-- ------------------------------------------------ buluşma isteği sınırı (7g)
create or replace function public.enforce_meeting_request_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  sinir := case public.plan_of(new.requester_id)
             when 'pro'  then null
             when 'plus' then 5
             else 3
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.meeting_requests
  where requester_id = new.requester_id
    and created_at > now() - interval '7 days';

  if kullanilan >= sinir then
    raise exception 'QUOTA_MEETING_REQUEST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists meeting_requests_quota on public.meeting_requests;
create trigger meeting_requests_quota before insert on public.meeting_requests
for each row execute function public.enforce_meeting_request_quota();

-- ------------------------------------------------ buluşma kabulü sınırı (7g)
create or replace function public.enforce_meeting_accept_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  if new.status <> 'accepted' or old.status = 'accepted' then return new; end if;

  sinir := case public.plan_of(new.recipient_id)
             when 'pro'  then null
             when 'plus' then 5
             else 2
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.meeting_requests
  where recipient_id = new.recipient_id
    and status = 'accepted'
    and updated_at > now() - interval '7 days'
    and id <> new.id;

  if kullanilan >= sinir then
    raise exception 'QUOTA_MEETING_ACCEPT' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists meeting_requests_accept_quota on public.meeting_requests;
create trigger meeting_requests_accept_quota before update of status on public.meeting_requests
for each row execute function public.enforce_meeting_accept_quota();

-- Kademeyi istemcinin okuyabilmesi için: profil sütun izni.
grant select (plan) on public.profiles to authenticated;

commit;
