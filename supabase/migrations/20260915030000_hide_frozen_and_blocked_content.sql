-- Dondurulan ve engellenen hesapların içeriği okuma tarafında gizlenir.
--
-- Gönderi ve cevap okuma politikası `using (true)` idi. Dondurma diyaloğu
-- "akışta görünmez" diyordu ama dondurulan hesabın gönderileri akışta duruyordu;
-- engelleme de yalnızca istemci listesinden siliyordu, akış yenilenince
-- gönderiler geri geliyordu (App Store 1.2: engellenen kişinin içeriği
-- görünmemeli). Story politikası engeli kontrol ediyordu ama `blocks` RLS'i
-- yalnızca engelleyenin satırını gösterdiği için "beni engelledi" dalı hiç
-- eşleşmiyordu.
--
-- Tek bir security definer yardımcı: hesap pasifse ya da iki yönlü engel
-- varsa içerik gizli. Security definer olduğu için `profiles` politikasının
-- (post yazarları görünür) bu politikaya geri dönmesiyle oluşacak döngüye de
-- girmez. Kişinin kendi içeriği her zaman görünür.

begin;

create or replace function public.content_hidden(author uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select author <> auth.uid() and (
    not exists (select 1 from public.profiles p where p.id = author and p.is_active)
    or exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = author)
         or (b.blocker_id = author and b.blocked_id = auth.uid())
    )
  );
$$;
revoke all on function public.content_hidden(uuid) from public, anon;
grant execute on function public.content_hidden(uuid) to authenticated;

drop policy if exists "authenticated users view posts" on public.posts;
create policy "authenticated users view posts" on public.posts
for select to authenticated
using (not public.content_hidden(author_id));

drop policy if exists "authenticated users view comments" on public.comments;
create policy "authenticated users view comments" on public.comments
for select to authenticated
using (not public.content_hidden(author_id));

drop policy if exists "authenticated read active stories" on public.stories;
create policy "authenticated read active stories" on public.stories
for select to authenticated
using (expires_at > now() and not public.content_hidden(author_id));

commit;
