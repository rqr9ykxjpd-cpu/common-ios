-- Run against a local/staging database after the content_text_safety migration.
-- Rolls back all temporary fixtures; never reads real users' text.
begin;

do $$
declare
  example text;
begin
  foreach example in array array['siktir', 'SİKTİR!', 'S1KT1R', 'ＦＵＣＫ',
      'amına koyayım', 'seni öldüreceğim', 'kill, yourself', 'bl0wj0b'] loop
    assert public.content_text_is_blocked(example), 'Expected content to be blocked';
  end loop;
  foreach example in array array['', 'Sık görüşelim', 'Bu çok şık.', 'Amina',
      'Scunthorpe', 'This is a pic of my class', 'Sıkış', 'Kill the process yourself'] loop
    assert not public.content_text_is_blocked(example), 'Unexpected text-filter false positive';
  end loop;
end;
$$;

create temporary table content_safety_fixture (id integer primary key, body text, read_at timestamptz);
-- Represents a legacy row written before filtering was enabled.
insert into content_safety_fixture values (1, 'siktir', null);
create trigger content_text_safety before insert or update of body on content_safety_fixture
for each row execute function public.check_content_text_before_write('body');

do $$
begin
  begin
    insert into content_safety_fixture values (2, 'S1KT1R', null);
    raise exception 'Safety trigger accepted a blocked insert';
  exception when check_violation then
    assert sqlerrm = 'CONTENT_BLOCKED';
  end;
  insert into content_safety_fixture values (2, 'Hello!', null);
  begin
    update content_safety_fixture set body = 'siktir' where id = 2;
    raise exception 'Safety trigger accepted a blocked update';
  exception when check_violation then
    assert sqlerrm = 'CONTENT_BLOCKED';
  end;
  -- Read receipts and unchanged legacy text still work; edits can remove abuse.
  update content_safety_fixture set read_at = now() where id = 1;
  update content_safety_fixture set body = body where id = 1;
  update content_safety_fixture set body = 'Sorry.' where id = 1;
end;
$$;

rollback;
