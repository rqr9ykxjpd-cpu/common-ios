-- Sohbeti özelleştirme (kurucunun isteği, 15 Ekim): ortak tema ve hızlı tepki.
--
-- Tema ve çift dokunuş tepkisi sohbete (`matches`) ait; iki taraf da aynısını
-- görüyor. Değiştirmenin tek yolu `set_chat_style`: değeri doğruluyor,
-- kaydediyor ve sohbete bilgi satırı ekliyor (`messages.kind` 'theme' /
-- 'reaction', `style_value` yeni değer). Satır anlık kanaldan karşı tarafa
-- gidiyor; tema orada da hemen değişiyor. `body` Türkçe cümle ("Sohbet
-- temasını Gece mavisi yaptı."): eski sürümler satırı düz mesaj gibi
-- gösteriyor, okunur kalsın.
--
-- Bu satırlar bildirim üretmiyor (`messages_notify` yalnızca düz mesajda) ve
-- istemci onları doğrudan ekleyemiyor, sonradan değiştiremiyor. Tema adları
-- ve değerleri kart temalarıyla aynı (`profiles.card_theme`). Yazı boyutu
-- kişisel; telefonda tutuluyor, sunucuda yok.
--
-- Doğrudan güncelleme koruması canlıdaki tanımdan kopyalandı (20261011040000
-- ile aynı); kilitli alanlara `kind` ve `style_value` eklendi, bilgi
-- satırının metni düzenlenemiyor.
begin;

alter table public.matches
  add column if not exists chat_theme text not null default 'classic',
  add column if not exists quick_reaction text not null default '❤️';

alter table public.matches drop constraint if exists matches_chat_theme_check;
alter table public.matches add constraint matches_chat_theme_check check (chat_theme in
  ('classic', 'ink', 'navy', 'terracotta', 'raspberry', 'sage', 'lavender', 'rose', 'bubblegum', 'ocean'));

alter table public.matches drop constraint if exists matches_quick_reaction_check;
alter table public.matches add constraint matches_quick_reaction_check check (
  char_length(quick_reaction) between 1 and 16 and quick_reaction !~ '[[:alnum:][:space:]]');

alter table public.messages
  add column if not exists kind text not null default 'text',
  add column if not exists style_value text;

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check check (
  (kind = 'text' and style_value is null)
  or (kind in ('theme', 'reaction') and style_value is not null));

-- İstemci yalnızca düz mesaj ekleyebilir; bilgi satırı `set_chat_style`ten.
create or replace function public.messages_kind_guard()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
begin
  if current_user = 'authenticated' and (new.kind <> 'text' or new.style_value is not null) then
    raise exception 'MESSAGE_KIND_LOCKED';
  end if;
  return new;
end;
$function$;

drop trigger if exists messages_kind_guard on public.messages;
create trigger messages_kind_guard before insert on public.messages
for each row execute function public.messages_kind_guard();

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
     or new.shared_post_id is distinct from old.shared_post_id
     or new.kind is distinct from old.kind
     or new.style_value is distinct from old.style_value then
    raise exception 'MESSAGE_FIELD_LOCKED';
  end if;
  if old.kind <> 'text'
     and (new.body is distinct from old.body or new.edited_at is distinct from old.edited_at) then
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

-- Tema değişikliği "… sana mesaj gönderdi" bildirimi üretmesin.
drop trigger if exists messages_notify on public.messages;
create trigger messages_notify after insert on public.messages
for each row when (new.kind = 'text') execute function public.notify_on_message();

create or replace function public.set_chat_style(match_id uuid, kind text, value text)
 returns table (id uuid, body text, created_at timestamptz)
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  ben uuid := auth.uid();
  sohbet public.matches%rowtype;
  karsi uuid;
  deger text := btrim(coalesce(set_chat_style.value, ''));
  ad text;
  metin text;
  yeni public.messages%rowtype;
begin
  if ben is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into sohbet from public.matches m
   where m.id = set_chat_style.match_id
     and ben in (m.user_a, m.user_b)
     and m.unmatched_at is null
   for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;

  karsi := case when sohbet.user_a = ben then sohbet.user_b else sohbet.user_a end;
  if exists (
    select 1 from public.blocks b
     where (b.blocker_id = ben and b.blocked_id = karsi)
        or (b.blocker_id = karsi and b.blocked_id = ben)
  ) then
    raise exception 'BLOCKED';
  end if;

  -- Art arda değiştirip sohbeti bilgi satırıyla doldurmasın.
  if (select count(*) from public.messages x
       where x.match_id = sohbet.id and x.kind <> 'text'
         and x.created_at > now() - interval '1 hour') >= 20 then
    raise exception 'CHAT_STYLE_RATE_LIMIT';
  end if;

  if set_chat_style.kind = 'theme' then
    ad := case deger
      when 'classic' then 'Klasik' when 'ink' then 'Mürekkep' when 'navy' then 'Gece mavisi'
      when 'terracotta' then 'Kiremit' when 'raspberry' then 'Ahududu' when 'sage' then 'Adaçayı'
      when 'lavender' then 'Lavanta' when 'rose' then 'Gül' when 'bubblegum' then 'Pembe'
      when 'ocean' then 'Okyanus' end;
    if ad is null then raise exception 'CHAT_THEME_INVALID'; end if;
    if sohbet.chat_theme = deger then return; end if;
    update public.matches m set chat_theme = deger where m.id = sohbet.id;
    metin := 'Sohbet temasını ' || ad || ' yaptı.';
  elsif set_chat_style.kind = 'reaction' then
    if char_length(deger) not between 1 and 16 or deger ~ '[[:alnum:][:space:]]' then
      raise exception 'CHAT_REACTION_INVALID';
    end if;
    if sohbet.quick_reaction = deger then return; end if;
    update public.matches m set quick_reaction = deger where m.id = sohbet.id;
    metin := 'Hızlı tepkiyi ' || deger || ' yaptı.';
  else
    raise exception 'CHAT_STYLE_KIND_INVALID';
  end if;

  insert into public.messages (match_id, sender_id, body, kind, style_value)
  values (sohbet.id, ben, metin, set_chat_style.kind, deger)
  returning * into yeni;

  return query select yeni.id, yeni.body, yeni.created_at;
end;
$function$;

revoke all on function public.set_chat_style(uuid, text, text) from public, anon;
grant execute on function public.set_chat_style(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261015020000', 'chat_style')
on conflict (version) do nothing;

commit;
