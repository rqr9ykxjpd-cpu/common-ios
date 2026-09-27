-- Mesaj tepkileri kişiye özel + mesaj satırı doğrudan güncellemede korunuyor (Build 6).
--
-- 1) Tepkiler. Eskiden mesajda tek bir `reaction` alanı vardı ve kimin koyduğu
--    tutulmuyordu: tepkiye kim dokunursa kaldırabiliyordu, iki kişi tepki
--    verince ikincisi birincisini siliyordu. Her mesajın iki tarafı var:
--    - `reaction`        : mesajı alan kişinin tepkisi (eski alan, anlamı bu),
--    - `sender_reaction` : gönderenin kendi mesajına tepkisi (yeni).
--    `set_message_reaction` imzası aynı; çağıranı kendi alanına yazar. Build 5
--    aynı fonksiyonu çağırdığı için çalışmaya devam eder.
--
-- 2) Doğrudan güncelleme. `messages` tablosunda tablo düzeyinde UPDATE izni
--    açık kalmıştı ve "recipients mark messages read" kuralı sütuna bakmıyor:
--    alıcı, uygulamayı atlayıp gönderenin mesaj metnini değiştirebiliyordu.
--    Tetikleyici doğrudan güncellemede yalnızca şunlara izin veriyor:
--    - gönderen: body, edited_at (mesaj düzenleme; Build 5 dahil),
--    - alıcı:    read_at (okundu işareti; Build 5 dahil).
--    Tepkiler yalnızca `set_message_reaction` (security definer) ile değişir.
begin;

alter table public.messages add column if not exists sender_reaction text;
alter table public.messages drop constraint if exists messages_sender_reaction_len;
alter table public.messages add constraint messages_sender_reaction_len
  check (sender_reaction is null or char_length(sender_reaction) <= 16);
grant select (sender_reaction) on public.messages to authenticated;

create or replace function public.set_message_reaction(message_uuid uuid, reaction text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  istenen text := nullif(btrim(coalesce(reaction, '')), '');
  gonderen uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if istenen is not null and char_length(istenen) > 16 then raise exception 'Reaction is too long'; end if;
  select m.sender_id into gonderen
    from public.messages m
   where m.id = message_uuid and public.is_match_member(m.match_id);
  if not found then raise exception 'Message unavailable'; end if;
  if gonderen = auth.uid() then
    update public.messages set sender_reaction = istenen where id = message_uuid;
  else
    update public.messages set reaction = istenen where id = message_uuid;
  end if;
end;
$$;
revoke all on function public.set_message_reaction(uuid, text) from public, anon;
grant execute on function public.set_message_reaction(uuid, text) to authenticated;

-- Doğrudan (REST) güncellemede sütun kuralı. Security definer fonksiyonlar
-- sahibin rolüyle çalıştığı için `current_user` onlarda 'authenticated' değil;
-- kural yalnızca istemcinin doğrudan yazdığı satırlara uygulanıyor.
create or replace function public.messages_guard_direct_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user <> 'authenticated' then return new; end if;
  if new.id is distinct from old.id
     or new.match_id is distinct from old.match_id
     or new.sender_id is distinct from old.sender_id
     or new.reply_to_id is distinct from old.reply_to_id
     or new.created_at is distinct from old.created_at
     or new.reaction is distinct from old.reaction
     or new.sender_reaction is distinct from old.sender_reaction then
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
$$;
drop trigger if exists messages_guard_direct_update on public.messages;
create trigger messages_guard_direct_update before update on public.messages
for each row execute function public.messages_guard_direct_update();

commit;
