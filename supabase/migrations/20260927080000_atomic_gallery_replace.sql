-- Galeri değişimi önce eski satırları silip sonra yenilerini yazmamalı: ikinci
-- adım hata verirse kullanıcının çalışan galerisi kaybolur. Bu RPC satır
-- değişimini tek veritabanı işlemi yapar; Storage dosyaları istemci tarafından
-- yalnızca başarılı sonuçtan sonra temizlenir.

begin;

create or replace function public.replace_gallery_photos(p_storage_paths text[])
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_paths text[] := coalesce(p_storage_paths, '{}'::text[]);
  v_old_paths text[];
begin
  if v_uid is null then raise exception 'authentication required'; end if;
  if cardinality(v_paths) > 5 then raise exception 'gallery_full'; end if;
  if cardinality(v_paths) <> (select count(distinct p.path) from unnest(v_paths) as p(path)) then
    raise exception 'gallery_duplicate_path';
  end if;
  if exists (
    select 1 from unnest(v_paths) as p(path)
    where p.path is null
       or p.path <> btrim(p.path)
       or p.path not like v_uid::text || '/gallery-%'
  ) then
    raise exception 'photo_owned_path';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_uid::text));
  if not exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'profile_not_found';
  end if;

  select coalesce(array_agg(pp.storage_path order by pp.position), '{}'::text[])
  into v_old_paths
  from public.profile_photos pp
  where pp.profile_id = v_uid;

  delete from public.profile_photos where profile_id = v_uid;

  insert into public.profile_photos(profile_id, storage_path, position)
  select v_uid, item.path, (item.ordinality - 1)::smallint
  from unnest(v_paths) with ordinality as item(path, ordinality);

  return v_old_paths;
end;
$$;

revoke all on function public.replace_gallery_photos(text[]) from public, anon;
grant execute on function public.replace_gallery_photos(text[]) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20260927080000', 'atomic_gallery_replace')
on conflict (version) do nothing;

commit;
