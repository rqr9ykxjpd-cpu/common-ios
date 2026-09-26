-- Kullanıcı adı (Build 6).
--
-- App Review 21 Eylül (Guideline 4): Apple ile girişten sonra kullanıcıdan
-- adını tekrar istemek yasak. Apple adı yalnızca ilk yetkilendirmede verir;
-- sonraki girişlerde boş gelir ve zorunlu ad alanı aynı reddi doğurabilir.
-- Kayıt artık gerçek ad yerine uygulamaya özel bir kullanıcı adı (@cem.budak)
-- istiyor; gerçek ad yalnızca sağlayıcı verdiyse sessizce kaydediliyor.
--
-- Eski sürümlerle uyumlu: Build 5 kullanıcı adından habersiz profil açar;
-- tetikleyici ona addan türetilmiş bir kullanıcı adı verir. Sütun ve kurallar
-- mevcut okuma/yazma yollarını değiştirmiyor.
--
-- Kurallar: 3–20 karakter; küçük harf, rakam, nokta, alt çizgi; nokta ile
-- başlayıp bitemez, iki nokta yan yana gelemez; ayrılmış kelimeler ve metin
-- filtresine takılanlar geçersiz.
begin;

alter table public.profiles add column if not exists username text;
-- Kullanıcı adını kendisi seçtiyse ne zaman. Otomatik verilenlerde (eski
-- hesaplar, Build 5 ile açılanlar) boş; uygulama bir kez "Kullanıcı adını
-- seç" ekranı gösteriyor.
alter table public.profiles add column if not exists username_claimed_at timestamptz;

-- Biçim kontrolü. Kısıt da bunu kullanıyor; doğrudan güncelleme yolları
-- (avatar gibi) satırı yeniden doğruladığı için herkes çalıştırabilmeli.
create or replace function public.username_is_valid(candidate text)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select candidate is not null
     and candidate ~ '^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$'
     and position('..' in candidate) = 0
     and candidate <> all (array[
       'common', 'admin', 'administrator', 'moderator', 'mod', 'support',
       'destek', 'apple', 'google', 'root', 'system', 'yonetici', 'kurucu',
       'founder', 'official', 'resmi', 'help', 'yardim', 'null', 'undefined'
     ])
     and not public.content_text_is_blocked(candidate);
$$;

alter table public.profiles drop constraint if exists profiles_username_valid;
alter table public.profiles add constraint profiles_username_valid
  check (username is null or public.username_is_valid(username));

create unique index if not exists profiles_username_key on public.profiles (username);

-- Tabloda sütun bazlı okuma izni var; yeni sütun ayrıca açılmazsa hiç okunmaz.
grant select (username) on public.profiles to authenticated;

-- Addan aday: küçük harf, Türkçe harfler Latin, izinsiz karakterler nokta.
create or replace function public.username_base(raw text)
returns text
language sql
immutable
set search_path = ''
as $$
  select left(trim(both '.' from regexp_replace(regexp_replace(
           translate(
             translate(lower(coalesce(raw, '')), U&'\0307', ''),
             'çğıöşüâîû', 'cgiosuaiu'
           ),
           '[^a-z0-9_.]+', '.', 'g'),
         '\.{2,}', '.', 'g')), 14);
$$;

-- Benzersiz bir kullanıcı adı üretir; gerekirse sonuna 4 rakam ekler.
create or replace function public.generate_username(raw text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  taban text := trim(both '.' from public.username_base(raw));
  aday text;
  deneme integer := 0;
begin
  if not public.username_is_valid(taban) then
    taban := 'ogrenci';
  end if;
  aday := taban;
  loop
    if public.username_is_valid(aday)
       and not exists (select 1 from public.profiles p where p.username = aday) then
      return aday;
    end if;
    deneme := deneme + 1;
    if deneme > 60 then
      return 'ogrenci' || substr(md5(random()::text || clock_timestamp()::text), 1, 10);
    end if;
    aday := left(taban, 14) || (1000 + floor(random() * 9000))::int::text;
  end loop;
end;
$$;
revoke all on function public.generate_username(text) from public, anon, authenticated;

-- Eski sürümün (ve kullanıcı adı seçilmeden kaydedilen) profilleri de bir ad alır.
create or replace function public.profiles_default_username()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.username is null then
    new.username := public.generate_username(new.name);
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_default_username on public.profiles;
create trigger profiles_default_username before insert on public.profiles
for each row execute function public.profiles_default_username();

-- Mevcut profiller: bir kez, sırayla (benzersizlik için). updated_at oynamasın.
alter table public.profiles disable trigger profiles_set_updated_at;
do $$
declare
  satir record;
begin
  for satir in select id, name from public.profiles where username is null order by created_at loop
    update public.profiles set username = public.generate_username(satir.name) where id = satir.id;
  end loop;
end;
$$;
alter table public.profiles enable trigger profiles_set_updated_at;

-- Kayıt/profil ekranındaki anlık "uygun mu" kontrolü. Kendi mevcut adın uygun sayılır.
create or replace function public.username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.username_is_valid(lower(btrim(candidate)))
     and not exists (
       select 1 from public.profiles p
       where p.username = lower(btrim(candidate)) and p.id <> auth.uid()
     );
$$;
revoke all on function public.username_available(text) from public, anon;
grant execute on function public.username_available(text) to authenticated;

-- Kullanıcı adını alır. Hatalar istemcide ayrıştırılıyor:
-- USERNAME_INVALID, USERNAME_TAKEN, PROFILE_MISSING.
create or replace function public.claim_my_username(candidate text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  hesap uuid := auth.uid();
  istenen text := lower(btrim(coalesce(candidate, '')));
begin
  if hesap is null then raise exception 'Authentication required'; end if;
  if not public.username_is_valid(istenen) then raise exception 'USERNAME_INVALID'; end if;
  if exists (select 1 from public.profiles p where p.username = istenen and p.id <> hesap) then
    raise exception 'USERNAME_TAKEN';
  end if;
  update public.profiles set username = istenen, username_claimed_at = now() where id = hesap;
  if not found then raise exception 'PROFILE_MISSING'; end if;
  return istenen;
exception
  when unique_violation then raise exception 'USERNAME_TAKEN';
end;
$$;
revoke all on function public.claim_my_username(text) from public, anon;
grant execute on function public.claim_my_username(text) to authenticated;

-- Kullanıcı adı otomatik mi verildi? `true` ise uygulama seçme ekranını gösterir.
create or replace function public.username_needs_choice()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.username_claimed_at is null from public.profiles p where p.id = auth.uid()),
    false
  );
$$;
revoke all on function public.username_needs_choice() from public, anon;
grant execute on function public.username_needs_choice() to authenticated;

commit;
