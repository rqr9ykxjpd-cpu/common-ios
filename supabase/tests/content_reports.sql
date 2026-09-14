-- Run only against a local/staging database after all migrations, as postgres.
-- Uses synthetic users/content and rolls back every fixture. No network access.
begin;

create temporary table report_test_ids (name text primary key, id uuid not null default gen_random_uuid());
insert into report_test_ids(name) values
  ('author'), ('reporter'), ('moderator'), ('outsider'), ('match'),
  ('post'), ('other_post'), ('story'), ('comment'), ('message'), ('other_message');
grant select on report_test_ids to authenticated;

insert into auth.users(id, email)
select id, id::text || '@yalova.edu.tr' from report_test_ids
where name in ('author', 'reporter', 'moderator', 'outsider');
insert into public.profiles(id, name, birth_date, gender, dating_preference,
  university, department, academic_year, is_verified, is_active, discovery_enabled, badge)
select id, 'Test ' || name, date '2000-01-01', 'male', 'everyone',
  'Yalova University', 'Engineering', '3', true, true, true,
  (case when name = 'moderator' then 'moderator' else 'none' end)::public.profile_badge
from report_test_ids where name in ('author', 'reporter', 'moderator', 'outsider');

select set_config('request.jwt.claim.sub', (select id::text from report_test_ids where name = 'author'), true);
insert into public.posts(id, author_id, caption)
select i.id, auth.uid(), 'Original ' || i.name from report_test_ids i where i.name in ('post', 'other_post');
insert into public.stories(id, author_id, media_path, caption)
select id, auth.uid(), auth.uid()::text || '/report-test.jpg', 'Original story'
from report_test_ids where name = 'story';
insert into public.comments(id, post_id, author_id, body)
select id, (select id from report_test_ids where name = 'other_post'), auth.uid(), 'Original comment'
from report_test_ids where name = 'comment';
insert into public.matches(id, user_a, user_b)
select m.id, least(a.id, r.id), greatest(a.id, r.id)
from report_test_ids m, report_test_ids a, report_test_ids r
where m.name = 'match' and a.name = 'author' and r.name = 'reporter';
insert into public.messages(id, match_id, sender_id, body)
select id, (select id from report_test_ids where name = 'match'), auth.uid(), 'Original ' || name
from report_test_ids where name in ('message', 'other_message');

-- A normal member creates exact-content reports. The caller cannot spoof the
-- reported person, overwrite evidence, or claim a report is already handled.
select set_config('request.jwt.claim.sub', (select id::text from report_test_ids where name = 'reporter'), true);
set local role authenticated;
select public.report_content(name, id, 'other', null)
from report_test_ids where name in ('post', 'story', 'comment', 'message');
insert into public.reports(reporter_id, reported_id, reason, target_kind, target_id, content_text, handled_at, resolution)
select auth.uid(), (select id from report_test_ids where name = 'outsider'), 'other', 'post', id,
  'Forged evidence', now(), 'content_removed' from report_test_ids where name = 'other_post';
insert into public.reports(reporter_id, reported_id, reason)
select auth.uid(), id, 'other' from report_test_ids where name = 'author';

do $$
begin
  assert (select count(*) = 5 from public.reports where target_id is not null);
  assert not exists(select 1 from public.reports where content_text = 'Forged evidence');
  assert not exists(select 1 from public.reports where reported_id <> (select id from report_test_ids where name = 'author'));
  assert not exists(select 1 from public.reports where handled_at is not null);
  assert (select content_text = 'Original message' from public.reports where target_kind = 'message');
  assert not has_column_privilege('authenticated', 'public.reports', 'resolution', 'UPDATE');
  begin
    perform public.resolve_content_report((select id from public.reports limit 1), 'dismissed');
    raise exception 'Non-moderator unexpectedly resolved a report';
  exception when raise_exception then
    assert sqlerrm = 'Moderator privileges required';
  end;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', (select id::text from report_test_ids where name = 'outsider'), true);
set local role authenticated;
do $$
begin
  assert not exists(select 1 from public.reports), 'Outsider can read another user''s reports';
  begin
    perform public.report_content('message', (select id from report_test_ids where name = 'message'), 'other', null);
    raise exception 'Guessed private-message ID was accepted';
  exception when raise_exception then
    assert sqlerrm = 'REPORT_CONTENT_UNAVAILABLE';
  end;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', (select id::text from report_test_ids where name = 'author'), true);
set local role authenticated;
do $$
begin
  begin
    perform public.report_content('post', (select id from report_test_ids where name = 'post'), 'other', null);
    raise exception 'Own content was accepted';
  exception when raise_exception then
    assert sqlerrm = 'CANNOT_REPORT_OWN_CONTENT';
  end;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', (select id::text from report_test_ids where name = 'moderator'), true);
set local role authenticated;
do $$
declare
  legacy_id uuid;
  item record;
begin
  select id into legacy_id from public.reports where target_id is null;
  begin
    perform public.resolve_content_report(legacy_id, 'content_removed');
    raise exception 'Legacy profile report falsely marked content removed';
  exception when raise_exception then
    assert sqlerrm = 'REPORT_HAS_NO_CONTENT_TARGET';
  end;
  assert (select handled_at is null from public.reports where id = legacy_id);
  for item in select id from public.reports where target_id in (
    select id from report_test_ids where name in ('post', 'story', 'comment', 'message')
  ) loop
    perform public.resolve_content_report(item.id, 'content_removed');
    perform public.resolve_content_report(item.id, 'content_removed'); -- idempotent retry
  end loop;
  perform public.resolve_content_report(legacy_id, 'dismissed');
  assert (select resolution = 'dismissed' from public.reports where id = legacy_id);
end;
$$;

-- Inspect deletion as postgres (SELECT RLS must not hide a failed deletion).
reset role;
do $$
begin
  assert not exists(select 1 from public.posts where id = (select id from report_test_ids where name = 'post'));
  assert exists(select 1 from public.posts where id = (select id from report_test_ids where name = 'other_post'));
  assert not exists(select 1 from public.stories where id = (select id from report_test_ids where name = 'story'));
  assert not exists(select 1 from public.comments where id = (select id from report_test_ids where name = 'comment'));
  assert not exists(select 1 from public.messages where id = (select id from report_test_ids where name = 'message'));
  assert exists(select 1 from public.messages where id = (select id from report_test_ids where name = 'other_message'));
  assert not has_function_privilege('anon', 'public.report_content(text,uuid,public.report_reason,text)', 'EXECUTE');
  assert not has_function_privilege('anon', 'public.resolve_content_report(uuid,text)', 'EXECUTE');
end;
$$;
rollback;
