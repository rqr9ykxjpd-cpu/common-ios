-- Kurucu paneli 2: kullanıcı listesi ve işlemleri, son 7 gün, duyuru geçmişi.
-- Hepsi is_founder() kapısının arkasında; kurucu olmayan çağırırsa hata alır.
begin;

-- Arama + liste. plan_of ile aynı kural (rozetliler Pro).
create or replace function public.get_founder_users(search text default '', lim integer default 50)
returns table (
  id uuid, name text, department text, academic_year text, avatar_path text,
  badge text, is_verified boolean, is_active boolean, plan text,
  created_at timestamptz, last_active_at timestamptz
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select p.id, p.name, p.department, p.academic_year, p.avatar_path,
           p.badge::text, p.is_verified, p.is_active, public.plan_of(p.id),
           p.created_at, p.last_active_at
    from public.profiles p
    where search = '' or p.name ilike '%' || search || '%' or p.department ilike '%' || search || '%'
    order by p.last_active_at desc
    limit greatest(1, least(lim, 200));
end;
$$;
revoke all on function public.get_founder_users(text, integer) from public, anon;
grant execute on function public.get_founder_users(text, integer) to authenticated;

-- Plan hediye: days null = süresiz; 'free' = hediyeyi kaldır.
-- Apple'a bağlı bir abonelik satırı varsa (original_transaction_id dolu) dokunmaz.
create or replace function public.founder_grant_plan(target uuid, new_plan text, days integer default null)
returns text language plpgsql security definer set search_path = '' as $$
declare bitis timestamptz;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if new_plan not in ('free', 'plus', 'pro') then raise exception 'Invalid plan'; end if;
  if exists (select 1 from public.subscriptions where user_id = target and original_transaction_id is not null) then
    raise exception 'PAID_SUBSCRIPTION';
  end if;
  bitis := case when days is null then null else now() + make_interval(days => days) end;
  perform public.set_plan(target, new_plan, null, 'founder_gift', bitis);
  return public.plan_of(target);
end;
$$;
revoke all on function public.founder_grant_plan(uuid, text, integer) from public, anon;
grant execute on function public.founder_grant_plan(uuid, text, integer) to authenticated;

-- Moderatör rozeti ver/al. Kurucu rozetine dokunulmaz.
create or replace function public.founder_set_moderator(target uuid, enabled boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare yeni text;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.profiles
     set badge = case when enabled then 'moderator'::public.profile_badge else 'none'::public.profile_badge end
   where id = target and badge <> 'founder'
   returning badge::text into yeni;
  if yeni is null then raise exception 'Profile not found'; end if;
  return yeni;
end;
$$;
revoke all on function public.founder_set_moderator(uuid, boolean) from public, anon;
grant execute on function public.founder_set_moderator(uuid, boolean) to authenticated;

-- Hesabı dondur/aç: is_active. Dondurulan kişi akışta, kişilerde, kampüste görünmez.
create or replace function public.founder_set_active(target uuid, active boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
declare yeni boolean;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if target = auth.uid() then raise exception 'SELF'; end if;
  update public.profiles set is_active = active where id = target returning is_active into yeni;
  if yeni is null then raise exception 'Profile not found'; end if;
  return yeni;
end;
$$;
revoke all on function public.founder_set_active(uuid, boolean) from public, anon;
grant execute on function public.founder_set_active(uuid, boolean) to authenticated;

-- Son 7 gün: günlük yeni kullanıcı, aktif, gönderi. Bugün dahil, eski→yeni.
create or replace function public.get_founder_daily(days integer default 7)
returns table (day date, new_users integer, active_users integer, posts integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select d::date,
      (select count(*)::integer from public.profiles p where p.created_at::date = d::date),
      (select count(*)::integer from public.profiles p where p.last_active_at::date = d::date),
      (select count(*)::integer from public.posts x where x.created_at::date = d::date)
    from generate_series(current_date - (greatest(1, least(days, 30)) - 1), current_date, interval '1 day') d
    order by d;
end;
$$;
revoke all on function public.get_founder_daily(integer) from public, anon;
grant execute on function public.get_founder_daily(integer) to authenticated;

-- Duyuru geçmişi: aynı başlık+gövde+dakika bir gönderim sayılır. Panel son 3ü ister.
create or replace function public.get_founder_announcements(lim integer default 10)
returns table (title text, body text, sent_at timestamptz, recipients integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select n.title, n.body, min(n.created_at), count(*)::integer
    from public.notifications n
    where n.kind = 'announcement'
    group by n.title, n.body, date_trunc('minute', n.created_at)
    order by 3 desc
    limit greatest(1, least(lim, 50));
end;
$$;
revoke all on function public.get_founder_announcements(integer) from public, anon;
grant execute on function public.get_founder_announcements(integer) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914190000', 'founder_panel_users') on conflict (version) do nothing;

commit;
