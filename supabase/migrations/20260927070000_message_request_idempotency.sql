-- Mesaj isteği yanıtları ağ tekrarı ve iki cihazdan eşzamanlı dokunmaya karşı
-- atomik ve idempotent olmalı. Aynı kabul yalnızca tek ilk mesaj üretir.

begin;

create or replace function public.accept_message_request(request uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  kayit public.message_requests;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into kayit
  from public.message_requests
  where id = request and recipient_id = auth.uid()
  for update;

  if kayit.id is null then raise exception 'Request not found'; end if;

  ilk := least(kayit.sender_id, kayit.recipient_id);
  ikinci := greatest(kayit.sender_id, kayit.recipient_id);

  -- İlk çağrı tamamlandıktan sonra yanıt ağda kaybolmuş olabilir. Tekrar çağrı
  -- yeni mesaj yazmaz; oluşmuş sohbetin kimliğini geri verir.
  if kayit.status = 'accepted' then
    select m.id into eslesme
    from public.matches m
    where m.user_a = ilk and m.user_b = ikinci and m.unmatched_at is null;
    if eslesme is null then raise exception 'MESSAGE_REQUEST_INCONSISTENT'; end if;
    return eslesme;
  end if;

  if kayit.status <> 'pending' then raise exception 'MESSAGE_REQUEST_DECLINED'; end if;

  insert into public.matches(user_a, user_b) values (ilk, ikinci)
  on conflict (user_a, user_b) do update set unmatched_at = null
  returning id into eslesme;

  insert into public.messages(match_id, sender_id, body)
  values (eslesme, kayit.sender_id, kayit.body);

  update public.message_requests set status = 'accepted' where id = request;
  return eslesme;
end;
$$;

revoke all on function public.accept_message_request(uuid) from public, anon;
grant execute on function public.accept_message_request(uuid) to authenticated;

create or replace function public.decline_message_request(request uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  kayit public.message_requests;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into kayit
  from public.message_requests
  where id = request and recipient_id = auth.uid()
  for update;

  if kayit.id is null then raise exception 'Request not found'; end if;
  if kayit.status = 'declined' then return true; end if;
  if kayit.status = 'accepted' then raise exception 'MESSAGE_REQUEST_ACCEPTED'; end if;

  update public.message_requests set status = 'declined' where id = request;
  return true;
end;
$$;

revoke all on function public.decline_message_request(uuid) from public, anon;
grant execute on function public.decline_message_request(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20260927070000', 'message_request_idempotency')
on conflict (version) do nothing;

commit;
