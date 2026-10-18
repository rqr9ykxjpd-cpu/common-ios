-- Notlar paylaşılamıyordu ("buna yetkiniz yok", 18 Ekim). `posts`a ekleme
-- kolon bazlı izinle yapılıyor (20260913200000, 20261003040000) ve notların
-- sütunlarına (bölüm 20261017020000, ders/PDF/sayfa 20261018010000) ekleme
-- izni verilmemişti. Sütunların kuralları (uzunluk, PDF yalnızca notta ve
-- yazarın klasöründe, sayfa 1-500) ve içerik filtresi aynen geçerli.
begin;

grant insert (department, course, document_path, page_count) on public.posts to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261018030000', 'notes_insert_grant')
on conflict (version) do nothing;

commit;
