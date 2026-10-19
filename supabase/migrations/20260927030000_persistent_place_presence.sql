-- "Kim nerede" seçimi kullanıcı ayrılana veya başka bir yer seçene kadar sürer.
-- Eski istemciler `minutes` parametresini gönderebildiği için imza korunur;
-- parametre artık davranışı değiştirmez.

begin;

-- Süresi geçmiş eski seçimleri yeniden görünür yapma. Yalnızca migration anında
-- hâlâ etkin olan seçimleri kalıcı seçime dönüştür.
update public.profiles
set visible_place_id = null, visible_until = null
where visible_place_id is not null
  and visible_until is not null
  and visible_until <= now();

update public.profiles
set visible_until = null
where visible_place_id is not null;

create index if not exists profiles_visible_place_persistent_idx
  on public.profiles (visible_place_id)
  where visible_place_id is not null;

create or replace function public.set_visible_place(target_place uuid, minutes integer default 90)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  if target_place is null then
    update public.profiles
    set visible_place_id = null, visible_until = null
    where id = auth.uid();
    return;
  end if;

  if not exists (select 1 from public.places where id = target_place and is_active) then
    raise exception 'Unknown place';
  end if;

  update public.profiles
  set visible_place_id = target_place,
      visible_until = null,
      last_active_at = now()
  where id = auth.uid();
end;
$$;

revoke all on function public.set_visible_place(uuid, integer) from public, anon;
grant execute on function public.set_visible_place(uuid, integer) to authenticated;

create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    public.activity_label(p.last_active_at)
  from public.profiles p
  where p.visible_place_id = target_place
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not coalesce(p.ghost_mode, false)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

revoke all on function public.get_people_at_place(uuid) from public, anon;
grant execute on function public.get_people_at_place(uuid) to authenticated;

create or replace function public.get_place_presence()
returns table (place_id uuid, people_count integer, avatar_paths text[])
language sql stable security definer set search_path = '' as $$
  with gorunen as (
    select p.visible_place_id as place_id, p.id, p.avatar_path, p.last_active_at
    from public.profiles p
    where auth.uid() is not null
      and p.visible_place_id is not null
      and p.is_verified and p.is_active
      and not coalesce(p.ghost_mode, false)
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = auth.uid())
      )
  )
  select g.place_id,
         count(*)::integer,
         (array_agg(g.avatar_path order by g.last_active_at desc) filter (where g.avatar_path is not null))[1:3]
  from gorunen g
  group by g.place_id;
$$;

revoke all on function public.get_place_presence() from public, anon;
grant execute on function public.get_place_presence() to authenticated;

create or replace function public.get_campus_people(
  page_limit integer default 20,
  page_offset integer default 0
)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge, interests text[], visible_place_id uuid,
  visible_place_name text
)
language sql stable security definer set search_path = '' as $$
  select
    p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge,
    coalesce((
      select array_agg(pi.interest order by pi.interest)
      from public.profile_interests pi
      where pi.profile_id = p.id
    ), '{}'::text[]),
    p.visible_place_id,
    pl.name
  from public.profiles p
  left join public.places pl on pl.id = p.visible_place_id
  where p.id is distinct from auth.uid()
    and p.is_active
    and p.is_verified
    and not coalesce(p.ghost_mode, false)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc nulls last, p.name
  limit greatest(1, least(coalesce(page_limit, 20), 50))
  offset greatest(0, coalesce(page_offset, 0));
$$;

-- App Store 4.3(b) nedeniyle dizin RPC'si daha önce istemcilere kapatıldı.
-- Fonksiyonu uyumluluk için güncelle ama bu güvenlik/ürün kararını geri alma.
revoke all on function public.get_campus_people(integer, integer)
from public, anon, authenticated;

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
    'pro',            (select count(*) from public.subscriptions where plan = 'pro' and (expires_at is null or expires_at > now())),
    'posts_total',    (select count(*) from public.posts),
    'posts_today',    (select count(*) from public.posts where created_at > now() - interval '24 hours'),
    'comments_total', (select count(*) from public.comments),
    'votes_total',    (select count(*) from public.post_likes) + (select count(*) from public.comment_votes),
    'stories_active', (select count(*) from public.stories where expires_at > now()),
    'right_swipes',   (select count(*) from public.profile_right_swipes),
    'left_swipes',    (select count(*) from public.profile_left_swipes),
    'matches',        (select count(*) from public.matches),
    'messages_total', (select count(*) from public.messages),
    'present_now',    (select count(*) from public.profiles where visible_place_id is not null),
    'reports_open',   (select count(*) from public.reports where handled_at is null),
    'push_devices',   (select count(distinct user_id) from public.device_tokens)
  ) into sonuc;
  return sonuc;
end;
$$;

revoke all on function public.get_founder_stats() from public, anon;
grant execute on function public.get_founder_stats() to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20260927030000', 'persistent_place_presence')
on conflict (version) do nothing;

commit;
