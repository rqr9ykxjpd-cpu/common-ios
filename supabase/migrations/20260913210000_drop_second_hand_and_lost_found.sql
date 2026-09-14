-- "İkinci el" ve "Kayıp/Buluntu" türleri kaldırıldı (ürün kararı, 2026-09-13).
-- Sunucuda o türde satır yok (özellik hiç yayınlanmadı); olsa da düz paylaşıma döner.

begin;

update public.posts set kind = 'moment' where kind in ('second_hand', 'lost_found');

alter table public.posts drop constraint if exists posts_kind_check;
alter table public.posts add constraint posts_kind_check
  check (kind in ('moment', 'question', 'announcement', 'notes'));

commit;
