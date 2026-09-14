-- Kurucu grafiği: günlük bağlantı (karşılıklı eşleşme) sayısı da geliyor;
-- 30 gün + karşılaştırma için 60 güne kadar istenebiliyor.
begin;

drop function if exists public.get_founder_daily(integer);
create or replace function public.get_founder_daily(days integer default 7)
returns table (day date, new_users integer, active_users integer, posts integer, matches integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select d::date,
      (select count(*)::integer from public.profiles p where p.created_at::date = d::date),
      (select count(*)::integer from public.profiles p where p.last_active_at::date = d::date),
      (select count(*)::integer from public.posts x where x.created_at::date = d::date),
      (select count(*)::integer from public.matches m where m.created_at::date = d::date)
    from generate_series(current_date - (greatest(1, least(days, 60)) - 1), current_date, interval '1 day') d
    order by d;
end;
$$;
revoke all on function public.get_founder_daily(integer) from public, anon;
grant execute on function public.get_founder_daily(integer) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260915010000', 'founder_daily_matches') on conflict (version) do nothing;

commit;
