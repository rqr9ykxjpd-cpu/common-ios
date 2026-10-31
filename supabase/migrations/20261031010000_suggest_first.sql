-- Önerilerde kurucunun hemen arkasında duran hesap (kurucunun isteği, 31 Ekim:
-- "bu hesabı en başta gösterelim", herkese). Bayrak `profiles.suggest_first`;
-- yalnızca sıralamada ve kampüs kuralında kullanılıyor. Engelleme, X ile kapatma, sola kaydırma ve mevcut
-- bağlantı kuralları aynen geçerli. İlk hesap: Tuna (@tunaozdemire), test
-- işareti kalkıyor ki önerilerde görünsün. Gövde canlıdaki tanımdan (31 Ekim).
begin;

alter table public.profiles add column if not exists suggest_first boolean not null default false;

CREATE OR REPLACE FUNCTION public.get_people_you_may_know(max_count integer DEFAULT 12, include_sent boolean DEFAULT false)
 RETURNS TABLE(id uuid, name text, birth_date date, university text, department text, academic_year text, bio text, avatar_path text, is_verified boolean, badge profile_badge, interests text[], reason text, reason_detail text, reason_count integer, sent boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with me as (
    select p.id, p.university, p.department, p.academic_year, p.badge
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
      exists (select 1 from cleared_peers cp where cp.other = p.id) as is_cleared,
      -- Kurucuyu öneride X ile kapatanlar herkesin listesinde en sonda
      -- (kurucunun isteği). Listeden çıkmazlar, yalnızca sıraları sona gider.
      exists (
        select 1
        from public.suggestion_dismissals d
        join public.profiles f on f.id = d.profile_id and f.badge = 'founder'
        where d.user_id = p.id
      ) as sona,
      exists (
        select 1 from public.profile_right_swipes s where s.actor_id = me.id and s.subject_id = p.id
      ) as is_sent
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
          -- Öne alınan hesap (suggest_first) da her kampüste önerilir.
          (p.university = me.university or p.badge = 'founder' or p.suggest_first)
          and not exists (select 1 from my_connections c where c.other = p.id)
          -- Sağa geçtiğin ve yanıt bekleyen kişi: yeni istemci (include_sent)
          -- "Gönderildi" ile görür; kurucu her sürümde görür; eski istemcide düşer.
          and (me.badge = 'founder' or include_sent or not exists (
            select 1 from public.profile_right_swipes s where s.actor_id = me.id and s.subject_id = p.id
          ))
          and not exists (
            select 1 from public.profile_left_swipes s where s.actor_id = me.id and s.subject_id = p.id
          )
        )
      )
  ),
  scored as (
    select
      c.*,
      -- Fotoğrafın altında kişinin bölümü yazar (1.1.3'ten itibaren sınıfı da);
      -- kulüp, ortak bağlantı ya da ortak ilgi yazmaz (kurucunun isteği).
      -- Ortak noktalar yalnızca sıralamada (score).
      case
        -- Yalnızca 1.1.1 sohbet temizleyebildiği için eski istemci bu sebebi görmez.
        when c.is_cleared then 'connection'
        -- Kurucu: boş 'department' bilinçli; 1.1'den beri her sürüm bunu
        -- kabul ediyor ve altına hiçbir şey yazmıyor.
        when c.badge = 'founder' then 'department'
        -- Bölümü boş olan da listede kalır (altı boş görünür).
        else 'department'
      end as reason,
      -- Fotoğrafın altı iki satır: bölüm ve sınıf. 1.1.2 bu metni olduğu gibi
      -- (iki satır) gösteriyor; 1.1.3+ bölüm ve sınıfı kendisi okuyor, bu
      -- alana bakmıyor. Ayraç satır sonu: 1.1.2 "· / , |" görünce bölüyordu.
      case
        when c.is_cleared then null
        when c.badge = 'founder' then ''
        else coalesce(nullif(concat_ws(E'\n',
          nullif(btrim(c.department), ''),
          nullif(btrim(c.academic_year), '')), ''), '')
      end as reason_detail,
      0 as reason_count,
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
    s.reason_count,
    s.is_sent
  from scored s
  where s.reason is not null
  -- Kurucu her zaman en önde, sonra sohbeti temizlenen bağlantı, sonra en
  -- son katılan (kurucunun isteği); eşitlikte ortak nokta gücü. Kurucuyu
  -- X ile kapatanlar herkesin listesinde en sonda.
  -- Sayı sınırı yok (kurucunun isteği): önerilebilecek herkes gelir.
  -- `max_count` eski istemciler gönderdiği için duruyor, kullanılmıyor.
  -- Öne alınan hesap (suggest_first) kurucunun hemen arkasında (31 Ekim).
  order by s.sona, (s.badge = 'founder') desc, s.suggest_first desc, s.is_cleared desc, s.created_at desc, s.score desc, s.id;
$function$;

update public.profiles
   set suggest_first = true,
       is_test_account = false
 where id = 'a18bfb3b-eea9-4110-9963-ae847b959c40';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261031010000', 'suggest_first')
on conflict (version) do nothing;

commit;
