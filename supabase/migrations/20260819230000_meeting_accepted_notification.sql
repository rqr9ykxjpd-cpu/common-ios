-- Buluşma isteği kabul edilince gönderenin haberi olmuyordu.
--
-- `meeting_requests` üzerindeki bildirim tetikleyicisi yalnızca `after insert`
-- çalışıyor: alıcı isteği görüyor, ama kabul ettiğinde gönderene hiçbir şey
-- gitmiyor. Gönderenin öğrenmesinin tek yolu "Buluşma istekleri" ekranını
-- açmayı akıl etmesi. Aynı yerde, o an buluşmaya yarayan bir özellik için bu,
-- özelliği işlevsiz bırakıyor: karşı taraf kabul edip beklerken gönderen çoktan
-- oradan ayrılmış oluyor.
--
-- Reddedilme bilerek bildirilmiyor. İstek göndermenin eşiğini düşüren şey,
-- reddedilirse karşı tarafın bunu öğrenmeyecek olması; uygulama da kullanıcıya
-- bunu vaat ediyor.
--
-- Yeni bir enum değeri EKLENMİYOR. `notification_kind` üzerinde `alter type ...
-- add value` çalıştırmak, migration'ın tamamı tek işlemde koştuğu için riskli
-- (eklenen değer aynı işlem içinde kullanılamaz). Mevcut 'meeting_request'
-- değeri yeniden kullanılıyor; arayüz bu türü zaten tanıyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

create or replace function public.notify_on_meeting_accepted()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  place_label text;
begin
  select name into place_label from public.places where id = new.place_id;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (new.requester_id, 'meeting_request',
    public.profile_display_name(new.recipient_id) || ' buluşmayı kabul etti',
    coalesce(place_label, 'Kampüs') || ' için buluşmanız onaylandı.',
    new.recipient_id);
  return new;
end;
$$;

drop trigger if exists meeting_requests_accepted_notify on public.meeting_requests;
create trigger meeting_requests_accepted_notify
after update of status on public.meeting_requests
for each row
when (new.status = 'accepted' and old.status is distinct from 'accepted')
execute function public.notify_on_meeting_accepted();

commit;
