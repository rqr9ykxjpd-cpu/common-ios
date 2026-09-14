-- Kaydırmalar görünmez: kimin kimi sağa/sola kaydırdığını kimse görmez.
-- Yalnızca karşılıklı sağa kaydırma bağlantı kurar (bildirim + sohbet zaten
-- notify_on_match ve swipe_right_on_profile'da). Tek istisna: kurucu kendi
-- kartını kimin sağa/sola kaydırdığını görür (`who_swiped_me`).
-- - Tanışma isteği kutusu boş döner (adlı tek yönlü istek yok).
-- - Tek yönlü sağa kaydırma bildirimi yalnızca kurucuya, adlı.
-- - Sola kaydırma artık kaydedilir (`profile_left_swipes`), sadece kurucu okur.

begin;

-- ------------------------------------------------------ sola kaydırmalar
create table if not exists public.profile_left_swipes (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (actor_id, subject_id),
  constraint profile_left_swipes_not_self check (actor_id <> subject_id)
);
alter table public.profile_left_swipes enable row level security;
-- Doğrudan okuma yok; yazma yalnızca RPC ile (security definer).
revoke all on public.profile_left_swipes from anon, authenticated;

create or replace function public.swipe_left_on_profile(subject uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'Authentication required'; end if;
  if subject = actor then return; end if;
  insert into public.profile_left_swipes (actor_id, subject_id)
  values (actor, subject)
  on conflict (actor_id, subject_id) do update set created_at = now();
end;
$$;
revoke all on function public.swipe_left_on_profile(uuid) from public, anon;
grant execute on function public.swipe_left_on_profile(uuid) to authenticated;

-- ------------------------------------------ tanışma kutusu: artık adsız/yok
create or replace function public.get_introduction_requests()
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department,
         p.academic_year, p.bio, p.avatar_path, p.is_verified, p.badge
  from public.profiles p
  where false;
$$;

-- --------------------------------------- tek yönlü bildirim: sadece kurucuya
create or replace function public.notify_on_profile_right_swipe()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Karşılıklıysa notify_on_match zaten iki tarafa "Yeni bağlantı" yazar.
  if exists (select 1 from public.profile_right_swipes s
             where s.actor_id = new.subject_id and s.subject_id = new.actor_id) then
    return new;
  end if;
  if exists (select 1 from public.profiles p where p.id = new.subject_id and p.badge = 'founder') then
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (new.subject_id, 'like', 'Sizi biri sağa kaydırdı',
            public.profile_display_name(new.actor_id) || ' kartını sağa kaydırdı.', new.actor_id);
  end if;
  return new;
end;
$$;

-- Eski adlı/adsız tek yönlü bildirimleri kurucu dışındakilerden temizle.
delete from public.notifications n
using public.profiles p
where n.user_id = p.id and p.badge is distinct from 'founder'
  and n.kind = 'like' and n.match_id is null and n.post_id is null;

-- ------------------------------------------------- kurucu: beni kaydıranlar
create or replace function public.who_swiped_me()
returns table (id uuid, name text, avatar_path text, direction text, swiped_at timestamptz, is_matched boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select p.id, p.name, p.avatar_path, x.direction, x.swiped_at,
      exists (select 1 from public.matches m
              where m.user_a = least(p.id, auth.uid()) and m.user_b = greatest(p.id, auth.uid())
                and m.unmatched_at is null)
    from (
      select r.actor_id, 'right'::text as direction, r.created_at as swiped_at
      from public.profile_right_swipes r where r.subject_id = auth.uid()
      union all
      select l.actor_id, 'left'::text, l.created_at
      from public.profile_left_swipes l where l.subject_id = auth.uid()
    ) x
    join public.profiles p on p.id = x.actor_id
    order by x.swiped_at desc;
end;
$$;
revoke all on function public.who_swiped_me() from public, anon;
grant execute on function public.who_swiped_me() to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914110000', 'hidden_swipes_founder_view') on conflict (version) do nothing;

commit;
