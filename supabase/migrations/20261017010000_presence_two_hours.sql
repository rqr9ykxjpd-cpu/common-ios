-- "Kim nerede" seçimi 2 saat geçerli (kurucunun kararı, 17 Ekim). Uygulama
-- süre göndermiyor, sunucunun varsayılanı kullanılıyor: 90 dakikaydı, 120
-- oldu. Bütün sürümlerde hemen geçerli. Gövde canlıdaki tanımın aynısı
-- (17 Ekim); yalnızca varsayılan değişti. 15–240 dakika sınırı aynı.
begin;

create or replace function public.set_visible_place(target_place uuid, minutes integer default 120)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_place is null then
    update public.profiles set visible_place_id = null, visible_until = null where id = auth.uid();
    return;
  end if;
  if not exists (select 1 from public.places where id = target_place and is_active) then
    raise exception 'Unknown place';
  end if;
  update public.profiles
     set visible_place_id = target_place,
         visible_until = now() + make_interval(mins => greatest(15, least(minutes, 240))),
         last_active_at = now()
   where id = auth.uid();
end;
$function$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261017010000', 'presence_two_hours')
on conflict (version) do nothing;

commit;
