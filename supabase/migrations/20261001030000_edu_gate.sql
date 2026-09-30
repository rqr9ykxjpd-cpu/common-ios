-- Öğrenci kilidi (1.1).
--
-- Okul e-postası doğrulanmamış (ve muaf olmayan) hesap:
--   - kimseye görünmez: kişi listeleri, Kim nerede, öneriler, profil fotoğrafı,
--     gönderileri, yorumları, story'leri;
--   - paylaşamaz, yorum yazamaz, oy/beğeni veremez, story atamaz/izleyemez,
--     mesaj ya da bağlantı/buluşma isteği gönderemez, kulübe ya da çalışma
--     grubuna katılamaz, "Buradayım" diyemez;
--   - akışı ve Kim nerede'yi gezebilir (başkalarının fotoğraflarını görür).
-- Muaf: kurucu, moderatör, edu_exempt. Şikâyet, engelleme, kaydetme ve
-- Sorun bildir her zaman açık.
--
-- Kilit KAPALI başlıyor: yayındaki 1.0'da doğrulama ekranı yok, açık olsa
-- 1.0 kullanıcıları doğrulayamadan kilitli kalırdı. 1.1 mağazaya çıkınca
-- kurucu panelden açar (founder_set_edu_gate). 1.1 uygulaması kilidi kendisi
-- de gösteriyor; sunucu bunu zorunlu kılıyor ve görünürlüğü uyguluyor.
--
-- Görünürlük mevcut kurallarla sağlanıyor: kişi, yer ve öneri fonksiyonları
-- "is_verified" olmayanı göstermiyor; kilit açıkken is_verified =
-- doğrulanmış/muaf/rozetli. İçerik `content_hidden` ile gizleniyor. Okuyan
-- taraftaki "is_verified" şartı iki medya kuralından kalkıyor ki doğrulanmamış
-- öğrenci gezerken fotoğrafları görsün (kilit kapalıyken zaten herkes true).
begin;

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);
alter table public.app_settings enable row level security;
revoke all on public.app_settings from anon, authenticated;

create or replace function public.edu_gate_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select s.value = 'true'::jsonb from public.app_settings s where s.key = 'edu_gate'), false);
$$;
revoke all on function public.edu_gate_active() from public, anon;
grant execute on function public.edu_gate_active() to authenticated;

-- Etkileşime açık mı: doğrulanmış, muaf ya da rozetli. Sistem işlemleri
-- (auth.uid() yok) her zaman açık.
create or replace function public.can_interact(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select uid is null or exists (
    select 1 from public.profiles p
    where p.id = uid
      and (p.edu_exempt or p.edu_verified_at is not null or p.badge in ('founder', 'moderator'))
  );
$$;
revoke all on function public.can_interact(uuid) from public, anon;
grant execute on function public.can_interact(uuid) to authenticated;

-- Etkileşim tablolarına yazma: kilit açıkken doğrulanmamış hesap reddedilir
-- ('EDU_REQUIRED'; uygulama doğrulama penceresini açar). 'skip' verilen
-- tablolarda (story izleme, profil ziyareti) satır sessizce yazılmaz: kimse
-- doğrulanmamış hesabı "görüntüleyenler"de görmez.
create or replace function public.edu_gate_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and public.edu_gate_active() and not public.can_interact(auth.uid()) then
    if tg_nargs > 0 and tg_argv[0] = 'skip' then return null; end if;
    raise exception 'EDU_REQUIRED';
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'posts', 'comments', 'post_likes', 'comment_votes', 'stories', 'story_likes',
    'meeting_requests', 'message_requests', 'messages', 'club_members',
    'study_groups', 'study_group_members', 'profile_right_swipes'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_edu_gate', t);
    execute format('create trigger %I before insert on public.%I for each row execute function public.edu_gate_guard()', t || '_edu_gate', t);
  end loop;
  foreach t in array array['story_views', 'profile_visits'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_edu_gate', t);
    execute format('create trigger %I before insert on public.%I for each row execute function public.edu_gate_guard(''skip'')', t || '_edu_gate', t);
  end loop;
end $$;

-- Profil: kilit açıkken "is_verified" doğrulama durumunu izler; doğrulanmamış
-- hesap yerini ("Buradayım") gösteremez.
create or replace function public.edu_gate_profile_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  izinli boolean;
begin
  if not public.edu_gate_active() then return new; end if;
  izinli := new.edu_exempt or new.edu_verified_at is not null or new.badge in ('founder', 'moderator');
  new.is_verified := izinli;
  if not izinli and new.visible_place_id is not null
     and (tg_op = 'INSERT' or new.visible_place_id is distinct from old.visible_place_id) then
    if auth.uid() is not null and auth.uid() = new.id then raise exception 'EDU_REQUIRED'; end if;
    new.visible_place_id := null;
    new.visible_until := null;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_edu_gate on public.profiles;
create trigger profiles_edu_gate
before insert or update on public.profiles
for each row execute function public.edu_gate_profile_guard();

-- İçerik görünürlüğü: kilit açıkken doğrulanmamış yazarın gönderisi, yorumu
-- ve story'si başkalarına gizli.
create or replace function public.content_hidden(author uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select author <> auth.uid() and (
    not exists (select 1 from public.profiles p where p.id = author and p.is_active)
    or exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = author)
         or (b.blocker_id = author and b.blocked_id = auth.uid())
    )
    or (public.edu_gate_active() and not public.can_interact(author))
  );
$$;

-- Medya: okuyanın "is_verified" şartı kalktı (doğrulanmamış öğrenci gezerken
-- fotoğrafları görsün). Görünen kişinin şartı aynen duruyor.
create or replace function public.can_read_media(owner_uuid uuid, media_bucket text, media_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select owner_uuid = auth.uid()
  or (
    exists (
      select 1 from public.profiles reader
      where reader.id = auth.uid() and reader.is_active
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = owner_uuid)
         or (b.blocker_id = owner_uuid and b.blocked_id = auth.uid())
    )
    and (
      (media_bucket = 'post-media' and exists (
        select 1 from public.posts p where p.author_id = owner_uuid and p.media_path = media_name
      ))
      or (media_bucket = 'story-media' and exists (
        select 1 from public.stories s
        where s.author_id = owner_uuid
          and s.expires_at > now()
          and (s.media_path = media_name or s.poster_path = media_name)
      ))
      or (media_bucket = 'profile-photos' and exists (
        select 1 from public.profiles p
        where p.id = owner_uuid and p.is_verified and p.is_active
      ))
      or exists (
        select 1 from public.matches m
        where m.unmatched_at is null
          and ((m.user_a = auth.uid() and m.user_b = owner_uuid)
            or (m.user_b = auth.uid() and m.user_a = owner_uuid))
      )
    )
  );
$$;

create or replace function public.can_read_profile_photo(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and (
    public.media_owner_id(object_name) = auth.uid()
    or (
      exists(select 1 from public.profiles r
        where r.id = auth.uid() and r.is_active)
      and exists(select 1 from public.profiles p
        where p.id = public.media_owner_id(object_name)
          and p.is_active and p.is_verified
          and (p.avatar_path = object_name or exists(
            select 1 from public.profile_photos ph
            where ph.profile_id = p.id and ph.storage_path = object_name)))
      and not exists(select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = public.media_owner_id(object_name))
           or (b.blocked_id = auth.uid() and b.blocker_id = public.media_owner_id(object_name)))
    )
  );
$$;

-- Uygulama: kilit açık mı (kurucu panelindeki anahtar için).
create or replace function public.get_edu_gate()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.edu_gate_active();
$$;
revoke all on function public.get_edu_gate() from public, anon;
grant execute on function public.get_edu_gate() to authenticated;

-- Kurucu: kilidi aç/kapat. Açınca doğrulanmamış hesaplar görünmez olur ve
-- açık "Buradayım"ları kapanır; kapatınca herkes eskisi gibi görünür.
create or replace function public.founder_set_edu_gate(enabled boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  acik boolean := coalesce(enabled, false);
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  insert into public.app_settings (key, value, updated_by)
  values ('edu_gate', to_jsonb(acik), auth.uid())
  on conflict (key) do update
    set value = excluded.value, updated_at = now(), updated_by = excluded.updated_by;

  if acik then
    update public.profiles p
       set is_verified = (p.edu_exempt or p.edu_verified_at is not null or p.badge in ('founder', 'moderator')),
           visible_place_id = case when p.edu_exempt or p.edu_verified_at is not null or p.badge in ('founder', 'moderator')
                                   then p.visible_place_id end,
           visible_until = case when p.edu_exempt or p.edu_verified_at is not null or p.badge in ('founder', 'moderator')
                                then p.visible_until end;
  else
    update public.profiles set is_verified = true where not is_verified;
  end if;
  return acik;
end;
$$;
revoke all on function public.founder_set_edu_gate(boolean) from public, anon;
grant execute on function public.founder_set_edu_gate(boolean) to authenticated;

-- Muaf tutma ve doğrulama is_verified'i hemen günceller (profiles tetikleyicisi);
-- muafiyeti kaldırılan hesap kilit açıkken görünmez olur.

commit;
