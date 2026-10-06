-- Tanıyor olabileceğin kişiler: kurucu en başta, altında yazı yok. Test
-- hesapları (Apple inceleme hesapları, kurucunun deneme hesapları) hiç
-- önerilmez; sohbeti temizlenmiş bağlantı olsalar bile.
--
-- Henüz kurucuyla bağlantısı olmayan herkese ilk kart kurucu. Kartını X ile
-- kapatan, kaydıran ya da bağlantı kuran bir daha görmez (genel kurallar).
-- Gövde 20261003020000'deki canlı tanımdan; yalnızca kurucu satırları eklendi.
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
      and not p.is_test_account
      and (
        -- Kendi bağlantın: keşif kuralları (kaydırma) uygulanmaz.
        exists (select 1 from cleared_peers cp where cp.other = p.id)
        or (
          -- Kurucu her kampüste önerilir (yeni üniversiteden katılana da).
          (p.university = me.university or p.badge = 'founder')
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
        -- Kurucu: boş 'department' bilinçli; 1.1'den beri her sürüm bunu
        -- kabul ediyor ve altına hiçbir şey yazmıyor.
        when c.badge = 'founder' then 'department'
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
        when c.badge = 'founder' then ''
        when c.mutuals > 0 then null
        when c.club_name is not null then c.club_name
        when c.same_year or c.same_department then c.department
        when c.shared_interests >= 2 then null
        else c.department
      end as reason_detail,
      case
        when c.is_cleared then 0
        when c.badge = 'founder' then 0
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
  -- Sohbeti temizlenen bağlantı, sonra kurucu, sonra en son katılan en önde
  -- (kurucunun isteği); eşitlikte ortak nokta gücü.
  order by s.is_cleared desc, (s.badge = 'founder') desc, s.created_at desc, s.score desc, s.id
  limit greatest(1, least(coalesce(max_count, 12), 20));
$$;

-- Kurucunun ikinci deneme hesabı da test hesabı.
update public.profiles set is_test_account = true where username = 'test.test';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261006010000', 'suggestions_founder_first')
on conflict (version) do nothing;

commit;
