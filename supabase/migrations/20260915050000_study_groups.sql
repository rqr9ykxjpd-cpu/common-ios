-- Çalışma grubu: "Şu saatte kütüphanede ders çalışacağım, gelen olur mu?"
--
-- Akışta "Çalışma grubu kur" ile açılır; kart olarak görünür; Kim nerede'deki
-- BURADAYIM gibi tek dokunuşla "Katıl". Grup sohbeti yok: katılanların kartı
-- açılır, tanışma oradan (sağa kaydır). Başlangıçtan 2 saat sonra kart düşer.
-- Kişinin aynı anda tek açık grubu olur (spam değil, plan).

alter type public.notification_kind add value if not exists 'study_group';

begin;

create table if not exists public.study_groups (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  starts_at timestamptz not null,
  note text not null default '' check (char_length(note) <= 140),
  capacity integer check (capacity is null or capacity between 2 and 30),
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  constraint study_groups_starts_soon check (starts_at > created_at - interval '15 minutes'
                                             and starts_at < created_at + interval '7 days')
);
create index if not exists study_groups_active_idx on public.study_groups (starts_at) where cancelled_at is null;

create table if not exists public.study_group_members (
  group_id uuid not null references public.study_groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.study_groups enable row level security;
alter table public.study_group_members enable row level security;

-- Görünürlük: iptal edilmemiş, süresi dolmamış, dondurulmuş/engelli olmayan ev sahibi.
create or replace function public.study_group_visible(g public.study_groups)
returns boolean language sql stable security definer set search_path = '' as $$
  select g.cancelled_at is null
     and g.starts_at + interval '2 hours' > now()
     and not public.content_hidden(g.host_id);
$$;
revoke all on function public.study_group_visible(public.study_groups) from public, anon;
grant execute on function public.study_group_visible(public.study_groups) to authenticated;

drop policy if exists "read active study groups" on public.study_groups;
create policy "read active study groups" on public.study_groups
for select to authenticated using (public.study_group_visible(study_groups));

drop policy if exists "hosts create study groups" on public.study_groups;
create policy "hosts create study groups" on public.study_groups
for insert to authenticated with check (host_id = auth.uid());

drop policy if exists "hosts cancel study groups" on public.study_groups;
create policy "hosts cancel study groups" on public.study_groups
for update to authenticated using (host_id = auth.uid()) with check (host_id = auth.uid());

drop policy if exists "moderators delete any study group" on public.study_groups;
create policy "moderators delete any study group" on public.study_groups
for delete to authenticated using (host_id = auth.uid() or public.is_moderator());

drop policy if exists "read study group members" on public.study_group_members;
create policy "read study group members" on public.study_group_members
for select to authenticated
using (exists (select 1 from public.study_groups g where g.id = group_id));

drop policy if exists "join study groups as self" on public.study_group_members;
create policy "join study groups as self" on public.study_group_members
for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.study_groups g where g.id = group_id));

drop policy if exists "leave study groups" on public.study_group_members;
create policy "leave study groups" on public.study_group_members
for delete to authenticated using (user_id = auth.uid());

grant select, insert, update (cancelled_at), delete on public.study_groups to authenticated;
grant select, insert, delete on public.study_group_members to authenticated;

-- Metin güvenliği ve dondurulmuş hesap: gönderilerdeki kurallar aynen.
drop trigger if exists study_groups_text_safety on public.study_groups;
create trigger study_groups_text_safety before insert or update of note on public.study_groups
for each row execute function public.check_content_text_before_write('note');
drop trigger if exists study_groups_block_inactive on public.study_groups;
create trigger study_groups_block_inactive before insert on public.study_groups
for each row execute function public.block_inactive_authors();
drop trigger if exists study_group_members_block_inactive on public.study_group_members;
create trigger study_group_members_block_inactive before insert on public.study_group_members
for each row execute function public.block_inactive_authors();

-- Tek açık grup; süresi dolan ya da iptal edilen sayılmaz.
create or replace function public.enforce_single_open_study_group()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.study_groups g
    where g.host_id = new.host_id and g.id <> new.id
      and g.cancelled_at is null and g.starts_at + interval '2 hours' > now()
  ) then
    raise exception 'STUDY_GROUP_ACTIVE_EXISTS' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;
drop trigger if exists study_groups_single_open on public.study_groups;
create trigger study_groups_single_open before insert on public.study_groups
for each row execute function public.enforce_single_open_study_group();

-- Katılım: ev sahibi zaten içeride; kontenjan doluysa reddet; ev sahibine bildirim.
create or replace function public.on_study_group_join()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  grup public.study_groups;
  dolu integer;
begin
  select * into grup from public.study_groups where id = new.group_id;
  if grup.id is null or grup.cancelled_at is not null or grup.starts_at + interval '2 hours' <= now() then
    raise exception 'STUDY_GROUP_CLOSED' using errcode = 'check_violation';
  end if;
  if grup.host_id = new.user_id then
    raise exception 'SELF' using errcode = 'check_violation';
  end if;
  if grup.capacity is not null then
    select count(*) into dolu from public.study_group_members where group_id = new.group_id;
    -- Ev sahibi kontenjandan bir kişi sayılır.
    if dolu + 1 >= grup.capacity then
      raise exception 'STUDY_GROUP_FULL' using errcode = 'check_violation';
    end if;
  end if;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (grup.host_id, 'study_group', 'Çalışma grubuna katılım',
          public.profile_display_name(new.user_id) || ' çalışma grubuna katıldı.', new.user_id);
  return new;
end;
$$;
drop trigger if exists study_group_members_join on public.study_group_members;
create trigger study_group_members_join before insert on public.study_group_members
for each row execute function public.on_study_group_join();

-- Ev sahibi ve katılanların profili herkes tarafından okunabilsin (kart için).
drop policy if exists "users view relevant profiles" on public.profiles;
create policy "users view relevant profiles" on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or exists (select 1 from public.matches m where m.unmatched_at is null
             and ((m.user_a = auth.uid() and m.user_b = profiles.id) or (m.user_b = auth.uid() and m.user_a = profiles.id)))
  or exists (select 1 from public.posts p where p.author_id = profiles.id)
  or exists (select 1 from public.stories s where s.author_id = profiles.id and s.expires_at > now())
  or exists (select 1 from public.comments c where c.author_id = profiles.id)
  or exists (select 1 from public.meeting_requests mr
             where (mr.requester_id = auth.uid() and mr.recipient_id = profiles.id)
                or (mr.recipient_id = auth.uid() and mr.requester_id = profiles.id))
  or exists (select 1 from public.story_views sv join public.stories s on s.id = sv.story_id
             where sv.viewer_id = profiles.id and s.author_id = auth.uid())
  or exists (select 1 from public.notifications n where n.user_id = auth.uid() and n.actor_id = profiles.id)
  or exists (select 1 from public.study_groups g where g.host_id = profiles.id)
  or exists (select 1 from public.study_group_members gm where gm.user_id = profiles.id)
);

commit;
