-- "Sorun bildir" (Build 6).
--
-- Kullanıcı uygulamada bir sorunla karşılaşınca profilinden ya da kayıt
-- adımlarından yazıyor; kurucu ve moderatörler Ayarlar → Şikâyetler →
-- Sorunlar'da okuyup kapatıyor. İçerik şikâyetlerinden (`reports`) ayrı:
-- orada bir kişi ya da içerik hedef alınıyor, burada uygulamanın kendisi.
--
-- Tabloya doğrudan erişim yok; yazma ve okuma yalnızca aşağıdaki
-- fonksiyonlarla. Mevcut hiçbir tabloya dokunmuyor, Build 5 etkilenmiyor.
begin;

create table if not exists public.problem_reports (
  id uuid primary key default gen_random_uuid(),
  -- Kayıt adımlarında profil henüz olmayabilir; bu yüzden hesap (auth.users).
  reporter_id uuid references auth.users (id) on delete set null,
  message text not null check (char_length(btrim(message)) between 3 and 2000),
  -- Sürüm, iOS, cihaz, ekran: sorunu yeniden üretebilmek için.
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references auth.users (id) on delete set null
);

create index if not exists problem_reports_open_idx
  on public.problem_reports (created_at desc) where handled_at is null;

alter table public.problem_reports enable row level security;
revoke all on public.problem_reports from anon, authenticated;

-- Sorun bildirir. Saatte en fazla 5 (yanlışlıkla art arda basma ve kötüye
-- kullanım için).
create or replace function public.report_problem(message text, context jsonb default '{}'::jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  hesap uuid := auth.uid();
  son_saat integer;
  yeni uuid;
begin
  if hesap is null then raise exception 'Authentication required'; end if;
  if char_length(btrim(coalesce(message, ''))) < 3 then raise exception 'PROBLEM_REPORT_TOO_SHORT'; end if;
  select count(*) into son_saat
    from public.problem_reports r
   where r.reporter_id = hesap and r.created_at > now() - interval '1 hour';
  if son_saat >= 5 then raise exception 'PROBLEM_REPORT_RATE_LIMIT'; end if;
  insert into public.problem_reports (reporter_id, message, context)
  values (hesap, left(btrim(message), 2000), coalesce(context, '{}'::jsonb))
  returning id into yeni;
  return yeni;
end;
$$;
revoke all on function public.report_problem(text, jsonb) from public, anon;
grant execute on function public.report_problem(text, jsonb) to authenticated;

-- Kurucu ve moderatörler için liste: açıklar önce, en yeni üstte.
create or replace function public.list_problem_reports()
returns table (
  id uuid,
  message text,
  context jsonb,
  created_at timestamptz,
  handled_at timestamptz,
  reporter_id uuid,
  reporter_name text,
  reporter_username text
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.message, r.context, r.created_at, r.handled_at,
         r.reporter_id, p.name, p.username
    from public.problem_reports r
    left join public.profiles p on p.id = r.reporter_id
   where public.is_moderator()
   order by (r.handled_at is not null), r.created_at desc
   limit 200;
$$;
revoke all on function public.list_problem_reports() from public, anon;
grant execute on function public.list_problem_reports() to authenticated;

create or replace function public.close_problem_report(report_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_moderator() then raise exception 'Moderator only'; end if;
  update public.problem_reports
     set handled_at = now(), handled_by = auth.uid()
   where id = report_id and handled_at is null;
end;
$$;
revoke all on function public.close_problem_report(uuid) from public, anon;
grant execute on function public.close_problem_report(uuid) to authenticated;

commit;
