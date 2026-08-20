-- "Geç" denilen kişiler bir daha hiç görünmüyordu.
--
-- Keşif sorgusu, karar verilmiş herkesi eliyor: `not exists (select 1 from
-- reactions where actor_id = auth.uid() and subject_id = p.id)`. Beğeni için
-- doğru, ama "geç" için kalıcı bir karar olmamalı — kampüste toplam birkaç bin
-- kişi var ve bir kere sağa/sola kaydırmak kimseyi ömür boyu silmemeli.
--
-- İstemci bu kayıtları kendisi silemiyor: `reactions` tablosunda authenticated
-- rolünün yalnızca select yetkisi var (bilerek — kimse başkasının kararını
-- değiştirememeli). O yüzden silme işi bu fonksiyonun içinde.
--
-- Yalnızca 'pass' kayıtları siliniyor. Beğeniler duruyor, dolayısıyla eşleşmeler
-- ve mevcut sohbetler etkilenmiyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

create or replace function public.reset_my_passes()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  silinen integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.reactions
  where actor_id = auth.uid() and kind = 'pass';
  get diagnostics silinen = row_count;
  return silinen;
end;
$$;

revoke all on function public.reset_my_passes() from public, anon;
grant execute on function public.reset_my_passes() to authenticated;

commit;
