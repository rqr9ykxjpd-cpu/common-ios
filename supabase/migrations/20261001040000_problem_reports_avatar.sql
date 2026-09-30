-- Kurucu Sorunlar listesi: şikâyetçinin profil fotoğrafı (1.1).
--
-- Liste ve destek yazışması kimin yazdığını fotoğrafla gösteriyor. Dönüş tipi
-- değiştiği için fonksiyon önce kaldırılıyor; gövde 20261001010000 ile aynı,
-- yalnız reporter_avatar_path eklendi. Fotoğrafın kendisi mevcut depolama
-- kuralıyla imzalanıyor (kurucu/moderatör zaten okuyabiliyor).
begin;

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
  staff_unread boolean,
  reporter_avatar_path text
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
         r.status = 'open' and coalesce(r.last_message_at, r.created_at) > coalesce(r.staff_read_at, '-infinity'::timestamptz),
         p.avatar_path
    from public.problem_reports r
    left join public.profiles p on p.id = r.reporter_id
   where public.is_moderator()
   order by (r.status = 'resolved'), coalesce(r.last_message_at, r.created_at) desc
   limit 200;
$$;
revoke all on function public.list_problem_reports() from public, anon;
grant execute on function public.list_problem_reports() to authenticated;

commit;
