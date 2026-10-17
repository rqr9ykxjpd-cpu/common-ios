-- "Teslim Edildi", iPhone Mesajlar'daki gibi (kurucunun kararı, 17 Ekim:
-- "ımessagede apple bunu nasıl yapıyorsa bizde öyle yapalım"; okundu
-- gösterilmeyecek).
--
-- * Mesaj alıcının uygulamasına ulaşınca `delivered_at` dolar; gönderen son
--   mesajının altında "Teslim Edildi" görür. Okunan mesaj teslim de
--   edilmiştir: uygulama `delivered_at` boşsa `read_at`e bakar, eski sürümler
--   yalnızca okundu yazdığı için.
-- * Yalnızca alıcı, yalnızca `mark_messages_delivered()` ile işaretler;
--   doğrudan güncelleme (gönderen de alıcı da) `delivered_at`i değiştiremez.
-- * Eski sürümler bu sütunu seçmiyor; etkilenmezler.
begin;

alter table public.messages add column if not exists delivered_at timestamptz;
create index if not exists messages_undelivered_idx
  on public.messages (match_id) where delivered_at is null;

-- Canlıdaki tanım (17 Ekim) + delivered_at kilidi.
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
or new.style_value is distinct from old.style_value
or new.delivered_at is distinct from old.delivered_at then
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

-- Bana gelen, henüz işaretlenmemiş mesajlar teslim alındı. Uygulama sohbetleri
-- yükleyince ve anlık kanaldan mesaj gelince çağırıyor. Kaç satır işaretlendi.
create or replace function public.mark_messages_delivered()
returns integer
language sql
security definer
set search_path = ''
as $$
  with isaretlenen as (
    update public.messages m
       set delivered_at = now()
     where m.delivered_at is null
       and m.sender_id <> auth.uid()
       and m.match_id in (
         select x.id from public.matches x
          where x.unmatched_at is null
            and (x.user_a = auth.uid() or x.user_b = auth.uid())
       )
    returning 1
  )
  select count(*)::integer from isaretlenen;
$$;
revoke all on function public.mark_messages_delivered() from public, anon;
grant execute on function public.mark_messages_delivered() to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261018020000', 'message_delivered')
on conflict (version) do nothing;

commit;
