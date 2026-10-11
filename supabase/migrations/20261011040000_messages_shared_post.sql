-- Gönderiyi mesajla gönderme (kurucunun isteği, 1.1.4 / build 17).
--
-- Gönderinin kâğıt uçak düğmesi artık bağlantılarından birine gönderiyi
-- sohbet mesajı olarak yolluyor; karşı taraf mesaja dokununca gönderi açılıyor.
-- Yalnızca mevcut sohbetlere gidiyor: mesajlaşma zaten bağlantıya bağlı ve
-- "members send as themselves" kuralı aynen geçerli. Bağlantısız birine
-- gönderi yollamak yeni bir istenmeyen mesaj yolu açmak olurdu.
--
-- `body` dolu kalıyor ("Bir gönderi paylaştı."): eski sürümler, sohbet listesi
-- ve bildirim onu gösteriyor. Gönderi silinirse alan boşalır; yeni sürüm
-- "Bu gönderi artık yok" der. Gönderiyi kimin görebileceği değişmiyor:
-- alıcı gönderiyi `posts` okuma kuralıyla getiriyor (gizlenen/engelleyen
-- yazarın gönderisi açılmaz).
--
-- `messages` tablosunda `authenticated` için tablo düzeyinde yetki var
-- (11 Ekim'de canlıda bakıldı); yeni sütun için ayrıca grant gerekmiyor.
-- Doğrudan güncelleme koruması canlıdaki tanımdan (gövde md5 6cdec1b4…) kopyalandı,
-- yalnızca `shared_post_id` kilitli alanlara eklendi. Gönderi silinince
-- yapılan `on delete set null` güncellemesi tablo sahibi rolüyle çalışıyor;
-- koruma onu durdurmuyor.
begin;

alter table public.messages
  add column if not exists shared_post_id uuid references public.posts(id) on delete set null;

-- Gönderi silinirken bağlı mesajlar bu indeksle bulunuyor.
create index if not exists messages_shared_post_id_idx
  on public.messages (shared_post_id)
  where shared_post_id is not null;

create or replace function public.messages_guard_direct_update()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
begin
  if current_user <> 'authenticated' then return new; end if;
  if new.id is distinct from old.id
     or new.match_id is distinct from old.match_id
     or new.sender_id is distinct from old.sender_id
     or new.reply_to_id is distinct from old.reply_to_id
     or new.created_at is distinct from old.created_at
     or new.reaction is distinct from old.reaction
     or new.sender_reaction is distinct from old.sender_reaction
     or new.shared_post_id is distinct from old.shared_post_id then
    raise exception 'MESSAGE_FIELD_LOCKED';
  end if;
  if old.sender_id = auth.uid() then
    if new.read_at is distinct from old.read_at then raise exception 'MESSAGE_FIELD_LOCKED'; end if;
  else
    if new.body is distinct from old.body or new.edited_at is distinct from old.edited_at then
      raise exception 'MESSAGE_FIELD_LOCKED';
    end if;
  end if;
  return new;
end;
$function$;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261011040000', 'messages_shared_post')
on conflict (version) do nothing;

commit;
