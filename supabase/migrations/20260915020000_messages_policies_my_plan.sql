-- Mesaj UPDATE/DELETE'in tamamı 403 dönüyordu: okundu işaretleme dâhil.
--
-- 20260913120000 düzenle/sil politikalarına `plan_of(auth.uid())` koydu; ama
-- `plan_of`'un EXECUTE yetkisi authenticated'dan alınmış. İzin verici
-- politikalar OR'landığı için Postgres her UPDATE'te bu ifadeyi de değerlendiriyor
-- ve "permission denied for function plan_of" ile bütün güncellemeyi reddediyordu:
-- karşı tarafın mesajı hiç okundu olmuyordu, rozet hiç sıfırlanmıyordu; Plus/Pro
-- mesaj düzenleme ve silme de aynı hatayla düşüyordu.
--
-- `my_plan()` security definer ve authenticated'a açık; aynı cevabı verir.

begin;

drop policy if exists "senders edit own messages" on public.messages;
create policy "senders edit own messages" on public.messages
for update to authenticated
using (
  sender_id = auth.uid()
  and public.is_match_member(match_id)
  and public.my_plan() in ('plus', 'pro')
)
with check (
  sender_id = auth.uid()
  and public.is_match_member(match_id)
  and public.my_plan() in ('plus', 'pro')
);

drop policy if exists "senders delete own messages" on public.messages;
create policy "senders delete own messages" on public.messages
for delete to authenticated
using (
  sender_id = auth.uid()
  and public.is_match_member(match_id)
  and public.my_plan() in ('plus', 'pro')
);

commit;
