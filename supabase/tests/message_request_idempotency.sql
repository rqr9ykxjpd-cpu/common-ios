-- Synthetic fixtures only. Every write is rolled back.
begin;

create temporary table message_request_test_ids(
  label text primary key,
  id uuid default gen_random_uuid()
);
insert into message_request_test_ids(label)
values ('sender_accept'), ('sender_decline'), ('recipient');
grant select on message_request_test_ids to authenticated;

insert into auth.users(id, email)
select id, label || '@example.com' from message_request_test_ids;

insert into public.profiles(
  id, name, birth_date, university, department, academic_year,
  is_verified, is_active
)
select id, initcap(label), '2002-01-01', 'Yalova', 'Test', '3', true, true
from message_request_test_ids;

insert into public.message_requests(sender_id, recipient_id, body)
select s.id, r.id, 'Tek kez yazılmalı'
from message_request_test_ids s, message_request_test_ids r
where s.label = 'sender_accept' and r.label = 'recipient';

insert into public.message_requests(sender_id, recipient_id, body)
select s.id, r.id, 'Reddedilecek'
from message_request_test_ids s, message_request_test_ids r
where s.label = 'sender_decline' and r.label = 'recipient';

select set_config(
  'request.jwt.claim.sub',
  (select id::text from message_request_test_ids where label = 'recipient'),
  true
);
set local role authenticated;

do $$
declare
  accept_request uuid;
  decline_request uuid;
  first_match uuid;
  retry_match uuid;
begin
  select id into accept_request
  from public.message_requests where body = 'Tek kez yazılmalı';
  select id into decline_request
  from public.message_requests where body = 'Reddedilecek';

  first_match := public.accept_message_request(accept_request);
  retry_match := public.accept_message_request(accept_request);

  assert first_match = retry_match,
    'Retrying an accepted request must return the same conversation';
  assert (select count(*) = 1 from public.messages
          where match_id = first_match and body = 'Tek kez yazılmalı'),
    'Retrying accept must not duplicate the first message';

  assert public.decline_message_request(decline_request);
  assert public.decline_message_request(decline_request),
    'Retrying decline must succeed without changing another state';
  assert (select status = 'declined' from public.message_requests
          where id = decline_request),
    'Decline must persist the terminal state';
end $$;

reset role;
rollback;
