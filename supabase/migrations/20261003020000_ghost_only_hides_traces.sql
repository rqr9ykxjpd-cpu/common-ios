-- Hayalet mod yalnızca iz bırakmamak: profil ziyaretlerinde ve story
-- izleyenlerde görünmezsin. Başka hiçbir yerden gizlemez (kurucunun kararı).
--
-- Önceden hayalet kişi önerilerden, Kim nerede'den (sayı, yüzler, yerdeki
-- kişi listesi, anlık güncelleme) ve kampüs listesinden de çıkıyordu. Kim
-- nerede'de görünmek zaten kişinin kendi seçimi ("Buradayım"). Ziyaret ve
-- story izi (record_profile_visit, skip_ghost_story_view) olduğu gibi kalıyor.
begin;

create or replace function public.get_people_you_may_know(max_count integer default 12)
returns table (
  id uuid,
  name text,
  birth_date date,
  university text,
  department text,
  academic_year text,
  bio text,
  avatar_path text,
  is_verified boolean,
  badge public.profile_badge,
  interests text[],
  reason text,
  reason_detail text,
  reason_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select p.id, p.university, p.department, p.academic_year
    from public.profiles p
    where p.id = auth.uid() and p.is_active
  ),
  my_connections as (
    select case when m.user_a = me.id then m.user_b else m.user_a end as other
    from public.matches m, me
    where (m.user_a = me.id or m.user_b = me.id) and m.unmatched_at is null
  ),
  -- Sohbeti temizlenmiş ama bağlantısı süren kişiler: temizlikten sonra
  -- iki taraftan da mesaj yoksa öneride en başta durur (kart açılıp yazılsın).
  cleared_peers as (
    select case when m.user_a = me.id then m.user_b else m.user_a end as other
    from public.conversation_clears cc
    join public.matches m on m.id = cc.match_id
    cross join me
    where cc.user_id = me.id
      and m.unmatched_at is null
      and (m.user_a = me.id or m.user_b = me.id)
      and not exists (
        select 1 from public.messages x
        where x.match_id = m.id and x.created_at > cc.cleared_at
      )
  ),
  my_clubs as (
    select cm.club_id from public.club_members cm, me where cm.user_id = me.id
  ),
  my_interests as (
    select pi.interest from public.profile_interests pi, me where pi.profile_id = me.id
  ),
  candidates as (
    select
      p.*,
      (
        select count(*)::integer
        from public.matches m2
        join my_connections c on c.other = case when m2.user_a = p.id then m2.user_b else m2.user_a end
        where (m2.user_a = p.id or m2.user_b = p.id) and m2.unmatched_at is null
      ) as mutuals,
      (
        select count(*)::integer
        from public.club_members cm join my_clubs mc on mc.club_id = cm.club_id
        where cm.user_id = p.id
      ) as shared_clubs,
      (
        select c.name
        from public.club_members cm
        join my_clubs mc on mc.club_id = cm.club_id
        join public.clubs c on c.id = cm.club_id and c.is_active
        where cm.user_id = p.id
        order by c.name
        limit 1
      ) as club_name,
      (
        select count(*)::integer
        from public.profile_interests pi join my_interests mi on mi.interest = pi.interest
        where pi.profile_id = p.id
      ) as shared_interests,
      (btrim(p.department) <> '' and p.department = me.department) as same_department,
      (btrim(p.department) <> '' and p.department = me.department
        and btrim(p.academic_year) <> '' and p.academic_year = me.academic_year) as same_year,
      (p.created_at > now() - interval '30 days') as is_new,
      (p.created_at > now() - interval '7 days') as is_fresh,
      exists (select 1 from cleared_peers cp where cp.other = p.id) as is_cleared
    from public.profiles p, me
    where p.id <> me.id
      and p.is_active
      and p.is_verified
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = me.id and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = me.id)
      )
      and not exists (
        select 1 from public.suggestion_dismissals d where d.user_id = me.id and d.profile_id = p.id
      )
      and (
        -- Kendi bağlantın: keşif kuralları (kaydırma, test hesabı) uygulanmaz.
        exists (select 1 from cleared_peers cp where cp.other = p.id)
        or (
          not p.is_test_account
          and p.university = me.university
          and not exists (select 1 from my_connections c where c.other = p.id)
          and not exists (
            select 1 from public.profile_right_swipes s where s.actor_id = me.id and s.subject_id = p.id
          )
          and not exists (
            select 1 from public.profile_left_swipes s where s.actor_id = me.id and s.subject_id = p.id
          )
        )
      )
  ),
  scored as (
    select
      c.*,
      -- En güçlü ortak nokta kartın altında yazan sebep.
      case
        -- Yalnızca 1.1.1 sohbet temizleyebildiği için eski istemci bu sebebi görmez.
        when c.is_cleared then 'connection'
        when c.mutuals > 0 then 'mutual'
        when c.club_name is not null then 'club'
        when c.same_year then 'classmate'
        when c.same_department then 'department'
        when c.shared_interests >= 2 then 'interests'
        -- Ortak nokta şart değil: kampüsteki herkes, yeniden eskiye. Altında
        -- kendi bölümü yazar ('department' bilinçli: 1.1 tanımadığı sebebi gizliyor).
        when btrim(c.department) <> '' then 'department'
      end as reason,
      case
        when c.is_cleared then null
        when c.mutuals > 0 then null
        when c.club_name is not null then c.club_name
        when c.same_year or c.same_department then c.department
        when c.shared_interests >= 2 then null
        else c.department
      end as reason_detail,
      case
        when c.is_cleared then 0
        when c.mutuals > 0 then c.mutuals
        when c.club_name is null and not c.same_year and not c.same_department then c.shared_interests
        else 0
      end as reason_count,
      c.mutuals * 4
        + c.shared_clubs * 3
        + (case when c.same_year then 3 else 0 end)
        + (case when c.same_department then 2 else 0 end)
        + least(c.shared_interests, 5)
        -- Yeni gelen öne çıksın: ilk hafta güçlü, ilk ay hafif.
        + (case when c.is_fresh then 5 when c.is_new then 2 else 0 end) as score
    from candidates c
  )
  select
    s.id,
    s.name,
    s.birth_date,
    s.university,
    s.department,
    s.academic_year,
    s.bio,
    s.avatar_path,
    s.is_verified,
    s.badge,
    coalesce((
      select array_agg(pi.interest order by pi.interest)
      from public.profile_interests pi
      where pi.profile_id = s.id
    ), '{}'::text[]),
    s.reason,
    s.reason_detail,
    s.reason_count
  from scored s
  where s.reason is not null
  -- En son katılan en önde (kurucunun isteği); eşitlikte ortak nokta gücü.
  order by s.is_cleared desc, s.created_at desc, s.score desc, s.id
  limit greatest(1, least(coalesce(max_count, 12), 20));
$$;

-- Bu iki fonksiyon canlıdaki tanımlarından alındı (görünürlük süresi
-- kontrolüyle). 20260927030000_persistent_place_presence canlıya hiç
-- uygulanmadı; onun sürümü kullanılmadı.
create or replace function public.get_campus_people(page_limit integer default 20, page_offset integer default 0)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge, interests text[], visible_place_id uuid,
  visible_place_name text
)
language sql stable security definer set search_path = '' as $$
  select
    p.id,
    p.name,
    p.birth_date,
    p.university,
    p.department,
    p.academic_year,
    p.bio,
    p.avatar_path,
    p.is_verified,
    p.badge,
    coalesce((
      select array_agg(pi.interest order by pi.interest)
      from public.profile_interests pi
      where pi.profile_id = p.id
    ), '{}'::text[]),
    case when p.visible_until > now() then p.visible_place_id end,
    case when p.visible_until > now() then pl.name end
  from public.profiles p
  left join public.places pl on pl.id = p.visible_place_id
  where p.id is distinct from auth.uid()
    and p.is_active
    and p.is_verified
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc nulls last, p.name
  limit greatest(1, least(coalesce(page_limit, 20), 50))
  offset greatest(0, coalesce(page_offset, 0));
$$;

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
    and p.visible_until > now()
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

create or replace function public.get_place_presence()
returns table (place_id uuid, people_count integer, avatar_paths text[])
language sql stable security definer set search_path = '' as $$
  with gorunen as (
    select p.visible_place_id as place_id, p.id, p.avatar_path, p.last_active_at
    from public.profiles p
    where auth.uid() is not null
      and p.visible_place_id is not null
      and p.visible_until > now()
      and p.is_verified and p.is_active
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

create or replace function public.touch_place_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.visible_place_id is not distinct from old.visible_place_id then
    return new;
  end if;
  if old.visible_place_id is not null then
    insert into public.place_activity (place_id, changed_at)
    values (old.visible_place_id, now())
    on conflict (place_id) do update set changed_at = excluded.changed_at;
  end if;
  if new.visible_place_id is not null then
    insert into public.place_activity (place_id, changed_at)
    values (new.visible_place_id, now())
    on conflict (place_id) do update set changed_at = excluded.changed_at;
  end if;
  return new;
exception
  -- Damga yazılamazsa yer seçimi yine de kaydedilsin.
  when others then return new;
end;
$$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261003020000', 'ghost_only_hides_traces')
on conflict (version) do nothing;

commit;
