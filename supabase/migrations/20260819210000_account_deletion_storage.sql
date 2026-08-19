-- Hesap silme de aynı sebeple kırıktı.
--
-- `delete_my_account` içinde şu vardı:
--   delete from storage.objects where bucket_id in (...) and ...
--
-- Bu, gönderi silmeyi bozan işlemin aynısı: Supabase depolama tablolarından
-- doğrudan silmeyi engelliyor ("Direct deletion from storage tables is not
-- allowed"). Yani "Hesabı kalıcı sil" düğmesi de hata verecekti — henüz kimse
-- denemediği için görünmemişti.
--
-- Dosya silme istemciye alınıyor: uygulama önce Storage API ile kullanıcının
-- klasörlerini boşaltıyor, sonra bu fonksiyonu çağırıyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  -- Depolama artık istemci tarafında, Storage API ile temizleniyor.
  -- Buradaki satır silme, `auth.users` üzerinden cascade ile tüm tabloları
  -- boşaltıyor.
  delete from auth.users where id = account_id;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

commit;
