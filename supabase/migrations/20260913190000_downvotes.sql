-- Aşağı ok: gönderi ve cevap oyları yön taşır. value +1 yukarı, -1 aşağı;
-- puan = toplam. Eski satırlar +1 sayılır. Oy yönü değiştirmek için update
-- izni gerekir (upsert). Bildirim yalnızca yukarı oyda düşer ve artık
-- "beğendi" değil "oy verdi" der.

begin;

alter table public.post_likes
  add column if not exists value smallint not null default 1;
alter table public.post_likes drop constraint if exists post_likes_value_check;
alter table public.post_likes add constraint post_likes_value_check check (value in (-1, 1));
grant update on public.post_likes to authenticated;

alter table public.comment_votes
  add column if not exists value smallint not null default 1;
alter table public.comment_votes drop constraint if exists comment_votes_value_check;
alter table public.comment_votes add constraint comment_votes_value_check check (value in (-1, 1));
grant update on public.comment_votes to authenticated;

create or replace function public.notify_on_post_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid;
begin
  if new.value <> 1 then return new; end if;
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  if exists (
    select 1 from public.notifications n
    where n.user_id = owner_id and n.kind = 'like' and n.post_id = new.post_id and n.actor_id = new.user_id
  ) then
    return new;
  end if;
  insert into public.notifications (user_id, kind, title, body, actor_id, post_id)
  values (owner_id, 'like',
    public.profile_display_name(new.user_id) || ' gönderine oy verdi', '', new.user_id, new.post_id);
  return new;
end;
$$;

commit;
