-- Mutual right-swipe creates a match (DM). One-way swipe stays a ping only.

begin;

create or replace function public.notify_on_profile_right_swipe()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  subject_is_founder boolean;
  is_mutual boolean;
begin
  -- Second swipe of a mutual pair: match notification covers both sides.
  select exists (
    select 1
    from public.profile_right_swipes s
    where s.actor_id = new.subject_id
      and s.subject_id = new.actor_id
  ) into is_mutual;

  if coalesce(is_mutual, false) then
    return new;
  end if;

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

drop function if exists public.swipe_right_on_profile(uuid);

create or replace function public.swipe_right_on_profile(subject uuid)
returns table (matched boolean, match_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  inserted uuid;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
  karsilikli boolean;
begin
  if actor is null or subject is null or subject = actor then
    raise exception 'Invalid swipe';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = subject and p.is_active and p.is_verified
  ) then
    raise exception 'Profile unavailable';
  end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = actor and b.blocked_id = subject)
       or (b.blocker_id = subject and b.blocked_id = actor)
  ) then
    raise exception 'RIGHT_SWIPE_BLOCKED';
  end if;

  insert into public.profile_right_swipes(actor_id, subject_id)
  values (actor, subject)
  on conflict (actor_id, subject_id) do nothing
  returning subject_id into inserted;

  if inserted is null then
    raise exception 'RIGHT_SWIPE_EXISTS';
  end if;

  select exists (
    select 1
    from public.profile_right_swipes s
    where s.actor_id = subject and s.subject_id = actor
  ) into karsilikli;

  if not coalesce(karsilikli, false) then
    return query select false, null::uuid;
    return;
  end if;

  ilk := least(actor, subject);
  ikinci := greatest(actor, subject);

  insert into public.matches(user_a, user_b)
  values (ilk, ikinci)
  on conflict (user_a, user_b) do update set unmatched_at = null
  returning id into eslesme;

  return query select true, eslesme;
end;
$$;

revoke all on function public.swipe_right_on_profile(uuid) from public, anon;
grant execute on function public.swipe_right_on_profile(uuid) to authenticated;

-- Connection wording (not dating “like”).
create or replace function public.notify_on_match()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.unmatched_at is not null then return new; end if;
  insert into public.notifications (user_id, kind, title, body, actor_id, match_id)
  values
    (new.user_a, 'match', 'Yeni bağlantı',
     'Sen ve ' || public.profile_display_name(new.user_b) || ' artık bağlantıdasınız.', new.user_b, new.id),
    (new.user_b, 'match', 'Yeni bağlantı',
     'Sen ve ' || public.profile_display_name(new.user_a) || ' artık bağlantıdasınız.', new.user_a, new.id);
  return new;
end;
$$;

commit;
