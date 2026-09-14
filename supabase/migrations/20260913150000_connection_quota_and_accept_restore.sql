-- Paywall'daki sayılarla sunucu haklarını eşitler (2026-09-13 ürün kararı):
-- - Bağlantı isteği (kartı sağa kaydırma): kayan 2 günde Free 5 / Plus 10 / Pro sınırsız.
-- - Buluşma kabulü: haftada Free 1 / Plus 5 / Pro sınırsız. (20260913120000 bu
--   kotayı kaldırmıştı; ürün kararıyla geri geliyor, yeni sayıyla.)
-- İstemcideki `SubscriptionTier` aynı sayıları taşır; asıl sınır burasıdır.
-- 20260913120000_subscription_entitlements_cleanup.sql'den SONRA uygulanır.

begin;

-- ------------------------------------------ bağlantı isteği sınırı (48 saat)
create or replace function public.enforce_right_swipe_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  sinir := case public.plan_of(new.actor_id)
             when 'pro'  then null
             when 'plus' then 10
             else 5
           end;
  if sinir is null then return new; end if;

  select count(*) into kullanilan
  from public.profile_right_swipes
  where actor_id = new.actor_id
    and created_at > now() - interval '2 days';

  if kullanilan >= sinir then
    raise exception 'QUOTA_CONNECTION_REQUEST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_right_swipes_quota on public.profile_right_swipes;
create trigger profile_right_swipes_quota before insert on public.profile_right_swipes
for each row execute function public.enforce_right_swipe_quota();

-- ------------------------------------------- buluşma kabulü sınırı (7 gün)
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
             else 1
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

commit;
