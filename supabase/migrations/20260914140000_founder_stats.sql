-- Kurucuya özel "Veriler": kaç kullanıcı, kaç Plus/Pro, akış ve etkileşim
-- sayıları. Tek RPC, yalnız kurucu; sayılar anlık hesaplanır (kampüs
-- ölçeğinde count(*) ucuz). Plus/Pro sayımı my_plan ile aynı kural:
-- süresi geçmemiş abonelik satırı.
begin;

create or replace function public.get_founder_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare sonuc jsonb;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  select jsonb_build_object(
    'users_total',    (select count(*) from public.profiles),
    'users_verified', (select count(*) from public.profiles where is_verified),
    'users_today',    (select count(*) from public.profiles where created_at > now() - interval '24 hours'),
    'users_week',     (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'active_today',   (select count(*) from public.profiles where last_active_at > now() - interval '24 hours'),
    'active_week',    (select count(*) from public.profiles where last_active_at > now() - interval '7 days'),
    'plus',           (select count(*) from public.subscriptions where plan = 'plus' and (expires_at is null or expires_at > now())),
    'pro',            (select count(*) from public.subscriptions where plan = 'pro'  and (expires_at is null or expires_at > now())),
    'posts_total',    (select count(*) from public.posts),
    'posts_today',    (select count(*) from public.posts where created_at > now() - interval '24 hours'),
    'comments_total', (select count(*) from public.comments),
    'votes_total',    (select count(*) from public.post_likes) + (select count(*) from public.comment_votes),
    'stories_active', (select count(*) from public.stories where expires_at > now()),
    'right_swipes',   (select count(*) from public.profile_right_swipes),
    'left_swipes',    (select count(*) from public.profile_left_swipes),
    'matches',        (select count(*) from public.matches),
    'messages_total', (select count(*) from public.messages),
    'present_now',    (select count(*) from public.profiles where visible_place_id is not null and visible_until > now()),
    'reports_open',   (select count(*) from public.reports where handled_at is null)
  ) into sonuc;
  return sonuc;
end;
$$;
revoke all on function public.get_founder_stats() from public, anon;
grant execute on function public.get_founder_stats() to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914140000', 'founder_stats') on conflict (version) do nothing;

commit;
