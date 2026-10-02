-- Sohbeti temizle: mesajlar yalnızca temizleyenden silinir.
--
-- Satırlar silinmiyor (karşı taraf kendi geçmişini görmeye devam ediyor);
-- kişi başına "şu andan öncesini gösterme" damgası tutuluyor. Uygulama bu
-- damgadan önceki mesajları ve okunmamış sayısını göstermiyor. Bağlantı
-- kaldırılırken de aynı damga atılıyor: ileride yeniden bağlanırsanız eski
-- konuşma geri gelmiyor. O sohbetin bildirimleri de silinen tarafta kalkıyor.
begin;

create table if not exists public.conversation_clears (
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  cleared_at timestamptz not null default now(),
  primary key (user_id, match_id)
);
alter table public.conversation_clears enable row level security;
revoke all on public.conversation_clears from public, anon, authenticated;
grant select on public.conversation_clears to authenticated;
drop policy if exists "users see own clears" on public.conversation_clears;
create policy "users see own clears" on public.conversation_clears
  for select to authenticated using (user_id = auth.uid());

create or replace function public.clear_conversation(target_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.matches m
    where m.id = target_match and (m.user_a = auth.uid() or m.user_b = auth.uid())
  ) then
    raise exception 'Conversation unavailable';
  end if;
  insert into public.conversation_clears (user_id, match_id, cleared_at)
  values (auth.uid(), target_match, now())
  on conflict (user_id, match_id) do update set cleared_at = excluded.cleared_at;
  delete from public.notifications
  where user_id = auth.uid() and match_id = target_match;
end;
$$;
revoke all on function public.clear_conversation(uuid) from public, anon;
grant execute on function public.clear_conversation(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261002080000', 'conversation_clear')
on conflict (version) do nothing;

commit;
