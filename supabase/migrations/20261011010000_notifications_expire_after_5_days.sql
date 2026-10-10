-- Bildirimler 5 gün sonra kendiliğinden silinir (kurucunun isteği).
--
-- Bildirimler hiç silinmiyordu; kullanıcı ve bildirim arttıkça tablo durmadan
-- büyüyecekti. Her saat başı (15. dakika) 5 günden eski bildirimler silinir.
-- Mesaj bildiriminde süre son mesajdan sayılır (her yeni mesaj satırın
-- zamanını yeniler). Okunmuş ya da okunmamış fark etmez.
-- İlk çalışmada mevcut 5 günden eski bildirimler de silinir (11 Ekim'de 135).
-- Bildirimlere bağlı başka tablo yok (yabancı anahtar yok).
begin;

create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.purge_old_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  silinen integer;
begin
  delete from public.notifications
   where created_at < now() - interval '5 days';
  get diagnostics silinen = row_count;
  return silinen;
end;
$$;
revoke all on function public.purge_old_notifications() from public, anon, authenticated;

-- Aynı adla tekrar çalıştırılırsa iş güncellenir, ikinci kopya oluşmaz.
select cron.schedule(
  'purge-old-notifications',
  '15 * * * *',
  $cron$select public.purge_old_notifications();$cron$
);

insert into supabase_migrations.schema_migrations (version, name)
values ('20261011010000', 'notifications_expire_after_5_days')
on conflict (version) do nothing;

commit;
