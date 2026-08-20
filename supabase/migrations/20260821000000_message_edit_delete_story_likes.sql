-- İki eksik: mesaj silme/düzenleme ve story beğenisi.
--
-- Uygulamanın `messages` tablosunda yalnızca okuma, ekleme ve `read_at`
-- güncelleme yetkisi vardı; kendi mesajını silmenin ya da düzeltmenin yolu
-- yoktu. Story beğenisi ise hiç yoktu: kalp düğmesi eşleşilen sohbete "❤️"
-- mesajı gönderiyordu, story sahibine "beğenildi" diye bir şey ulaşmıyordu.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

-- ------------------------------------------------------------ mesaj düzenleme
-- Düzenlenmiş mesajı arayüzde işaretleyebilmek için. Boşsa hiç düzenlenmemiş.
alter table public.messages add column if not exists edited_at timestamptz;

-- Yalnızca kendi mesajını ve yalnızca hâlâ üyesi olduğun eşleşmede.
drop policy if exists "senders edit own messages" on public.messages;
create policy "senders edit own messages" on public.messages
for update to authenticated
using (sender_id = auth.uid() and public.is_match_member(match_id))
with check (sender_id = auth.uid() and public.is_match_member(match_id));

-- `read_at` yetkisi zaten vardı; gövde ve düzenleme damgası ekleniyor.
grant update (body, edited_at) on public.messages to authenticated;

-- ---------------------------------------------------------------- mesaj silme
drop policy if exists "senders delete own messages" on public.messages;
create policy "senders delete own messages" on public.messages
for delete to authenticated
using (sender_id = auth.uid() and public.is_match_member(match_id));

grant delete on public.messages to authenticated;

-- ------------------------------------------------------------ story beğenisi
create table if not exists public.story_likes (
  story_id uuid not null references public.stories(id) on delete cascade,
  liker_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, liker_id)
);

alter table public.story_likes enable row level security;

-- Beğeniyi story sahibi ve beğenen görebilir; başkası göremez.
drop policy if exists "owner and liker read story likes" on public.story_likes;
create policy "owner and liker read story likes" on public.story_likes
for select to authenticated using (
  liker_id = auth.uid()
  or exists (
    select 1 from public.stories s
    where s.id = story_likes.story_id and s.author_id = auth.uid()
  )
);

-- Herkes yalnızca kendi beğenisini ekler ve kaldırır.
drop policy if exists "users manage own story likes" on public.story_likes;
create policy "users manage own story likes" on public.story_likes
for all to authenticated
using (liker_id = auth.uid())
with check (liker_id = auth.uid());

revoke all on public.story_likes from anon;
grant select, insert, delete on public.story_likes to authenticated;

-- Story sahibine bildirim. Yeni enum değeri EKLENMİYOR: `alter type ... add
-- value` migration'ın tamamı tek işlemde koştuğu için riskli. Mevcut 'like'
-- değeri kullanılıyor, arayüz bu türü zaten tanıyor.
create or replace function public.notify_on_story_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.stories where id = new.story_id;
  -- Kendi story'sini beğenmek bildirim üretmez; `no_self_notification` kısıtı
  -- zaten buna izin vermezdi ve tetikleyici hatası beğeniyi de geri sarardı.
  if owner_id is null or owner_id = new.liker_id then return new; end if;
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (owner_id, 'like',
    public.profile_display_name(new.liker_id) || ' story''ni beğendi', '',
    new.liker_id);
  return new;
end;
$$;

drop trigger if exists story_likes_notify on public.story_likes;
create trigger story_likes_notify after insert on public.story_likes
for each row execute function public.notify_on_story_like();

commit;
