-- Video story 35 saniyeye kadar (eskiden 15).
--
-- 1.1.2 videoyu 35 sn'ye kadar kesip yüklüyor. Eski sürümler hâlâ 15 sn'de
-- kesiyor; uzun videoyu da ilk 15 sn'sini oynatıp geçiyor, kırılmıyor.
-- Dosya sınırı (30 MB) yeterli: 960x540 klip 35 sn'de ~10–15 MB.
begin;

alter table public.stories drop constraint if exists stories_video_fields;
alter table public.stories
  add constraint stories_video_fields check (
    (media_kind = 'image'
      and duration_ms is null
      and poster_path is null)
    or (media_kind = 'video'
      and duration_ms between 1 and 35000
      and poster_path is not null
      and poster_path like author_id::text || '/%')
  );

insert into supabase_migrations.schema_migrations (version, name)
values ('20261005010000', 'story_video_35s')
on conflict (version) do nothing;

commit;
