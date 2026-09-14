-- Baseline text filtering for every client, including older app builds.
-- Prepared locally: apply during the separately authorized Supabase setup.
-- This is deliberately a limited token/phrase filter, not image, video or
-- context-aware moderation. Reports are EXCLUDED so users can quote abuse.
-- Keep the token and phrase lists aligned with ContentSafety.swift.

begin;

create or replace function public.content_text_is_blocked(raw_text text)
returns boolean
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  normalized text;
  words text[];
  sentence text;
begin
  normalized := translate(
    lower(normalize(coalesce(raw_text, ''), NFKC)),
    'çğıöşüâîûÇĞİÖŞÜÂÎÛ',
    'cgiosuaiucgiosuaiu'
  );
  normalized := translate(normalized, U&'\200B\200C\200D\2060\FEFF\0307', '');
  select coalesce(array_agg(translate(token, '013457', 'oieast') order by ordinal), '{}'::text[])
  into words
  from regexp_split_to_table(normalized, '[^[:alnum:]]+') with ordinality as pieces(token, ordinal)
  where token <> '';

  if words && array[
    'amk', 'amq', 'aminakoyayim', 'aminakoyim', 'amcik',
    'orospu', 'orospuoglu', 'siktir', 'siktirin', 'siktirgit',
    'sikerim', 'sikeriz', 'sikeyim', 'sikeyin', 'sikicem', 'sikecegim',
    'sikiyorum', 'sikismek', 'yarrak', 'yarragi', 'gotsiken',
    'fuck', 'fucking', 'fucked', 'fucker', 'fuckers', 'fuckoff',
    'motherfucker', 'motherfuckers', 'motherfucking', 'cunt', 'cunts',
    'asshole', 'assholes', 'dickhead', 'dickheads', 'bullshit',
    'porn', 'porno', 'pornhub', 'pornography', 'pornographic',
    'blowjob', 'blowjobs', 'handjob', 'handjobs'
  ] then
    return true;
  end if;

  sentence := ' ' || array_to_string(words, ' ') || ' ';
  return position(' amina koyayim ' in sentence) > 0
      or position(' amina koyim ' in sentence) > 0
      or position(' kill yourself ' in sentence) > 0
      or position(' go die ' in sentence) > 0
      or position(' seni oldurecegim ' in sentence) > 0
      or position(' seni oldururum ' in sentence) > 0
      or position(' sana tecavuz edecegim ' in sentence) > 0;
end;
$$;

create or replace function public.check_content_text_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  column_name text;
  proposed_text text;
begin
  foreach column_name in array tg_argv loop
    proposed_text := to_jsonb(new) ->> column_name;
    -- Updating a like counter/read receipt/other field must not revalidate old
    -- text or make it impossible to moderate a legacy row.
    if tg_op = 'UPDATE' then
      if (to_jsonb(old) ->> column_name) is not distinct from proposed_text then
        continue;
      end if;
    end if;
    if public.content_text_is_blocked(proposed_text) then
      -- No user-written content in errors/logs. The app maps this stable marker
      -- to a localized, actionable message.
      raise exception using errcode = '23514', message = 'CONTENT_BLOCKED';
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function public.content_text_is_blocked(text) from public;
revoke all on function public.check_content_text_before_write() from public;
grant execute on function public.content_text_is_blocked(text) to authenticated, service_role;

drop trigger if exists content_text_safety on public.posts;
create trigger content_text_safety before insert or update of caption, place_name on public.posts
for each row execute function public.check_content_text_before_write('caption', 'place_name');

drop trigger if exists content_text_safety on public.comments;
create trigger content_text_safety before insert or update of body on public.comments
for each row execute function public.check_content_text_before_write('body');

drop trigger if exists content_text_safety on public.stories;
create trigger content_text_safety before insert or update of caption on public.stories
for each row execute function public.check_content_text_before_write('caption');

drop trigger if exists content_text_safety on public.messages;
create trigger content_text_safety before insert or update of body on public.messages
for each row execute function public.check_content_text_before_write('body');

drop trigger if exists content_text_safety on public.message_requests;
create trigger content_text_safety before insert or update of body on public.message_requests
for each row execute function public.check_content_text_before_write('body');

drop trigger if exists content_text_safety on public.profiles;
create trigger content_text_safety before insert or update of name, bio, university, department, academic_year on public.profiles
for each row execute function public.check_content_text_before_write('name', 'bio', 'university', 'department', 'academic_year');

drop trigger if exists content_text_safety on public.profile_interests;
create trigger content_text_safety before insert or update of interest on public.profile_interests
for each row execute function public.check_content_text_before_write('interest');

drop trigger if exists content_text_safety on public.profile_prompts;
create trigger content_text_safety before insert or update of answer on public.profile_prompts
for each row execute function public.check_content_text_before_write('answer');

commit;
