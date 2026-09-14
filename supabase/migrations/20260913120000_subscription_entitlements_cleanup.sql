-- Paywall ile sunucu haklarını aynılaştırır:
-- - Free haftada 2 kampüs buluşma isteği gönderebilir.
-- - Gelen isteği kabul etmek bütün planlarda sınırsızdır.
-- - Mesaj gövdesi düzenleme/silme gerçekten Plus veya Pro gerektirir.
-- İstemci arayüzündeki kilit tek başına güvenlik sınırı değildir.

begin;

create or replace function public.enforce_meeting_request_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sinir integer;
  kullanilan integer;
begin
  sinir := case public.plan_of(new.requester_id)
             when 'pro'  then null
             when 'plus' then 5
             else 2
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

-- Kabul kotasını tamamen kaldır. Eski fonksiyon başka bir nesne tarafından
-- kullanılmıyorsa temizlenir; trigger'ın kalkması davranış için yeterlidir.
drop trigger if exists meeting_requests_accept_quota on public.meeting_requests;
drop function if exists public.enforce_meeting_accept_quota();

drop policy if exists "senders edit own messages" on public.messages;
create policy "senders edit own messages" on public.messages
for update to authenticated
using (
  sender_id = auth.uid()
  and public.is_match_member(match_id)
  and public.plan_of(auth.uid()) in ('plus', 'pro')
)
with check (
  sender_id = auth.uid()
  and public.is_match_member(match_id)
  and public.plan_of(auth.uid()) in ('plus', 'pro')
);

drop policy if exists "senders delete own messages" on public.messages;
create policy "senders delete own messages" on public.messages
for delete to authenticated
using (
  sender_id = auth.uid()
  and public.is_match_member(match_id)
  and public.plan_of(auth.uid()) in ('plus', 'pro')
);

commit;
