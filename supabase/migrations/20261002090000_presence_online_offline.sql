-- Çevrimiçi göstergesi gecikmesin.
--
-- Önceden: uygulama 2,5 dakikada bir "buradayım" diyor, sunucu bunu en fazla
-- 5 dakikada bir yazıyordu; panel de son 8 dakikayı "çevrimiçi" sayıyordu.
-- Uygulamadan çıkan biri 8 dakika daha yeşil görünüyordu.
--
-- Şimdi: her "buradayım" anında `online_at`'e yazılır (son aktif yine 5
-- dakikalık kısıtla). Uygulama arka plana geçerken `mark_offline` çağırır;
-- çevrimiçi = son 3 dakikada "buradayım" ve sonrasında "ayrıldım" yok.
-- Telefon kapanır ya da uygulama zorla kapatılırsa en geç 3 dakikada düşer.
-- Eski sürümler `mark_offline` çağırmaz; onlarda da 3 dakika.
begin;

alter table public.profiles add column if not exists online_at timestamptz;
alter table public.profiles add column if not exists offline_at timestamptz;

create or replace function public.touch_last_active()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  update public.profiles
  set online_at = now(),
      last_active_at = case
        when last_active_at < now() - interval '5 minutes' then now()
        else last_active_at
      end
  where id = auth.uid();
end;
$$;
revoke all on function public.touch_last_active() from public, anon;
grant execute on function public.touch_last_active() to authenticated;

create or replace function public.mark_offline()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  update public.profiles
  set offline_at = now(), last_active_at = now()
  where id = auth.uid();
end;
$$;
revoke all on function public.mark_offline() from public, anon;
grant execute on function public.mark_offline() to authenticated;

-- Dönüş tipine kolon ekleniyor: önce kaldır. 1.1 istemcisi fazla kolonu yok sayar.
drop function if exists public.get_founder_users(text, integer);
create function public.get_founder_users(search text default '', lim integer default 50)
returns table (
  id uuid, name text, department text, academic_year text, avatar_path text,
  badge text, is_verified boolean, is_active boolean, plan text,
  created_at timestamptz, last_active_at timestamptz,
  edu_exempt boolean, edu_verified boolean, has_push boolean,
  is_online boolean
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    with liste as (
      select p.*,
             coalesce(p.is_active
               and p.online_at > now() - interval '3 minutes'
               and (p.offline_at is null or p.offline_at < p.online_at), false) as cevrimici
      from public.profiles p
      where search = '' or p.name ilike '%' || search || '%' or p.department ilike '%' || search || '%'
    )
    select l.id, l.name, l.department, l.academic_year, l.avatar_path,
           l.badge::text, l.is_verified, l.is_active, public.plan_of(l.id),
           l.created_at, l.last_active_at,
           l.edu_exempt, l.edu_verified_at is not null,
           exists (select 1 from public.device_tokens d where d.user_id = l.id),
           l.cevrimici
    from liste l
    order by l.cevrimici desc, l.last_active_at desc
    limit greatest(1, least(lim, 200));
end;
$$;
revoke all on function public.get_founder_users(text, integer) from public, anon;
grant execute on function public.get_founder_users(text, integer) to authenticated;

-- Paneldeki "Şu an çevrimiçi" sayısı da aynı kural (önceden son 5 dakika).
create or replace function public.get_founder_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare sonuc jsonb;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  select jsonb_build_object(
    'users_total', (select count(*) from public.profiles),
    'users_verified', (select count(*) from public.profiles where is_verified),
    'users_today', (select count(*) from public.profiles where created_at > now() - interval '24 hours'),
    'users_week', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'online_now', (select count(*) from public.profiles
                   where is_active and online_at > now() - interval '3 minutes'
                     and (offline_at is null or offline_at < online_at)),
    'active_today', (select count(*) from public.profiles where last_active_at > now() - interval '24 hours'),
    'active_week', (select count(*) from public.profiles where last_active_at > now() - interval '7 days'),
    'plus', (select count(*) from public.subscriptions where plan = 'plus' and (expires_at is null or expires_at > now())),
    'pro', (select count(*) from public.subscriptions where plan = 'pro' and (expires_at is null or expires_at > now())),
    'posts_total', (select count(*) from public.posts),
    'posts_today', (select count(*) from public.posts where created_at > now() - interval '24 hours'),
    'comments_total', (select count(*) from public.comments),
    'votes_total', (select count(*) from public.post_likes) + (select count(*) from public.comment_votes),
    'stories_active', (select count(*) from public.stories where expires_at > now()),
    'right_swipes', (select count(*) from public.profile_right_swipes),
    'left_swipes', (select count(*) from public.profile_left_swipes),
    'matches', (select count(*) from public.matches),
    'messages_total', (select count(*) from public.messages),
    'present_now', (select count(*) from public.profiles where visible_place_id is not null and visible_until > now()),
    'reports_open', (select count(*) from public.reports where handled_at is null),
    'push_devices', (select count(distinct user_id) from public.device_tokens)
  ) into sonuc;
  return sonuc;
end;
$$;
revoke all on function public.get_founder_stats() from public, anon;
grant execute on function public.get_founder_stats() to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261002090000', 'presence_online_offline')
on conflict (version) do nothing;

commit;
