-- Kabul edilen buluşma isteği karşılıklı niyet sayılır ve gerçek bir sohbet açar.
--
-- İstek durumu ile eşleşme aynı transaction'da değişir. Böylece bağlantı arada
-- koparsa "kabul edildi ama sohbet yok" durumu oluşmaz.

begin;

create or replace function public.accept_meeting_request(request uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  kayit public.meeting_requests;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
begin
  if auth.uid() is null then
    raise exception 'Missing session';
  end if;

  select * into kayit
  from public.meeting_requests
  where id = request
    and recipient_id = auth.uid()
    and status = 'pending'
  for update;

  if kayit.id is null then
    raise exception 'Request not found';
  end if;

  if exists (
    select 1
    from public.blocks
    where (blocker_id = kayit.requester_id and blocked_id = kayit.recipient_id)
       or (blocker_id = kayit.recipient_id and blocked_id = kayit.requester_id)
  ) then
    raise exception 'Profile unavailable';
  end if;

  ilk := least(kayit.requester_id, kayit.recipient_id);
  ikinci := greatest(kayit.requester_id, kayit.recipient_id);

  -- Keşif eşleşmesiyle aynı kilit: iki farklı akış aynı anda aynı çifti
  -- oluşturmaya çalışırsa tek bir eşleşme satırı kalır.
  perform pg_advisory_xact_lock(
    hashtextextended(ilk::text || ':' || ikinci::text, 0)
  );

  select id into eslesme
  from public.matches
  where user_a = ilk and user_b = ikinci
  for update;

  if eslesme is null then
    insert into public.matches (user_a, user_b, unmatched_at)
    values (ilk, ikinci, null)
    returning id into eslesme;

    -- `matches` insert trigger'ı iki tarafa "beğeni eşleşmesi" bildirimi üretir.
    -- Burada kaynak buluşma kabulüdür; gönderen aşağıdaki status update trigger'ından
    -- doğru bildirimi alır, kabul eden ise zaten bu akışın içindedir.
    delete from public.notifications
    where kind = 'match' and match_id = eslesme;
  else
    update public.matches
    set unmatched_at = null
    where id = eslesme;
  end if;

  -- Kota ve kabul bildirimi trigger'ları bu update ile atomik olarak çalışır.
  update public.meeting_requests
  set status = 'accepted'
  where id = request;

  return eslesme;
end;
$$;

revoke all on function public.accept_meeting_request(uuid) from public, anon;
grant execute on function public.accept_meeting_request(uuid) to authenticated;

commit;
