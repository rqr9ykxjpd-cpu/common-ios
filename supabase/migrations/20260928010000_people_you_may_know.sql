-- Tanıyor olabileceğin kişiler (Build 7): Sohbet sekmesinin üstündeki öneriler.
--
-- Rastgele kişi listesi değil. Her öneri somut bir ortak noktaya dayanıyor ve
-- ortak nokta kartın altında yazıyor: ortak bağlantı, ortak kulüp, aynı bölüm
-- ve sınıf, aynı bölüm, en az iki ortak ilgi alanı. Ortak noktası olmayan kimse
-- önerilmiyor.
--
-- Görünmeyenler (get_campus_people'daki kurallar + bağlantı durumu):
--   hayalet mod, kapalı/askıdaki hesap, iki yönlü engel, başka kampüs,
--   zaten bağlantın olanlar, kartını sağa ya da sola geçtiklerin,
--   önerilerden kaldırdıkların.
begin;

-- × ile önerilerden kaldırılanlar. Yalnızca sahibinin önerilerini etkiler;
-- kimseye bildirilmez, doğrudan okunmaz.
create table if not exists public.suggestion_dismissals (
  user_id uuid not null references public.profiles(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, profile_id),
  constraint suggestion_dismissals_not_self check (user_id <> profile_id)
);
alter table public.suggestion_dismissals enable row level security;
revoke all on public.suggestion_dismissals from anon, authenticated;

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
        and btrim(p.academic_year) <> '' and p.academic_year = me.academic_year) as same_year
    from public.profiles p, me
    where p.id <> me.id
      and p.is_active
      and p.is_verified
      and not coalesce(p.ghost_mode, false)
      and p.university = me.university
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = me.id and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = me.id)
      )
      and not exists (select 1 from my_connections c where c.other = p.id)
      and not exists (
        select 1 from public.profile_right_swipes s where s.actor_id = me.id and s.subject_id = p.id
      )
      and not exists (
        select 1 from public.profile_left_swipes s where s.actor_id = me.id and s.subject_id = p.id
      )
      and not exists (
        select 1 from public.suggestion_dismissals d where d.user_id = me.id and d.profile_id = p.id
      )
  ),
  scored as (
    select
      c.*,
      -- En güçlü ortak nokta kartın altında yazan sebep.
      case
        when c.mutuals > 0 then 'mutual'
        when c.club_name is not null then 'club'
        when c.same_year then 'classmate'
        when c.same_department then 'department'
        when c.shared_interests >= 2 then 'interests'
      end as reason,
      case
        when c.mutuals > 0 then null
        when c.club_name is not null then c.club_name
        when c.same_year or c.same_department then c.department
      end as reason_detail,
      case
        when c.mutuals > 0 then c.mutuals
        when c.club_name is null and not c.same_year and not c.same_department then c.shared_interests
        else 0
      end as reason_count,
      c.mutuals * 4
        + c.shared_clubs * 3
        + (case when c.same_year then 3 else 0 end)
        + (case when c.same_department then 2 else 0 end)
        + least(c.shared_interests, 5) as score
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
  -- Fotoğrafı olanlar önde: yuvarlakta boş daire öneriyi zayıflatıyor.
  order by (s.avatar_path is not null) desc, s.score desc, s.last_active_at desc nulls last, s.id
  limit greatest(1, least(coalesce(max_count, 12), 20));
$$;

revoke all on function public.get_people_you_may_know(integer) from public, anon;
grant execute on function public.get_people_you_may_know(integer) to authenticated;

create or replace function public.dismiss_suggestion(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target is null or target = auth.uid() then return; end if;
  insert into public.suggestion_dismissals (user_id, profile_id)
  values (auth.uid(), target)
  on conflict do nothing;
end;
$$;

revoke all on function public.dismiss_suggestion(uuid) from public, anon;
grant execute on function public.dismiss_suggestion(uuid) to authenticated;

commit;
