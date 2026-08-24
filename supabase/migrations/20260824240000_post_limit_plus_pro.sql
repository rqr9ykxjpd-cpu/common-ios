-- 5 gönderi tavanı yalnızca ücretsiz planda. Plus ve Pro sınırsız.
-- Kurucu/moderatör plan_of ile zaten 'pro'.
-- Hata kodu QUOTA_POST: uygulama paywall açıyor.
--
-- Idempotent.

begin;

create or replace function public.enforce_post_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  kademe text;
  adet integer;
begin
  kademe := public.plan_of(new.author_id);
  if kademe in ('plus', 'pro') then
    return new;
  end if;

  select count(*) into adet
  from public.posts
  where author_id = new.author_id;

  if adet >= 5 then
    raise exception 'QUOTA_POST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_enforce_limit on public.posts;
create trigger posts_enforce_limit
before insert on public.posts
for each row execute function public.enforce_post_limit();

commit;
