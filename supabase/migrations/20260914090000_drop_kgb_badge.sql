-- "KGB Tarihi" rozeti kaldırıldı.

begin;

update public.posts set kind = 'moment' where kind = 'kgb_history';

alter table public.posts drop constraint if exists posts_kind_check;
alter table public.posts add constraint posts_kind_check
  check (kind in (
    'moment',
    'question', 'announcement', 'notes', 'help', 'event', 'poll', 'agenda',
    'sports', 'music', 'film', 'games', 'food', 'art', 'literature', 'science',
    'nature', 'health', 'history', 'philosophy', 'culture',
    'photo', 'life_story', 'instant', 'serious', 'flood',
    'ataturk', 'aga_beee', 'bele', 'ahraz'
  ));

commit;
