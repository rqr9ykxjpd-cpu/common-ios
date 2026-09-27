-- Kart renklerine iki pembe (Build 6): "Pembe" (bubblegum) ve "Ahududu"
-- (raspberry). Kısıt ve set_my_card_theme'nin izinli listesi genişliyor;
-- başka hiçbir şey değişmiyor. Değerler istemcideki `CardTheme` ile aynı.
begin;

alter table public.profiles drop constraint if exists profiles_card_theme_valid;
alter table public.profiles add constraint profiles_card_theme_valid
  check (card_theme is null or card_theme in (
    'ink', 'navy', 'terracotta', 'raspberry', 'sage', 'lavender', 'rose', 'bubblegum', 'ocean'
  ));

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
    'ink', 'navy', 'terracotta', 'raspberry', 'sage', 'lavender', 'rose', 'bubblegum', 'ocean'
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
