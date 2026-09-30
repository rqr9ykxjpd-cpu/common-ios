-- Destek talepleri: "Sorun bildir" iki yönlü oluyor (1.1).
--
-- Önceden tek yönlüydü: öğrenci yazıyor, kurucu okuyup "çözüldü" diye
-- kapatıyordu; öğrenci bundan hiç haberdar olmuyordu. Şimdi her bildirim
-- küçük bir yazışma: kurucu ya da moderatör yanıtlar, isterse "çözüldü"
-- işaretler; öğrenciye bildirim ve push gider, öğrenci de yanıtlayabilir.
--
-- Durum: open (öğrenci bekliyor) → answered (destek yanıtladı) → resolved.
-- Öğrenci yazınca talep yeniden open olur. handled_at eski anlamını koruyor:
-- çözüldüğü an (1.1'in ilk derlemeleri isOpen'ı ona bakarak hesaplıyor).
--
-- Kurucu panelinde iki ek: bir hesabı öğrenci doğrulamasından muaf tutma
-- ve kullanıcı listesinde doğrulama durumu.
--
-- Tablolara doğrudan erişim yok; hepsi aşağıdaki fonksiyonlarla. Yayındaki
-- 1.0 (5) bu fonksiyonların hiçbirini çağırmıyor, etkilenmiyor.

alter type public.notification_kind add value if not exists 'support';

begin;

alter table public.problem_reports
  add column if not exists status text not null default 'open',
  add column if not exists last_message_at timestamptz,
  add column if not exists reporter_read_at timestamptz,
  add column if not exists staff_read_at timestamptz;

alter table public.problem_reports drop constraint if exists problem_reports_status_check;
alter table public.problem_reports add constraint problem_reports_status_check
  check (status in ('open', 'answered', 'resolved'));

update public.problem_reports set status = 'resolved' where handled_at is not null and status <> 'resolved';
update public.problem_reports set last_message_at = created_at where last_message_at is null;

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.problem_reports (id) on delete cascade,
  sender_id uuid references auth.users (id) on delete set null,
  from_staff boolean not null,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists support_messages_report_idx
  on public.support_messages (report_id, created_at);

alter table public.support_messages enable row level security;
revoke all on public.support_messages from anon, authenticated;

-- Öğrencinin kendi talepleri: en son hareket eden üstte.
create or replace function public.get_my_support_threads()
returns table (
  id uuid,
  message text,
  screen text,
  status text,
  created_at timestamptz,
  last_message_at timestamptz,
  has_unread boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.message, r.context ->> 'screen', r.status, r.created_at,
         coalesce(r.last_message_at, r.created_at),
         exists (
           select 1 from public.support_messages m
            where m.report_id = r.id and m.from_staff
              and m.created_at > coalesce(r.reporter_read_at, '-infinity'::timestamptz)
         )
    from public.problem_reports r
   where r.reporter_id = auth.uid()
   order by coalesce(r.last_message_at, r.created_at) desc
   limit 50;
$$;
revoke all on function public.get_my_support_threads() from public, anon;
grant execute on function public.get_my_support_threads() to authenticated;

-- Yazışma. Talebin sahibi ya da kurucu/moderatör okuyabilir; okuyan tarafın
-- "okundu" zamanı güncellenir.
create or replace function public.get_support_messages(report_id uuid)
returns table (id uuid, from_staff boolean, body text, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  sahip uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select r.reporter_id into sahip from public.problem_reports r where r.id = get_support_messages.report_id;
  if not found then raise exception 'SUPPORT_NOT_FOUND'; end if;
  if sahip is distinct from auth.uid() and not public.is_moderator() then
    raise exception 'SUPPORT_NOT_ALLOWED';
  end if;

  if sahip = auth.uid() then
    update public.problem_reports r set reporter_read_at = now() where r.id = get_support_messages.report_id;
  else
    update public.problem_reports r set staff_read_at = now() where r.id = get_support_messages.report_id;
  end if;

  return query
    select m.id, m.from_staff, m.body, m.created_at
      from public.support_messages m
     where m.report_id = get_support_messages.report_id
     order by m.created_at;
end;
$$;
revoke all on function public.get_support_messages(uuid) from public, anon;
grant execute on function public.get_support_messages(uuid) to authenticated;

-- Yanıt. Destek yazarsa talep "answered" (resolve ise "resolved") olur ve
-- öğrenciye bildirim gider (push, bildirim tetikleyicisiyle). Öğrenci yazarsa
-- talep yeniden "open" olur. Çözüldü işaretlerken yazı isteğe bağlı.
create or replace function public.send_support_message(report_id uuid, body text, resolve boolean default false)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  sahip uuid;
  destek boolean;
  metin text := btrim(coalesce(body, ''));
  yeni_durum text;
  son_saat integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select r.reporter_id into sahip from public.problem_reports r where r.id = send_support_message.report_id;
  if not found then raise exception 'SUPPORT_NOT_FOUND'; end if;

  destek := public.is_moderator();
  if not destek and sahip is distinct from auth.uid() then raise exception 'SUPPORT_NOT_ALLOWED'; end if;
  if char_length(metin) > 2000 then metin := left(metin, 2000); end if;
  if metin = '' and not (destek and resolve) then raise exception 'SUPPORT_EMPTY'; end if;

  if not destek then
    select count(*) into son_saat
      from public.support_messages m
     where m.sender_id = auth.uid() and m.created_at > now() - interval '1 hour';
    if son_saat >= 20 then raise exception 'PROBLEM_REPORT_RATE_LIMIT'; end if;
  end if;

  if metin <> '' then
    insert into public.support_messages (report_id, sender_id, from_staff, body)
    values (send_support_message.report_id, auth.uid(), destek, metin);
  end if;

  if destek then
    yeni_durum := case when resolve then 'resolved' else 'answered' end;
    update public.problem_reports r
       set status = yeni_durum,
           last_message_at = now(),
           staff_read_at = now(),
           handled_at = case when resolve then now() else null end,
           handled_by = case when resolve then auth.uid() else r.handled_by end
     where r.id = send_support_message.report_id;

    -- Kayıt adımında yazan öğrencinin henüz profili olmayabilir; bildirim
    -- profil ister.
    if exists (select 1 from public.profiles p where p.id = sahip) then
      insert into public.notifications (user_id, kind, title, body)
      values (
        sahip,
        'support',
        case when resolve then 'Destek talebin çözüldü' else 'Destek ekibi yanıtladı' end,
        left(case when metin = '' then 'Talebin çözüldü olarak işaretlendi.' else metin end, 180)
      );
    end if;
  else
    yeni_durum := 'open';
    update public.problem_reports r
       set status = 'open', last_message_at = now(), reporter_read_at = now(), handled_at = null
     where r.id = send_support_message.report_id;
  end if;

  return yeni_durum;
end;
$$;
revoke all on function public.send_support_message(uuid, text, boolean) from public, anon;
grant execute on function public.send_support_message(uuid, text, boolean) to authenticated;

-- Kurucu listesi: durum ve son hareket de geliyor. Dönüş tipi değiştiği için
-- önce kaldırılıyor.
drop function if exists public.list_problem_reports();
create function public.list_problem_reports()
returns table (
  id uuid,
  message text,
  context jsonb,
  created_at timestamptz,
  handled_at timestamptz,
  reporter_id uuid,
  reporter_name text,
  reporter_username text,
  status text,
  last_message_at timestamptz,
  reply_count integer,
  staff_unread boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.message, r.context, r.created_at, r.handled_at,
         r.reporter_id, p.name, p.username, r.status,
         coalesce(r.last_message_at, r.created_at),
         (select count(*)::integer from public.support_messages m where m.report_id = r.id),
         r.status = 'open' and coalesce(r.last_message_at, r.created_at) > coalesce(r.staff_read_at, '-infinity'::timestamptz)
    from public.problem_reports r
    left join public.profiles p on p.id = r.reporter_id
   where public.is_moderator()
   order by (r.status = 'resolved'), coalesce(r.last_message_at, r.created_at) desc
   limit 200;
$$;
revoke all on function public.list_problem_reports() from public, anon;
grant execute on function public.list_problem_reports() to authenticated;

-- "Çözüldü olarak kapat" (yazmadan): durum da çözüldü olsun.
create or replace function public.close_problem_report(report_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_moderator() then raise exception 'Moderator only'; end if;
  update public.problem_reports
     set handled_at = now(), handled_by = auth.uid(), status = 'resolved'
   where id = report_id and handled_at is null;
end;
$$;
revoke all on function public.close_problem_report(uuid) from public, anon;
grant execute on function public.close_problem_report(uuid) to authenticated;

-- Kurucu: bir hesabı öğrenci doğrulamasından muaf tut / muafiyeti kaldır.
create or replace function public.founder_set_edu_exempt(target uuid, exempt boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare yeni boolean;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.profiles set edu_exempt = coalesce(exempt, false)
   where id = target
   returning edu_exempt into yeni;
  if yeni is null then raise exception 'Profile not found'; end if;
  return yeni;
end;
$$;
revoke all on function public.founder_set_edu_exempt(uuid, boolean) from public, anon;
grant execute on function public.founder_set_edu_exempt(uuid, boolean) to authenticated;

-- Kullanıcı listesi: doğrulama durumu da geliyor. Dönüş tipi değiştiği için
-- önce kaldırılıyor; gövde 20260914190000 ile aynı.
drop function if exists public.get_founder_users(text, integer);
create function public.get_founder_users(search text default '', lim integer default 50)
returns table (
  id uuid, name text, department text, academic_year text, avatar_path text,
  badge text, is_verified boolean, is_active boolean, plan text,
  created_at timestamptz, last_active_at timestamptz,
  edu_exempt boolean, edu_verified boolean
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select p.id, p.name, p.department, p.academic_year, p.avatar_path,
           p.badge::text, p.is_verified, p.is_active, public.plan_of(p.id),
           p.created_at, p.last_active_at,
           p.edu_exempt, p.edu_verified_at is not null
    from public.profiles p
    where search = '' or p.name ilike '%' || search || '%' or p.department ilike '%' || search || '%'
    order by p.last_active_at desc
    limit greatest(1, least(lim, 200));
end;
$$;
revoke all on function public.get_founder_users(text, integer) from public, anon;
grant execute on function public.get_founder_users(text, integer) to authenticated;

commit;
