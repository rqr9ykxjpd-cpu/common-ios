-- Notlar, ikinci hâl (kurucunun isteği, 17 Ekim: "notlar kısmı çok kötü
-- olmuş… rahat ders çalışılabilinsin… pdf filanda yüklenebilinsin").
--
-- * Notta ders (`course`), sayfa sayısı (`page_count`) ve PDF (`document_path`).
--   PDF'li notta ilk sayfanın resmi `media_path`e yazılır: akışta ve eski
--   sürümlerde not, ilk sayfasıyla görünür.
-- * Notta en fazla 20 fotoğraf (diğer gönderilerde 6 aynen).
-- * PDF'ler ayrı, gizli `note-files` alanında (25 MB, yalnızca PDF). Okuma
--   kuralı gönderi fotoğraflarıyla aynı (`can_read_media`): sahibi ya da
--   engellenmemiş, aktif bir öğrenci; dosya bir nota bağlı olmalı.
-- * Arama: ders, konu ya da bölümde geçen notlar (`security invoker`, RLS aynen).
begin;

alter table public.posts add column if not exists course text;
alter table public.posts add column if not exists document_path text;
alter table public.posts add column if not exists page_count smallint;
alter table public.posts drop constraint if exists posts_course_check;
alter table public.posts add constraint posts_course_check
  check (course is null or char_length(btrim(course)) between 1 and 60);
alter table public.posts drop constraint if exists posts_document_path_check;
alter table public.posts add constraint posts_document_path_check
  check (document_path is null or (kind = 'notes' and document_path like (author_id::text || '/%')));
alter table public.posts drop constraint if exists posts_page_count_check;
alter table public.posts add constraint posts_page_count_check
  check (page_count is null or page_count between 1 and 500);

-- Notta 20 fotoğraf; diğer gönderilerde 6.
alter table public.posts drop constraint if exists post_media_paths_valid;
alter table public.posts add constraint post_media_paths_valid check (
  media_paths is null or (
    cardinality(media_paths) >= 1
    and cardinality(media_paths) <= case when kind = 'notes' then 20 else 6 end
    and not (media_path is distinct from media_paths[1])
    and public.paths_owned_by(media_paths, author_id)
  )
);

-- İçerik filtresi ders adına da bakar.
drop trigger if exists content_text_safety on public.posts;
create trigger content_text_safety
before insert or update of caption, place_name, department, course on public.posts
for each row execute function public.check_content_text_before_write('caption', 'place_name', 'department', 'course');

-- PDF alanı.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('note-files', 'note-files', false, 26214400, array['application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = 26214400, allowed_mime_types = array['application/pdf'];

drop policy if exists "users upload own note files" on storage.objects;
create policy "users upload own note files" on storage.objects
for insert to authenticated
with check (bucket_id = 'note-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "users delete own note files" on storage.objects;
create policy "users delete own note files" on storage.objects
for delete to authenticated
using (bucket_id = 'note-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "members read permitted note files" on storage.objects;
create policy "members read permitted note files" on storage.objects
for select to authenticated
using (
  bucket_id = 'note-files'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and public.can_read_media(((storage.foldername(name))[1])::uuid, bucket_id, name)
);

-- Canlıdaki tanım (17 Ekim) + not dosyaları.
create or replace function public.can_read_media(owner_uuid uuid, media_bucket text, media_name text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select owner_uuid = auth.uid() or (
    exists (select 1 from public.profiles reader where reader.id = auth.uid() and reader.is_active)
    and not exists (
      select 1 from public.blocks b
       where (b.blocker_id = auth.uid() and b.blocked_id = owner_uuid)
          or (b.blocker_id = owner_uuid and b.blocked_id = auth.uid())
    )
    and (
      (media_bucket = 'post-media' and exists (
        select 1 from public.posts p
         where p.author_id = owner_uuid and (p.media_path = media_name or media_name = any(p.media_paths))
      ))
      or (media_bucket = 'note-files' and exists (
        select 1 from public.posts p
         where p.author_id = owner_uuid and p.kind = 'notes' and p.document_path = media_name
      ))
      or (media_bucket = 'story-media' and exists (
        select 1 from public.stories s
         where s.author_id = owner_uuid and s.expires_at > now()
           and (s.media_path = media_name or s.poster_path = media_name)
      ))
      or (media_bucket = 'profile-photos' and exists (
        select 1 from public.profiles p where p.id = owner_uuid and p.is_verified and p.is_active
      ))
      or exists (
        select 1 from public.matches m
         where m.unmatched_at is null
           and ((m.user_a = auth.uid() and m.user_b = owner_uuid) or (m.user_b = auth.uid() and m.user_a = owner_uuid))
      )
    )
  );
$function$;

-- Notlarda arama: ders, konu ya da bölüm.
create or replace function public.search_note_ids(q text)
returns setof uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id
    from public.posts p
    left join public.profiles pr on pr.id = p.author_id
   where p.kind = 'notes'
     and char_length(btrim(search_note_ids.q)) >= 2
     and (p.caption ilike '%' || btrim(search_note_ids.q) || '%'
          or p.course ilike '%' || btrim(search_note_ids.q) || '%'
          or coalesce(nullif(btrim(p.department), ''), pr.department) ilike '%' || btrim(search_note_ids.q) || '%')
   order by p.created_at desc
   limit 60;
$$;
revoke all on function public.search_note_ids(text) from public, anon;
grant execute on function public.search_note_ids(text) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261018010000', 'notes_v2')
on conflict (version) do nothing;

commit;
