-- Hayalet mod sunucuda da zorunlu. Eskiden yalnızca istemci ziyaret/izleme
-- isteğini göndermiyordu; uygulamayı kurcalayan biri aynı RPC'yi yine de
-- çağırabilirdi. Kolon + RPC + trigger: hayaletken iz bırakılmaz.
--
-- Push: bildirim satırı oluşunca Edge Function'ı çağıran tetikleyici.
-- Vault'ta `project_url` ve `service_role_key` yoksa sessizce geçer;
-- o durumda Dashboard → Database → Webhooks ile `send-push` bağlanır.
--
-- Idempotent.

begin;

alter table public.profiles
  add column if not exists ghost_mode boolean not null default false;

-- Pro (veya kurucu/moderatör) değilken açık sayılmaz. Kolon true kalsa bile
-- abonelik bitince iz bırakmama hakkı düşer.
create or replace function public.is_acting_ghost(account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.ghost_mode from public.profiles p where p.id = account
  ), false)
  and public.plan_of(account) = 'pro';
$$;

revoke all on function public.is_acting_ghost(uuid) from public, anon, authenticated;

create or replace function public.set_ghost_mode(enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if enabled and public.plan_of(auth.uid()) is distinct from 'pro' then
    raise exception 'ghost_mode requires pro';
  end if;
  update public.profiles
     set ghost_mode = enabled
   where id = auth.uid();
end;
$$;

revoke all on function public.set_ghost_mode(boolean) from public, anon;
grant execute on function public.set_ghost_mode(boolean) to authenticated;

-- Ziyaret: hayaletken satır açılmaz / sayaç artmaz.
create or replace function public.record_profile_visit(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or target is null or target = auth.uid() then return; end if;
  if public.is_acting_ghost(auth.uid()) then return; end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = target)
       or (b.blocker_id = target and b.blocked_id = auth.uid())
  ) then return; end if;
  if not exists (select 1 from public.profiles p where p.id = target and p.is_active) then return; end if;

  insert into public.profile_visits (profile_id, visitor_id)
  values (target, auth.uid())
  on conflict (profile_id, visitor_id) do update
    set visit_count = public.profile_visits.visit_count + 1,
        last_visited_at = now();
end;
$$;

revoke all on function public.record_profile_visit(uuid) from public, anon;
grant execute on function public.record_profile_visit(uuid) to authenticated;

-- Story izleme: INSERT/UPDATE hayaletken yutulur.
create or replace function public.skip_ghost_story_view()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_acting_ghost(new.viewer_id) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists story_views_skip_ghost on public.story_views;
create trigger story_views_skip_ghost
  before insert or update on public.story_views
  for each row execute function public.skip_ghost_story_view();

-- Kendi profilimde hayalet tercihini görmek için.
drop function if exists public.get_my_profile();
create or replace function public.get_my_profile()
returns table (
  name text, birth_date date, gender public.profile_gender,
  dating_preference public.dating_preference,
  relationship_intent public.relationship_intent,
  university text, department text, academic_year text, bio text,
  badge public.profile_badge,
  interests text[], prompt_keys text[], prompt_answers text[],
  min_age smallint, max_age smallint, academic_years text[], departments text[],
  require_common_interest boolean, campus_only boolean,
  ghost_mode boolean
)
language sql stable security definer set search_path = '' as $$
  select
    p.name, p.birth_date, p.gender, p.dating_preference, p.relationship_intent,
    p.university, p.department, p.academic_year, p.bio, p.badge,
    coalesce((select array_agg(pi.interest order by pi.interest) from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce(dp.min_age, 18::smallint),
    coalesce(dp.max_age, 30::smallint),
    coalesce(dp.academic_years, '{}'),
    coalesce(dp.departments, '{}'),
    coalesce(dp.require_common_interest, false),
    coalesce(dp.campus_only, true),
    p.ghost_mode
  from public.profiles p
  left join public.discovery_preferences dp on dp.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- Bildirim satırı → APNs. Sır yoksa no-op; insert asla düşmez.
create or replace function public.push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  service_key text;
begin
  begin
    select ds.decrypted_secret into project_url
      from vault.decrypted_secrets ds
     where ds.name = 'project_url'
     limit 1;
    select ds.decrypted_secret into service_key
      from vault.decrypted_secrets ds
     where ds.name = 'service_role_key'
     limit 1;
  exception
    when undefined_table then
      return new;
    when undefined_object then
      return new;
  end;

  if project_url is null or service_key is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', to_jsonb(new)
    )
  );
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists notifications_send_push on public.notifications;
create trigger notifications_send_push
  after insert on public.notifications
  for each row execute function public.push_on_notification();

commit;
