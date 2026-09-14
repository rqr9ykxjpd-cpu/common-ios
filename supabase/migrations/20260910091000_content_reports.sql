-- Exact-content reports, validated evidence, and atomic moderation actions.
-- Existing reports remain profile reports (nullable target). No live deployment
-- is performed by adding this file; deploy before releasing the updated app.
begin;

alter table public.reports
  add column if not exists target_kind text,
  add column if not exists target_id uuid,
  add column if not exists content_text text,
  add column if not exists content_media_path text,
  add column if not exists content_media_bucket text;

alter table public.reports drop constraint if exists reports_valid_target;
alter table public.reports add constraint reports_valid_target check (
  (target_kind is null and target_id is null)
  or (target_kind is not null and target_kind in ('post', 'story', 'comment', 'message') and target_id is not null)
);
create index if not exists reports_content_target_idx
  on public.reports(target_kind, target_id) where target_id is not null;

-- SECURITY INVOKER deliberately preserves the reporter's SELECT RLS. A guessed
-- private-message ID cannot expose its text or create a report for a stranger.
-- Also protects direct REST inserts: the client cannot forge owner/evidence.
create or replace function public.capture_report_content()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  content_owner uuid;
begin
  new.content_text := null;
  new.content_media_path := null;
  new.content_media_bucket := null;

  if new.target_kind is null and new.target_id is null then
    return new;
  end if;
  if new.target_kind is null or new.target_id is null then
    raise exception 'REPORT_TARGET_REQUIRED';
  end if;

  case new.target_kind
    when 'post' then
      select p.author_id, p.caption, p.media_path
        into content_owner, new.content_text, new.content_media_path
      from public.posts p where p.id = new.target_id;
      if new.content_media_path is not null then new.content_media_bucket := 'post-media'; end if;
    when 'story' then
      select s.author_id, s.caption, s.media_path
        into content_owner, new.content_text, new.content_media_path
      from public.stories s where s.id = new.target_id;
      if new.content_media_path is not null then new.content_media_bucket := 'story-media'; end if;
    when 'comment' then
      select c.author_id, c.body into content_owner, new.content_text
      from public.comments c
      join public.posts p on p.id = c.post_id
      where c.id = new.target_id;
    when 'message' then
      select m.sender_id, m.body into content_owner, new.content_text
      from public.messages m where m.id = new.target_id;
    else
      raise exception 'INVALID_REPORT_TARGET';
  end case;

  if content_owner is null then raise exception 'REPORT_CONTENT_UNAVAILABLE'; end if;
  if content_owner = auth.uid() then raise exception 'CANNOT_REPORT_OWN_CONTENT'; end if;
  new.reported_id := content_owner;
  return new;
end;
$$;

drop trigger if exists reports_capture_content on public.reports;
create trigger reports_capture_content before insert on public.reports
for each row execute function public.capture_report_content();

create or replace function public.report_content(
  content_kind text, content_id uuid, report_reason public.report_reason,
  report_details text default null
)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  new_report_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if content_kind is null or content_id is null then raise exception 'REPORT_TARGET_REQUIRED'; end if;
  insert into public.reports (reporter_id, target_kind, target_id, reason, details)
  values (auth.uid(), content_kind, content_id, report_reason, nullif(btrim(report_details), ''))
  returning id into new_report_id;
  return new_report_id;
end;
$$;
revoke all on function public.report_content(text, uuid, public.report_reason, text) from public, anon;
grant execute on function public.report_content(text, uuid, public.report_reason, text) to authenticated;

-- Only a report-resolution transaction may mark content as removed. The old
-- direct UPDATE route could close a report without deleting anything.
drop policy if exists "moderators resolve reports" on public.reports;
revoke update on public.reports from authenticated;
revoke update (handled_at, handled_by, resolution) on public.reports from authenticated;

create or replace function public.resolve_content_report(report_id uuid, report_resolution text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  report public.reports%rowtype;
begin
  if not public.is_moderator() then raise exception 'Moderator privileges required'; end if;
  if report_resolution is null or report_resolution not in ('dismissed', 'content_removed', 'account_suspended') then
    raise exception 'INVALID_REPORT_RESOLUTION';
  end if;
  select * into report from public.reports where id = report_id for update;
  if not found then raise exception 'REPORT_NOT_FOUND'; end if;
  if report.handled_at is not null then
    if report.resolution = report_resolution then return; end if;
    raise exception 'REPORT_ALREADY_RESOLVED';
  end if;

  if report_resolution = 'content_removed' then
    if report.target_kind is null or report.target_id is null then
      raise exception 'REPORT_HAS_NO_CONTENT_TARGET';
    end if;
    -- target IDs are preserved after deletion, so repeats and reports for a
    -- subsequently deleted item remain safe and never delete another row.
    case report.target_kind
      when 'post' then delete from public.posts where id = report.target_id and author_id = report.reported_id;
      when 'story' then delete from public.stories where id = report.target_id and author_id = report.reported_id;
      when 'comment' then delete from public.comments where id = report.target_id and author_id = report.reported_id;
      when 'message' then delete from public.messages where id = report.target_id and sender_id = report.reported_id;
      else raise exception 'INVALID_REPORT_TARGET';
    end case;
  elsif report_resolution = 'account_suspended' then
    perform public.set_account_active(report.reported_id, false);
  end if;

  update public.reports
    set handled_at = now(), handled_by = auth.uid(), resolution = report_resolution
    where id = report.id;
end;
$$;
revoke all on function public.resolve_content_report(uuid, text) from public, anon;
grant execute on function public.resolve_content_report(uuid, text) to authenticated;

-- A moderator can inspect only media referenced by a report. A reported
-- private message is exposed through its captured text, never a whole thread.
create or replace function public.can_read_reported_media(media_bucket text, media_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_moderator() and exists (
    select 1 from public.reports r
    where r.content_media_bucket = media_bucket and r.content_media_path = media_name
  );
$$;
revoke all on function public.can_read_reported_media(text, text) from public, anon;
grant execute on function public.can_read_reported_media(text, text) to authenticated;
drop policy if exists "moderators read reported media" on storage.objects;
create policy "moderators read reported media" on storage.objects for select to authenticated
using (bucket_id in ('post-media', 'story-media') and public.can_read_reported_media(bucket_id, name));

commit;
