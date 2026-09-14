-- Akışa kampüs gönderi türleri: Soru, Duyuru, Kayıp/Buluntu, İkinci el, Ders notu.
-- (İkinci el ve Kayıp/Buluntu 20260913210000 ile kaldırıldı.)
-- Düz paylaşım 'moment' varsayılan; eski satırlar dokunulmadan bu değeri alır.
-- İstemcideki `PostKind` aynı ham değerleri taşır.

begin;

alter table public.posts
  add column if not exists kind text not null default 'moment';

alter table public.posts drop constraint if exists posts_kind_check;
alter table public.posts add constraint posts_kind_check
  check (kind in ('moment', 'question', 'announcement', 'lost_found', 'second_hand', 'notes'));

-- Tür filtresi: "sadece sorular" gibi sorgular created_at sırasıyla okunur.
create index if not exists posts_kind_created_idx on public.posts (kind, created_at desc);

commit;
