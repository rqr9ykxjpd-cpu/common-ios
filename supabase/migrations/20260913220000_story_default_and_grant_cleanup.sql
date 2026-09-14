-- İki temizlik:
-- - stories.expires_at varsayılanı istemcinin gönderdiği 10 saatle hizalanır
--   (istemci hep açık gönderiyor; varsayılan yalnızca elle eklenen satır için).
-- - Supabase'in varsayılan "grant all" izinlerinden kalan TRUNCATE / REFERENCES /
--   TRIGGER yetkileri uygulama rollerinden alınır. RLS TRUNCATE'i durdurmaz.

begin;

alter table public.stories alter column expires_at set default now() + interval '10 hours';

revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke truncate, references, trigger on tables from anon, authenticated;

commit;
