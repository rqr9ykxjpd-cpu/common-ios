-- "Muaf tut" öğrenciyi doğrulanmış da sayar (kurucunun kararı, 21 Ekim:
-- "ben muaf deyince doğrulanması lazım"). Eskiden yalnızca edu_exempt
-- yazılıyordu: kilit kalkıyor ama Öğrenci rozeti gelmiyordu. Artık muaf
-- tutmak, "Öğrenci olarak doğrula" ile aynı izi de bırakır (edu_verified_at,
-- rozeti yoksa Öğrenci rozeti; kurucu/moderatör rozetine dokunulmaz).
-- Muafiyeti kaldırmak doğrulamayı geri almaz; o ayrı bir işlem.
-- Gövde canlıdaki tanımdan (21 Ekim) + doğrulama satırları.
begin;

create or replace function public.founder_set_edu_exempt(target uuid, exempt boolean)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  yeni boolean;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.profiles p
     set edu_exempt = coalesce(exempt, false),
         edu_verified_at = case when coalesce(exempt, false) then coalesce(p.edu_verified_at, now()) else p.edu_verified_at end,
         badge = case
           when coalesce(exempt, false) and p.badge = 'none' then 'verified'::public.profile_badge
           else p.badge
         end
   where p.id = target
   returning p.edu_exempt into yeni;
  if yeni is null then raise exception 'Profile not found'; end if;
  return yeni;
end;
$function$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261021010000', 'exempt_also_verifies')
on conflict (version) do nothing;

commit;
