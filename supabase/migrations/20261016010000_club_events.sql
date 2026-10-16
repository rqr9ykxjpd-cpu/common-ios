-- Kulüp etkinlikleri (kurucunun isteği, 16 Ekim): tarih-saat, yer, katılım.
--
-- Eskiden kulübün "yaklaşan etkinliği" `clubs.next_event` içinde düz bir
-- metindi: tarih yok, kim geliyor belli değil. Artık:
--   * Kulübü yönetenler (kurucu, kulübün yöneticileri, kulübün hesabı)
--     etkinlik açar, düzenler, iptal eder (`save_club_event`, `cancel_club_event`).
--   * Herkes "Katılıyorum" diyebilir (`set_club_event_attendance`); kulübe üye
--     olmak gerekmiyor, öğrenci kilidi diğer etkileşimlerdeki gibi.
--   * Katılanlar herkese görünür (kulüp üyeleri gibi); engelleşenler birbirini
--     görmez.
--   * Hatırlatma telefonda (yerel bildirim): katıldığın etkinlikler
--     `get_my_club_events` ile okunup başlamadan bir saat önceye kuruluyor.
--
-- Eski sürümler `clubs.next_event`i göstermeye devam ediyor: etkinlik
-- kaydedilince ya da iptal edilince en yakın etkinlik oraya yazılıyor
-- ("Sergi açılışı · 18.10 19:00").
--
-- Tablolara doğrudan erişim yok; hepsi aşağıdaki fonksiyonlardan.
begin;

create table if not exists public.club_events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 80),
  details text not null default '' check (char_length(details) <= 500),
  starts_at timestamptz not null,
  place_id uuid references public.places(id) on delete set null,
  place_note text not null default '' check (char_length(place_note) <= 80),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz
);
create index if not exists club_events_club_starts_idx on public.club_events (club_id, starts_at);
alter table public.club_events enable row level security;
revoke all on public.club_events from public, anon, authenticated;

create table if not exists public.club_event_attendees (
  event_id uuid not null references public.club_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index if not exists club_event_attendees_user_idx on public.club_event_attendees (user_id);
alter table public.club_event_attendees enable row level security;
revoke all on public.club_event_attendees from public, anon, authenticated;

-- Öğrenci kilidi: diğer etkileşim tablolarıyla aynı tetikleyici.
drop trigger if exists club_event_attendees_edu_gate on public.club_event_attendees;
create trigger club_event_attendees_edu_gate before insert on public.club_event_attendees
for each row execute function public.edu_gate_guard();

-- Eski sürümler için: en yakın etkinlik `clubs.next_event`e.
create or replace function public.refresh_club_next_event(club uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.clubs c
     set next_event = coalesce((
           select left(e.title, 120) || ' · ' || to_char(e.starts_at at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')
             from public.club_events e
            where e.club_id = club and e.cancelled_at is null and e.starts_at > now()
            order by e.starts_at
            limit 1), '')
   where c.id = club;
$$;
revoke all on function public.refresh_club_next_event(uuid) from public, anon, authenticated;

-- Aç ya da düzenle. Yeni etkinlikte `event_id` boş.
create or replace function public.save_club_event(
  event_id uuid, club_id uuid, title text, details text,
  starts_at timestamptz, place_id uuid, place_note text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  hedef uuid := save_club_event.event_id;
  kulup uuid := save_club_event.club_id;
  baslik text := btrim(coalesce(save_club_event.title, ''));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if hedef is not null then
    select e.club_id into kulup from public.club_events e
     where e.id = hedef and e.cancelled_at is null;
    if not found then raise exception 'EVENT_NOT_FOUND'; end if;
  end if;
  if not exists (select 1 from public.clubs c where c.id = kulup and c.is_active) then
    raise exception 'CLUB_NOT_FOUND';
  end if;
  if not public.can_manage_club(kulup) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  if char_length(baslik) not between 1 and 80 then raise exception 'EVENT_TITLE_INVALID'; end if;
  if save_club_event.starts_at is null
     or save_club_event.starts_at < now() - interval '1 hour'
     or save_club_event.starts_at > now() + interval '1 year' then
    raise exception 'EVENT_TIME_INVALID';
  end if;

  if hedef is null then
    if (select count(*) from public.club_events e
         where e.club_id = kulup and e.cancelled_at is null and e.starts_at > now()) >= 20 then
      raise exception 'EVENT_LIMIT';
    end if;
    insert into public.club_events (club_id, title, details, starts_at, place_id, place_note, created_by)
    values (kulup, baslik, left(coalesce(btrim(save_club_event.details), ''), 500),
            save_club_event.starts_at, save_club_event.place_id,
            left(coalesce(btrim(save_club_event.place_note), ''), 80), auth.uid())
    returning id into hedef;
  else
    update public.club_events e
       set title = baslik,
           details = left(coalesce(btrim(save_club_event.details), ''), 500),
           starts_at = save_club_event.starts_at,
           place_id = save_club_event.place_id,
           place_note = left(coalesce(btrim(save_club_event.place_note), ''), 80),
           updated_at = now()
     where e.id = hedef;
  end if;

  perform public.refresh_club_next_event(kulup);
  return hedef;
end;
$$;
revoke all on function public.save_club_event(uuid, uuid, text, text, timestamptz, uuid, text) from public, anon;
grant execute on function public.save_club_event(uuid, uuid, text, text, timestamptz, uuid, text) to authenticated;

create or replace function public.cancel_club_event(event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  kulup uuid;
begin
  select e.club_id into kulup from public.club_events e
   where e.id = cancel_club_event.event_id and e.cancelled_at is null;
  if not found then raise exception 'EVENT_NOT_FOUND'; end if;
  if not public.can_manage_club(kulup) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  update public.club_events e set cancelled_at = now(), updated_at = now()
   where e.id = cancel_club_event.event_id;
  perform public.refresh_club_next_event(kulup);
end;
$$;
revoke all on function public.cancel_club_event(uuid) from public, anon;
grant execute on function public.cancel_club_event(uuid) to authenticated;

-- Katılıyorum / vazgeç. Güncel katılımcı sayısını döner.
create or replace function public.set_club_event_attendance(event_id uuid, going boolean)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  ben uuid := auth.uid();
begin
  if ben is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists (
    select 1 from public.club_events e
      join public.clubs c on c.id = e.club_id and c.is_active
     where e.id = set_club_event_attendance.event_id
       and e.cancelled_at is null
       and e.starts_at > now() - interval '2 hours'
  ) then
    raise exception 'EVENT_NOT_FOUND';
  end if;
  if coalesce(going, false) then
    insert into public.club_event_attendees (event_id, user_id)
    values (set_club_event_attendance.event_id, ben)
    on conflict do nothing;
  else
    delete from public.club_event_attendees a
     where a.event_id = set_club_event_attendance.event_id and a.user_id = ben;
  end if;
  return (select count(*)::integer from public.club_event_attendees a
           join public.profiles p on p.id = a.user_id and p.is_active
          where a.event_id = set_club_event_attendance.event_id);
end;
$$;
revoke all on function public.set_club_event_attendance(uuid, boolean) from public, anon;
grant execute on function public.set_club_event_attendance(uuid, boolean) to authenticated;

-- Kulüp sayfası: yaklaşan (ya da 3 saat içinde başlamış) etkinlikler.
-- Katılımcı sayısı ve ilk üç katılımcının fotoğrafı; engelleşenler sayılmıyor.
create or replace function public.get_club_events(club_id uuid)
returns table (
  id uuid, title text, details text, starts_at timestamptz,
  place_id uuid, place_name text, place_note text,
  attendee_count integer, going boolean, attendee_avatars text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.title, e.details, e.starts_at, e.place_id, pl.name, e.place_note,
         (select count(*)::integer from public.club_event_attendees a
            join public.profiles p on p.id = a.user_id and p.is_active
           where a.event_id = e.id
             and not exists (select 1 from public.blocks b
                              where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
                                 or (b.blocker_id = a.user_id and b.blocked_id = auth.uid()))),
         exists (select 1 from public.club_event_attendees a where a.event_id = e.id and a.user_id = auth.uid()),
         array(select p.avatar_path from public.club_event_attendees a
                 join public.profiles p on p.id = a.user_id and p.is_active and p.avatar_path is not null
                where a.event_id = e.id
                  and not exists (select 1 from public.blocks b
                                   where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
                                      or (b.blocker_id = a.user_id and b.blocked_id = auth.uid()))
                order by a.created_at
                limit 3)
    from public.club_events e
    join public.clubs c on c.id = e.club_id and c.is_active
    left join public.places pl on pl.id = e.place_id
   where e.club_id = get_club_events.club_id
     and e.cancelled_at is null
     and e.starts_at > now() - interval '3 hours'
     and auth.uid() is not null
   order by e.starts_at
   limit 20;
$$;
revoke all on function public.get_club_events(uuid) from public, anon;
grant execute on function public.get_club_events(uuid) to authenticated;

-- Etkinliğe kimler geliyor (kartı açılabilsin diye profil alanlarıyla).
create or replace function public.get_club_event_attendees(event_id uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name, p.birth_date, p.university, p.department,
         p.academic_year, p.bio, p.avatar_path, p.is_verified, p.badge
    from public.club_event_attendees a
    join public.club_events e on e.id = a.event_id and e.cancelled_at is null
    join public.clubs c on c.id = e.club_id and c.is_active
    join public.profiles p on p.id = a.user_id and p.is_active
   where a.event_id = get_club_event_attendees.event_id
     and auth.uid() is not null
     and not exists (select 1 from public.blocks b
                      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
                         or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
   order by a.created_at
   limit 500;
$$;
revoke all on function public.get_club_event_attendees(uuid) from public, anon;
grant execute on function public.get_club_event_attendees(uuid) to authenticated;

-- Hatırlatmalar için: katıldığım, henüz başlamamış etkinlikler.
create or replace function public.get_my_club_events()
returns table (
  id uuid, club_id uuid, club_name text, title text, starts_at timestamptz,
  place_name text, place_note text
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, c.id, c.name, e.title, e.starts_at, pl.name, e.place_note
    from public.club_event_attendees a
    join public.club_events e on e.id = a.event_id and e.cancelled_at is null
    join public.clubs c on c.id = e.club_id and c.is_active
    left join public.places pl on pl.id = e.place_id
   where a.user_id = auth.uid()
     and e.starts_at > now()
   order by e.starts_at
   limit 50;
$$;
revoke all on function public.get_my_club_events() from public, anon;
grant execute on function public.get_my_club_events() to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261016010000', 'club_events')
on conflict (version) do nothing;

commit;
