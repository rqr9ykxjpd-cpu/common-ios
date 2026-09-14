-- Kurucu paneli:
-- - "ATATÜRK" rozeti kaldırıldı (görsel konmayacak).
-- - Bildirim türlerine 'announcement' eklendi: kurucunun herkese duyurusu.
-- - Canlı sayılar: online_now (son 5 dk), present_now zaten vardı.
-- - founder_broadcast(title, body, test_only): test_only=true ise yalnız
--   kurucuya, değilse aktif herkese bildirim satırı yazar; tetikleyici push'u
--   kendisi gönderir. Kaç kişiye yazıldığını döndürür.

alter type public.notification_kind add value if not exists 'announcement';

begin;

update public.posts set kind = 'moment' where kind = 'ataturk';
alter table public.posts drop constraint if exists posts_kind_check;
alter table public.posts add constraint posts_kind_check
  check (kind in (
    'moment',
    'question', 'announcement', 'notes', 'help', 'event', 'poll', 'agenda',
    'sports', 'music', 'film', 'games', 'food', 'art', 'literature', 'science',
    'nature', 'health', 'history', 'philosophy', 'culture',
    'photo', 'life_story', 'instant', 'serious', 'flood',
    'aga_beee', 'bele', 'ahraz'
  ));

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
    'online_now',     (select count(*) from public.profiles where last_active_at > now() - interval '5 minutes'),
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
    'reports_open',   (select count(*) from public.reports where handled_at is null),
    'push_devices',   (select count(distinct user_id) from public.device_tokens)
  ) into sonuc;
  return sonuc;
end;
$$;

create or replace function public.founder_broadcast(title text, body text, test_only boolean default false)
returns integer language plpgsql security definer set search_path = '' as $$
declare adet integer;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if char_length(btrim(title)) = 0 then raise exception 'EMPTY_TITLE'; end if;
  if test_only then
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (auth.uid(), 'announcement', btrim(title), btrim(body), auth.uid());
    return 1;
  end if;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  select p.id, 'announcement', btrim(title), btrim(body), auth.uid()
  from public.profiles p where p.is_active;
  get diagnostics adet = row_count;
  return adet;
end;
$$;
revoke all on function public.founder_broadcast(text, text, boolean) from public, anon;
grant execute on function public.founder_broadcast(text, text, boolean) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914170000', 'founder_panel') on conflict (version) do nothing;

commit;
