-- Eşleşmeden yanıt yazabilme: "yanıt isteği".
--
-- Mesajlaşma eşleşmeye bağlı ve bu veritabanı seviyesinde zorunlu. Şartı
-- tamamen kaldırmak "herkes herkese yazabilir" demekti; tanışma uygulamalarında
-- bunun karşılığı istenmeyen mesaj yağmuru ve kadın kullanıcıların uygulamayı
-- bırakması oluyor. Ayrıca Tanış'ın ve beğeni hakkının değeri sıfırlanırdı.
--
-- Ara yol: eşleşmeden yazılan mesaj doğrudan sohbete düşmüyor, karşı tarafa bir
-- istek olarak gidiyor. Kabul edilirse eşleşme kuruluyor ve ilk mesaj sohbete
-- yazılıyor; reddedilirse gönderene bildirim gitmiyor.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'message_request_status') then
    create type public.message_request_status as enum ('pending', 'accepted', 'declined');
  end if;
end $$;

create table if not exists public.message_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  story_id uuid references public.stories(id) on delete set null,
  status public.message_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

-- Aynı kişiye bekleyen ikinci bir istek gönderilemez: ısrarlı mesajın önü
-- kapalı olmalı.
create unique index if not exists message_requests_pending_idx
  on public.message_requests (sender_id, recipient_id)
  where status = 'pending';

alter table public.message_requests enable row level security;

drop policy if exists "parties read message requests" on public.message_requests;
create policy "parties read message requests" on public.message_requests
for select to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

-- Gönderen yalnızca kendi adına ve engelli olmadığı birine yazabilir.
drop policy if exists "senders create message requests" on public.message_requests;
create policy "senders create message requests" on public.message_requests
for insert to authenticated
with check (
  sender_id = auth.uid()
  and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = recipient_id)
       or (b.blocker_id = recipient_id and b.blocked_id = auth.uid())
  )
);

-- Durumu yalnızca alıcı değiştirebilir, o da yalnızca reddetmek için.
-- 'accepted' bilerek dışarıda: kabul, eşleşmeyi kurup ilk mesajı sohbete yazan
-- `accept_message_request` fonksiyonunun işi. Doğrudan yazılabilseydi istek
-- "kabul edildi" görünürken ortada ne eşleşme ne de mesaj olurdu; gönderen
-- kabul edildiğini görüp açacak bir sohbet bulamazdı. Fonksiyon security
-- definer olduğu için bu kısıt onu engellemiyor.
drop policy if exists "recipients answer message requests" on public.message_requests;
create policy "recipients answer message requests" on public.message_requests
for update to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid() and status <> 'accepted');

revoke all on public.message_requests from anon;
grant select, insert on public.message_requests to authenticated;
grant update (status, updated_at) on public.message_requests to authenticated;

-- Reddedilen bir daha yazamaz ve kimse gün boyu istek yağdıramaz.
--
-- Bekleyen ikinci isteği yukarıdaki tekil indeks engelliyor ama tek başına
-- yetmiyordu: reddedilen kişi tekrar tekrar gönderebiliyor, ısrarcı biri de
-- yüzlerce farklı kişiye yazabiliyordu. Eşleşme şartını gevşetmemizin sebebi
-- utangaç kullanıcıydı; ısrarcı kullanıcıya kapı açmak değil.
--
-- Bu sınır kademeye bağlı DEĞİL: Pro olmak ısrar etme hakkı satın almak
-- olmamalı. Günlük 10, normal kullanımın çok üstünde bir tavan.
create or replace function public.guard_message_request()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  gunluk integer;
begin
  if exists (
    select 1 from public.message_requests
    where sender_id = new.sender_id
      and recipient_id = new.recipient_id
      and status = 'declined'
  ) then
    raise exception 'MESSAGE_REQUEST_DECLINED' using errcode = 'check_violation';
  end if;

  select count(*) into gunluk
  from public.message_requests
  where sender_id = new.sender_id and created_at > now() - interval '24 hours';

  if gunluk >= 10 then
    raise exception 'MESSAGE_REQUEST_RATE' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists message_requests_guard on public.message_requests;
create trigger message_requests_guard before insert on public.message_requests
for each row execute function public.guard_message_request();

drop trigger if exists message_requests_set_updated_at on public.message_requests;
create trigger message_requests_set_updated_at before update on public.message_requests
for each row execute function public.set_updated_at();

-- Alıcıya bildirim. Yeni enum değeri eklenmiyor; mevcut 'message' kullanılıyor.
create or replace function public.notify_on_message_request()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (new.recipient_id, 'message',
    public.profile_display_name(new.sender_id) || ' sana yazmak istiyor',
    left(new.body, 140), new.sender_id);
  return new;
end;
$$;

drop trigger if exists message_requests_notify on public.message_requests;
create trigger message_requests_notify after insert on public.message_requests
for each row execute function public.notify_on_message_request();

-- Kabul: eşleşme kuruluyor ve ilk mesaj sohbete yazılıyor.
create or replace function public.accept_message_request(request uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  kayit public.message_requests;
  ilk uuid;
  ikinci uuid;
  eslesme uuid;
begin
  select * into kayit from public.message_requests
  where id = request and recipient_id = auth.uid() and status = 'pending';
  if kayit.id is null then raise exception 'Request not found'; end if;

  ilk := least(kayit.sender_id, kayit.recipient_id);
  ikinci := greatest(kayit.sender_id, kayit.recipient_id);

  insert into public.matches(user_a, user_b) values (ilk, ikinci)
  on conflict (user_a, user_b) do update set unmatched_at = null
  returning id into eslesme;

  insert into public.messages(match_id, sender_id, body)
  values (eslesme, kayit.sender_id, kayit.body);

  update public.message_requests set status = 'accepted' where id = request;
  return eslesme;
end;
$$;

revoke all on function public.accept_message_request(uuid) from public, anon;
grant execute on function public.accept_message_request(uuid) to authenticated;

commit;
