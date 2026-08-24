-- Kişi başına en fazla 5 gönderi. Akış tavanı (100) herkese ait;
-- bu kural kullanıcının kendi paylaşımını sınırlar. Silince yer açılır.
-- İstemci de keser; tetikleyici atlatmayı kapatır.
--
-- Idempotent.

begin;

create or replace function public.enforce_post_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (
    select count(*) from public.posts
    where author_id = new.author_id
  ) >= 5 then
    raise exception 'POST_LIMIT';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_enforce_limit on public.posts;
create trigger posts_enforce_limit
before insert on public.posts
for each row execute function public.enforce_post_limit();

commit;
