-- Right-swipe on a profile card notifies that person. It does not send a
-- message, create a match, or write a like/pass reaction.

begin;

create table if not exists public.profile_right_swipes (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (actor_id, subject_id),
  constraint profile_right_swipes_not_self check (actor_id <> subject_id)
);

alter table public.profile_right_swipes enable row level security;

drop policy if exists "actors read own right swipes" on public.profile_right_swipes;
create policy "actors read own right swipes" on public.profile_right_swipes
  for select to authenticated using (actor_id = auth.uid());

revoke all on public.profile_right_swipes from public, anon;
grant select on public.profile_right_swipes to authenticated;

create or replace function public.notify_on_profile_right_swipe()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (
    new.subject_id,
    'like',
    'Sizi biri sağa kaydırdı',
    public.profile_display_name(new.actor_id) || ' kartını sağa kaydırdı.',
    new.actor_id
  );
  return new;
end;
$$;

drop trigger if exists profile_right_swipes_notify on public.profile_right_swipes;
create trigger profile_right_swipes_notify
after insert on public.profile_right_swipes
for each row execute function public.notify_on_profile_right_swipe();

create or replace function public.swipe_right_on_profile(subject uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  inserted uuid;
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
end;
$$;

revoke all on function public.swipe_right_on_profile(uuid) from public, anon;
grant execute on function public.swipe_right_on_profile(uuid) to authenticated;

commit;
