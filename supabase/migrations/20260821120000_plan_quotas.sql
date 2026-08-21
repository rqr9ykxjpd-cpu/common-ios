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
--
-- Kademe `profiles` üzerinde bir sütun DEĞİL, ayrı bir tablo. `profiles`
-- satırının tamamı; paylaşım yapmış, story atmış, yorum yazmış ya da seninle
-- eşleşmiş herkes tarafından okunabiliyor (bkz. "users view relevant
-- profiles"). Kademe orada dursaydı biraz meraklı herkes kimin Plus/Pro
-- olduğunu sorgulayabilirdi — oysa paywall'da açıkça "kimse senin Plus
-- olduğunu bilmeyecek" diyoruz. Ayrı tabloda kural tek satır: yalnızca kendi
-- kademeni görürsün.
create table if not exists public.subscriptions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'plus', 'pro')),
  -- Apple'ın abonelik kimliği. Tekil: bir abonelik yalnızca bir hesabı açar.
  -- Olmasaydı tek Pro aboneliğinin makbuzu elden ele dolaşıp elli hesabı
  -- açardı; Apple'ın kendi doğrulaması bunu engellemiyor, çünkü makbuz gerçek.
  original_transaction_id text,
  product_id text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Tablo daha önce bu sütunlar olmadan oluşturulduysa.
alter table public.subscriptions add column if not exists original_transaction_id text;
alter table public.subscriptions add column if not exists product_id text;
alter table public.subscriptions add column if not exists expires_at timestamptz;
create unique index if not exists subscriptions_original_transaction_idx
  on public.subscriptions (original_transaction_id)
  where original_transaction_id is not null;

alter table public.subscriptions enable row level security;

drop policy if exists "users read own subscription" on public.subscriptions;
create policy "users read own subscription" on public.subscriptions
for select to authenticated using (user_id = auth.uid());

-- Yazma yetkisi hiç kimsede yok: ne insert, ne update, ne delete. Kademeyi
-- yalnızca aşağıdaki `set_plan` değiştirebiliyor. Sütunu tetikleyiciyle
-- korumaya çalışmaktan hem daha basit hem daha sağlam.
revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;

-- Sınır tetikleyicileri, beğeniyi yapan kişinin kademesini okumak zorunda;
-- o satır o kişiye ait olduğu için normal yetkiyle görünmez — bu yüzden
-- security definer.
--
-- Süresi geçmiş abonelik hak vermiyor. Apple yenilemeyi bildirene kadar satır
-- eski haliyle duruyor; tarihe bakmasaydık iptal eden kullanıcı sınırsız
-- kalırdı.
create or replace function public.plan_of(account uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select plan from public.subscriptions
    where user_id = account
      and (expires_at is null or expires_at > now())
  ), 'free');
$$;

revoke all on function public.plan_of(uuid) from public, anon, authenticated;

-- Kademeyi değiştiren tek yol.
--
-- Bilerek `authenticated` rolüne AÇILMIYOR. Açık olsaydı uygulamayı kurcalayan
-- herkes kendine 'pro' deyip bedava Pro olurdu ve bütün sınırlar anlamsızlaşırdı.
-- Gerçek satın alma devreye girdiğinde bunu çağıracak yer, Apple'ın makbuzunu
-- doğrulayan bir Edge Function olacak (service_role ile).
--
-- Test için (SQL editöründe, service_role ile):
--   select public.set_plan('<kullanıcı-uuid>', 'pro');
create or replace function public.set_plan(
  account uuid,
  new_plan text,
  original_transaction text default null,
  product text default null,
  expires timestamptz default null
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_plan not in ('free', 'plus', 'pro') then raise exception 'Invalid plan'; end if;

  -- Aynı Apple aboneliği başka bir hesaba bağlıysa reddediyoruz. Aksi halde
  -- bir kişinin makbuzu istediği kadar hesabı Pro yapardı.
  if original_transaction is not null and exists (
    select 1 from public.subscriptions
    where original_transaction_id = original_transaction and user_id <> account
  ) then
    raise exception 'SUBSCRIPTION_ALREADY_LINKED';
  end if;

  insert into public.subscriptions (user_id, plan, original_transaction_id, product_id, expires_at, updated_at)
  values (account, new_plan, original_transaction, product, expires, now())
  on conflict (user_id) do update set
    plan = excluded.plan,
    original_transaction_id = coalesce(excluded.original_transaction_id, public.subscriptions.original_transaction_id),
    product_id = coalesce(excluded.product_id, public.subscriptions.product_id),
    expires_at = excluded.expires_at,
    updated_at = now();
end;
$$;

revoke all on function public.set_plan(uuid, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.set_plan(uuid, text, text, text, timestamptz) to service_role;
-- Eski iki parametreli sürüm kaldıysa kalmasın.
drop function if exists public.set_plan(uuid, text);

-- Kendi kademeni okumak için. Hiç abone olmamış kullanıcının `subscriptions`'ta
-- satırı yok; boş sonuç yerine 'free' dönsün diye tek bir yer.
create or replace function public.my_plan()
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select plan from public.subscriptions
    where user_id = auth.uid()
      and (expires_at is null or expires_at > now())
  ), 'free');
$$;

revoke all on function public.my_plan() from public, anon;
grant execute on function public.my_plan() to authenticated;

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

-- Bu migration'ın önceki sürümü kademeyi `profiles.plan` sütununda tutuyor ve
-- sütunu bir tetikleyiciyle koruyordu. O yol herkesin başkasının kademesini
-- okumasına açıktı. Hiçbir yere yazılmadan değiştirildiği için taşınacak veri
-- yok; yine de daha önce çalıştırıldıysa kalıntı bırakmayalım.
drop trigger if exists profiles_guard_plan on public.profiles;
drop function if exists public.guard_plan_column();
drop function if exists public.set_my_plan(text);
alter table public.profiles drop column if exists plan;

commit;
