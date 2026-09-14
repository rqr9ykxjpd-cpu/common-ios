-- Right-swipe identity is founder-only. Everyone else gets an anonymous ping
-- (no actor_id, no name). who_liked_me reads profile_right_swipes for founders.

begin;

create or replace function public.notify_on_profile_right_swipe()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  subject_is_founder boolean;
begin
  select p.badge = 'founder'
  into subject_is_founder
  from public.profiles p
  where p.id = new.subject_id;

  if coalesce(subject_is_founder, false) then
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (
      new.subject_id,
      'like',
      'Sizi biri sağa kaydırdı',
      public.profile_display_name(new.actor_id) || ' kartını sağa kaydırdı.',
      new.actor_id
    );
  else
    insert into public.notifications (user_id, kind, title, body, actor_id)
    values (
      new.subject_id,
      'like',
      'Sizi biri sağa kaydırdı',
      'Kartını biri sağa kaydırdı.',
      null
    );
  end if;

  return new;
end;
$$;

-- Scrub existing named right-swipe pings for non-founders.
update public.notifications n
set actor_id = null,
    body = 'Kartını biri sağa kaydırdı.'
from public.profiles p
where n.user_id = p.id
  and p.badge is distinct from 'founder'
  and n.kind = 'like'
  and n.title = 'Sizi biri sağa kaydırdı'
  and n.actor_id is not null;

create or replace function public.who_liked_me()
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
  liked_at timestamptz,
  is_matched boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.badge = 'founder'
  ) then
    raise exception 'Founder privileges required';
  end if;

  return query
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
    s.created_at,
    exists (
      select 1 from public.matches m
      where m.user_a = least(p.id, auth.uid())
        and m.user_b = greatest(p.id, auth.uid())
        and m.unmatched_at is null
    )
  from public.profile_right_swipes s
  join public.profiles p on p.id = s.actor_id
  where s.subject_id = auth.uid()
    and p.is_active
  order by s.created_at desc;
end;
$$;

revoke all on function public.who_liked_me() from public, anon;
grant execute on function public.who_liked_me() to authenticated;

commit;
