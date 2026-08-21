-- Moderasyon: kurucu ve moderatörler içerik kaldırabilsin, hesap askıya alabilsin.
--
-- Şu ana kadar rozet yalnızca görseldi. Şikayet tablosuna kayıt düşüyordu ama
-- **kimse okuyamıyordu** — kurucu bile. Yani birileri bir gönderiyi şikayet
-- ettiğinde uygulama üzerinden yapılabilecek hiçbir şey yoktu.
--
-- Bu yalnızca bir eksik özellik değil: App Store 1.2 maddesi, kullanıcı
-- içeriği barındıran uygulamalardan şikayeti 24 saat içinde değerlendirip
-- içeriği kaldırmayı ve gerekiyorsa hesabı uygulamadan çıkarmayı istiyor.
-- Mağaza notlarımızda bunu yaptığımızı yazıyoruz; bu migration olmadan o
-- cümle doğru değil.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

-- ------------------------------------------------------------ kim moderatör
--
-- Rozet `profiles` üzerinde ve oraya yazma yetkisi 20260821170000 ile
-- kaldırıldı; yalnızca `set_badge` verebiliyor. Dolayısıyla bu kontrol
-- güvenli: kimse kendini moderatör ilan edip içerik silemez.
create or replace function public.is_moderator()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and badge in ('founder', 'moderator')
  );
$$;

revoke all on function public.is_moderator() from public, anon;
grant execute on function public.is_moderator() to authenticated;

-- --------------------------------------------------------- içerik kaldırma
--
-- Mevcut "kendi içeriğini yönet" kuralları duruyor; bunlar onların yanına
-- ekleniyor. Postgres izin kurallarını VEYA'lıyor, dolayısıyla normal
-- kullanıcı yine yalnızca kendi içeriğine dokunabiliyor.
drop policy if exists "moderators delete any post" on public.posts;
create policy "moderators delete any post" on public.posts
for delete to authenticated using (public.is_moderator());

drop policy if exists "moderators delete any story" on public.stories;
create policy "moderators delete any story" on public.stories
for delete to authenticated using (public.is_moderator());

drop policy if exists "moderators delete any comment" on public.comments;
create policy "moderators delete any comment" on public.comments
for delete to authenticated using (public.is_moderator());

-- ------------------------------------------------------------- şikayetler
alter table public.reports add column if not exists handled_at timestamptz;
alter table public.reports add column if not exists handled_by uuid references public.profiles(id) on delete set null;
alter table public.reports add column if not exists resolution text
  check (resolution is null or resolution in ('dismissed', 'content_removed', 'account_suspended'));

drop policy if exists "moderators read all reports" on public.reports;
create policy "moderators read all reports" on public.reports
for select to authenticated using (public.is_moderator());

-- Şikayeti yalnızca moderatör kapatabilir. Şikayet eden kendi kaydını
-- değiştiremiyor: "ben hallettim" diyip kaydı kapatmak kimsenin işi değil.
drop policy if exists "moderators resolve reports" on public.reports;
create policy "moderators resolve reports" on public.reports
for update to authenticated
using (public.is_moderator()) with check (public.is_moderator());

grant update (handled_at, handled_by, resolution) on public.reports to authenticated;

-- --------------------------------------------------------- hesap askıya alma
--
-- `is_active = false` olan hesap keşifte çıkmıyor, profili okunmuyor,
-- story'si görünmüyor — bu kural zaten her sorguda var (bkz. 20260817190000).
-- Eksik olan tek şey onu değiştirebilecek bir yoldu.
--
-- `profiles` üzerinde authenticated'ın UPDATE yetkisi yok (20260821170000),
-- o yüzden security definer.
create or replace function public.set_account_active(account uuid, active boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderator privileges required';
  end if;
  -- Moderatör moderatörü askıya alamasın: yetki kavgası ve kaza ihtimali.
  if exists (select 1 from public.profiles where id = account and badge in ('founder', 'moderator')) then
    raise exception 'Cannot suspend a moderator';
  end if;
  update public.profiles set is_active = active where id = account;
end;
$$;

revoke all on function public.set_account_active(uuid, boolean) from public, anon;
grant execute on function public.set_account_active(uuid, boolean) to authenticated;

-- Askıya alınan hesabın yeni içerik üretememesi gerekiyor; okuma kuralları
-- zaten kapalı ama yazma tarafı açıktı.
create or replace function public.block_inactive_authors()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and is_active) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_block_inactive on public.posts;
create trigger posts_block_inactive before insert on public.posts
for each row execute function public.block_inactive_authors();

drop trigger if exists stories_block_inactive on public.stories;
create trigger stories_block_inactive before insert on public.stories
for each row execute function public.block_inactive_authors();

drop trigger if exists comments_block_inactive on public.comments;
create trigger comments_block_inactive before insert on public.comments
for each row execute function public.block_inactive_authors();

drop trigger if exists messages_block_inactive on public.messages;
create trigger messages_block_inactive before insert on public.messages
for each row execute function public.block_inactive_authors();

commit;
