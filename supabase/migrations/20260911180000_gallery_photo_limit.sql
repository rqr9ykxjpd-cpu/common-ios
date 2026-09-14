-- Profile cards are five extra photos. The app already stops at 5, but
-- profile_photos allowed positions 0–5 (six rows) and any authenticated
-- owner could insert past that. Composer "add to cards" writes here, so
-- the limit has to live in SQL.

begin;

-- Repack before tightening the check: a row at position 5 would fail
-- `between 0 and 4` even when the profile still has only five photos.
-- Use a high offset so unique(profile_id, position) never collides mid-update,
-- and so a partial SQL-editor apply can be repaired the same way.
update public.profile_photos
set position = position + 1000;

update public.profile_photos p
set position = r.new_pos
from (
  select id,
    (row_number() over (partition by profile_id order by position, created_at) - 1)::smallint as new_pos
  from public.profile_photos
) r
where p.id = r.id;

delete from public.profile_photos where position > 4;

do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.profile_photos'::regclass
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%position%'
  loop
    execute format('alter table public.profile_photos drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.profile_photos
  add constraint profile_photos_position_check check (position between 0 and 4);

create or replace function public.enforce_gallery_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    select count(*) from public.profile_photos
    where profile_id = new.profile_id
  ) >= 5 then
    raise exception 'gallery_full';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_photos_limit on public.profile_photos;
create trigger profile_photos_limit
before insert on public.profile_photos
for each row execute function public.enforce_gallery_photo_limit();

create or replace function public.append_gallery_photo(p_storage_path text)
returns smallint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_pos smallint;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;
  if p_storage_path is null
     or p_storage_path <> btrim(p_storage_path)
     or p_storage_path not like v_uid::text || '/%' then
    raise exception 'photo_owned_path';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_uid::text));

  select count(*)::smallint into v_pos
  from public.profile_photos
  where profile_id = v_uid;

  if v_pos >= 5 then
    raise exception 'gallery_full';
  end if;

  insert into public.profile_photos (profile_id, storage_path, position)
  values (v_uid, p_storage_path, v_pos);

  return v_pos;
end;
$$;

revoke all on function public.append_gallery_photo(text) from public, anon;
grant execute on function public.append_gallery_photo(text) to authenticated;

commit;
