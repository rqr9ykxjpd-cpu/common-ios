-- Aynı sohbetten gelen ikinci, üçüncü mesajın push'u gitmiyordu.
--
-- notify_on_message, sohbette okunmamış bir mesaj bildirimi varsa yenisini
-- açmıyor, var olanın metnini ve zamanını tazeliyor (liste şişmesin diye).
-- Push tetikleyicisi ise yalnızca INSERT'te çalışıyordu. Sonuç: ilk mesajın
-- push'u geliyor, karşı taraf bildirimler ekranını açana kadar sonrakiler hiç
-- gelmiyordu; kullanıcıya "bildirimler geç geliyor" gibi görünüyordu.
--
-- Tazelenen (zamanı ileri alınan) okunmamış mesaj bildirimi de push gönderir.
-- send-push kaydın INSERT mi UPDATE mi olduğuna bakmıyor; başlık ve metin
-- güncel satırdan okunuyor. Okundu işaretlemek zamanı değiştirmediği için push
-- tetiklemez.
begin;

drop trigger if exists notifications_send_push_on_bump on public.notifications;
create trigger notifications_send_push_on_bump
after update of created_at on public.notifications
for each row
when (new.kind = 'message' and not new.is_read and new.created_at > old.created_at)
execute function public.push_on_notification();

insert into supabase_migrations.schema_migrations (version, name)
values ('20261002040000', 'message_push_on_bump')
on conflict (version) do nothing;

commit;
