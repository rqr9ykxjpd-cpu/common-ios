-- Doğrulanmamış hesap görünmez; öğrenci kilidi anahtarı olmadan.
--
-- Kurucu panelindeki kilit anahtarı kaldırıldı: yazma engelini uygulama zaten
-- koyuyor (1.1+). Ama görünürlük anahtara bağlıydı; anahtar kapalıyken
-- `is_verified` herkese true kalıyor, doğrulanmamış hesap önerilerde, keşifte
-- ve Kim nerede'de çıkıyordu. Artık `is_verified` her zaman doğrulama durumunu
-- izliyor (doğrulanmış, muaf ya da rozetli). Kişi, yer ve öneri fonksiyonları
-- zaten bu alana bakıyor. Yer engeli ve EDU_REQUIRED yine yalnız anahtar açıkken.
begin;

create or replace function public.edu_gate_profile_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  izinli boolean;
begin
  izinli := new.edu_exempt or new.edu_verified_at is not null or new.badge in ('founder', 'moderator');
  new.is_verified := izinli;
  if not public.edu_gate_active() then return new; end if;
  if not izinli and new.visible_place_id is not null
     and (tg_op = 'INSERT' or new.visible_place_id is distinct from old.visible_place_id) then
    if auth.uid() is not null and auth.uid() = new.id then raise exception 'EDU_REQUIRED'; end if;
    new.visible_place_id := null;
    new.visible_until := null;
  end if;
  return new;
end;
$$;

update public.profiles p
   set is_verified = (p.edu_exempt or p.edu_verified_at is not null or p.badge in ('founder', 'moderator'))
 where p.is_verified is distinct from (p.edu_exempt or p.edu_verified_at is not null or p.badge in ('founder', 'moderator'));

insert into supabase_migrations.schema_migrations (version, name)
values ('20261003010000', 'unverified_hidden')
on conflict (version) do nothing;

commit;
