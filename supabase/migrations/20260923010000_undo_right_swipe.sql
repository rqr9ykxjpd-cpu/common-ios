-- Sağa kaydırmayı geri alma (Build 6).
--
-- Kart destesinde yanlışlıkla sağa kaydırmak kolay; şimdiye kadar geri dönüşü
-- yoktu ve karşı tarafa bildirim gitmiş oluyordu. Bu RPC, kaydırmadan sonraki
-- kısa pencere içinde hem satırı hem de tetiklediği bildirimi siler.
--
-- Kurallar:
-- - Yalnızca kendi kaydırmanı geri alabilirsin.
-- - Karşılıklı olup eşleşme (match) doğduysa geri alınmaz: artık iki taraflı.
-- - Pencere 2 dakika: "yanlışlıkla" makul süresi; sonrasında kalıcı.
begin;

create or replace function public.undo_right_swipe(target uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  silindi integer;
begin
  if target is null or target = auth.uid() then
    return false;
  end if;

  -- Eşleşme varsa dokunma: karşı taraf da kaydırmış demektir.
  if exists (
    select 1 from public.matches m
    where (m.user_a = auth.uid() and m.user_b = target)
       or (m.user_a = target and m.user_b = auth.uid())
  ) then
    return false;
  end if;

  delete from public.profile_right_swipes s
   where s.actor_id = auth.uid()
     and s.subject_id = target
     and s.created_at > now() - interval '2 minutes';
  get diagnostics silindi = row_count;
  if silindi = 0 then
    return false;
  end if;

  -- Tetikleyicinin karşı tarafa bıraktığı bildirimi de kaldır; okunmuşsa bile
  -- yanlışlıkla gönderilmiş bir bildirimi listede bırakmanın anlamı yok.
  delete from public.notifications n
   where n.user_id = target
     and n.actor_id = auth.uid()
     and n.kind = 'like'
     and n.created_at > now() - interval '2 minutes';

  return true;
end;
$$;

revoke all on function public.undo_right_swipe(uuid) from public, anon;
grant execute on function public.undo_right_swipe(uuid) to authenticated;

-- Geri alma satırı silebilsin diye tablo üzerinde delete hakkı gerekmiyor:
-- fonksiyon security definer. Tablo hakları olduğu gibi kalıyor.

commit;
