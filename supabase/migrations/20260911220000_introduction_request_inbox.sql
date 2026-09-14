-- Named, explicit connection requests. No automatic chat message is inserted.
-- Deploy after 20260911210000_mutual_right_swipe_creates_match.sql.
begin;

-- Do not reveal identities behind historical, anonymous swipe notifications.
alter table public.profile_right_swipes
  add column if not exists introduction_visible boolean not null default false;
alter table public.profile_right_swipes alter column introduction_visible set default true;

create or replace function public.get_introduction_requests()
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department,
         p.academic_year, p.bio, p.avatar_path, p.is_verified, p.badge
  from public.profile_right_swipes s
  join public.profiles p on p.id = s.actor_id
  where auth.uid() is not null and s.subject_id = auth.uid()
    and s.introduction_visible
    and p.is_active and p.is_verified
    and not exists (
      select 1 from public.profile_right_swipes reciprocal
      where reciprocal.actor_id = auth.uid() and reciprocal.subject_id = p.id
    )
    and not exists (
      select 1 from public.matches m
      where m.user_a = least(auth.uid(), p.id)
        and m.user_b = greatest(auth.uid(), p.id) and m.unmatched_at is null
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by s.created_at desc;
$$;
revoke all on function public.get_introduction_requests() from public, anon;
grant execute on function public.get_introduction_requests() to authenticated;

create or replace function public.notify_on_profile_right_swipe()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.profile_right_swipes s
             where s.actor_id = new.subject_id and s.subject_id = new.actor_id) then
    return new;
  end if;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (new.subject_id, 'like', 'Tanışma isteği',
          public.profile_display_name(new.actor_id) || ' seninle tanışmak istiyor.', new.actor_id);
  return new;
end;
$$;

commit;
