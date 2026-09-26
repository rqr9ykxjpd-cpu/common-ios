-- Profil kartının rengi (Build 6, "Kartını düzenle").
--
-- Kullanıcı seçilmiş 8 renkten birini seçer; kartını açan herkes o renkte
-- görür. Klasik = null. Değerler istemcideki `CardTheme` ile aynı.
--
-- Eski sürümlerle uyumlu: Build 5 bu sütundan habersiz; hiçbir okuma ya da
-- yazma yolunu değiştirmiyor. Yazma yalnızca `set_my_card_theme` ile.
begin;

alter table public.profiles add column if not exists card_theme text;

alter table public.profiles drop constraint if exists profiles_card_theme_valid;
alter table public.profiles add constraint profiles_card_theme_valid
  check (card_theme is null or card_theme in (
    'ink', 'navy', 'terracotta', 'sage', 'lavender', 'rose', 'ocean'
  ));

-- Tabloda sütun bazlı okuma izni var; yeni sütun ayrıca açılmazsa hiç okunmaz.
grant select (card_theme) on public.profiles to authenticated;

-- Kendi kartının rengini kaydeder. 'classic' ya da null klasiğe döndürür.
create or replace function public.set_my_card_theme(theme text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  hesap uuid := auth.uid();
  secilen text := nullif(nullif(lower(btrim(coalesce(theme, ''))), ''), 'classic');
begin
  if hesap is null then raise exception 'Authentication required'; end if;
  if secilen is not null and secilen not in (
    'ink', 'navy', 'terracotta', 'sage', 'lavender', 'rose', 'ocean'
  ) then
    raise exception 'CARD_THEME_INVALID';
  end if;
  update public.profiles set card_theme = secilen where id = hesap;
  if not found then raise exception 'PROFILE_MISSING'; end if;
end;
$$;
revoke all on function public.set_my_card_theme(text) from public, anon;
grant execute on function public.set_my_card_theme(text) to authenticated;

commit;
