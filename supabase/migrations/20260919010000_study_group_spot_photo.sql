-- Çalışma grubu "Yerimi göster" fotoğrafı.
--
-- "Katıldım, peki kütüphanenin neresindesin?" Ev sahibi başlangıçtan 15 dk
-- önce → bitişe (başlangıç + 2 sa) kadar nerede olduğunu gösteren tek bir
-- fotoğraf paylaşır; yeniden çekince eskisinin yerine geçer. Fotoğrafı yalnızca
-- katılanlar ve ev sahibi görür; katılanlara bildirim gider.
-- Yol: <ev sahibi uuid>/<grup uuid>.jpg — bucket kuralları klasör = kullanıcı.

begin;

alter table public.study_groups
  add column if not exists spot_photo_path text,
  add column if not exists spot_photo_at timestamptz;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('study-group-photos', 'study-group-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Okuma: ev sahibi ya da açık grubun katılanı.
create or replace function public.can_read_study_spot(owner_uuid uuid, media_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select owner_uuid = auth.uid()
    or exists (
      select 1 from public.study_groups g
      join public.study_group_members m on m.group_id = g.id and m.user_id = auth.uid()
      where g.host_id = owner_uuid and g.spot_photo_path = media_name
        and g.cancelled_at is null and g.starts_at + interval '2 hours' > now()
    );
$$;
revoke all on function public.can_read_study_spot(uuid, text) from public, anon;
grant execute on function public.can_read_study_spot(uuid, text) to authenticated;

drop policy if exists "study spot photos read" on storage.objects;
create policy "study spot photos read" on storage.objects
for select to authenticated using (
  bucket_id = 'study-group-photos'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_read_study_spot(((storage.foldername(name))[1])::uuid, name)
);
drop policy if exists "study spot photos write" on storage.objects;
create policy "study spot photos write" on storage.objects
for insert to authenticated with check (
  bucket_id = 'study-group-photos' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists "study spot photos replace" on storage.objects;
create policy "study spot photos replace" on storage.objects
for update to authenticated
using (bucket_id = 'study-group-photos' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'study-group-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "study spot photos delete" on storage.objects;
create policy "study spot photos delete" on storage.objects
for delete to authenticated
using (bucket_id = 'study-group-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Ev sahibi fotoğrafı bağlar: pencere içinde, kendi klasöründen. Katılanlara bildirim.
create or replace function public.set_study_group_spot_photo(target uuid, path text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  grup public.study_groups;
  yer text;
begin
  select * into grup from public.study_groups where id = target;
  if grup.id is null or grup.host_id <> auth.uid() then
    raise exception 'FORBIDDEN' using errcode = 'insufficient_privilege';
  end if;
  if grup.cancelled_at is not null
     or now() < grup.starts_at - interval '15 minutes'
     or now() > grup.starts_at + interval '2 hours' then
    raise exception 'STUDY_GROUP_SPOT_WINDOW' using errcode = 'check_violation';
  end if;
  if path not like auth.uid()::text || '/%' then
    raise exception 'BAD_PATH' using errcode = 'check_violation';
  end if;

  update public.study_groups set spot_photo_path = path, spot_photo_at = now() where id = target;

  select name into yer from public.places where id = grup.place_id;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  select m.user_id, 'study_group', 'Yer paylaşıldı',
         public.profile_display_name(grup.host_id) || ' yerini paylaştı — ' || coalesce(yer, '') || '.',
         grup.host_id
  from public.study_group_members m
  where m.group_id = target;
end;
$$;
revoke all on function public.set_study_group_spot_photo(uuid, text) from public, anon;
grant execute on function public.set_study_group_spot_photo(uuid, text) to authenticated;

commit;
