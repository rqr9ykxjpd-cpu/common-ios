-- Yorum oyları, gönderiyle aynı kurucu araçları:
-- - Kullanıcı kendi yorumuna oy veremez (eski kural); kurucu verebilir.
-- - Kurucu yoruma istediği kadar oy ekler (boost), gönderideki boost_post gibi.
--   Görünen puan = score + boost; kimin verdiği yine gizli.
begin;

drop policy if exists "users manage own comment votes" on public.comment_votes;
create policy "users manage own comment votes" on public.comment_votes
for all to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and (
    public.is_founder()
    or not exists (
      select 1 from public.comments c
      where c.id = comment_id and c.author_id = auth.uid()
    )
  )
);

alter table public.comments add column if not exists boost integer not null default 0;

create or replace function public.boost_comment(target uuid, extra integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare yeni integer;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.comments set boost = greatest(0, boost + extra) where id = target
    returning boost into yeni;
  if yeni is null then raise exception 'Comment not found'; end if;
  return yeni;
end;
$$;
revoke all on function public.boost_comment(uuid, integer) from public, anon;
grant execute on function public.boost_comment(uuid, integer) to authenticated;

-- Yoruma kim ne oy vermiş: yalnızca kurucu/moderatör (get_post_voters gibi).
create or replace function public.get_comment_voters(target uuid)
returns table (id uuid, name text, avatar_path text, value smallint, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_moderator() then raise exception 'STAFF_ONLY'; end if;
  return query
    select p.id, p.name, p.avatar_path, v.value::smallint, v.created_at
    from public.comment_votes v join public.profiles p on p.id = v.user_id
    where v.comment_id = target
    order by v.created_at desc;
end;
$$;
revoke all on function public.get_comment_voters(uuid) from public, anon;
grant execute on function public.get_comment_voters(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914130000', 'comment_boost_and_founder_self_vote') on conflict (version) do nothing;

commit;
