-- Hayalet mod Common kurucusunun profiline karşı işlemez: hayalet moddaki
-- kullanıcı kurucunun profiline girerse ziyaret kaydedilir, kurucu
-- ziyaretçilerinde görür. Başka hiçbir profilde hayalet ziyaret kaydedilmez;
-- story izleme hayalette yine kaydedilmez.
--
-- Uygulamadaki hayalet mod açıklaması bu istisnayı 1.1.3'ten itibaren
-- söylüyor ("Common kurucusunun profili hariç"). Kurucunun kararıyla
-- 1.1.3'ü beklemeden uygulandı (7 Ekim).
--
-- Gövde 20260824120000'deki (canlıdaki) tanım; tek fark hayalet kontrolü.
begin;

create or replace function public.record_profile_visit(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or target is null or target = auth.uid() then return; end if;
  if public.is_acting_ghost(auth.uid())
     and not exists (select 1 from public.profiles p where p.id = target and p.badge = 'founder') then
    return;
  end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = target)
       or (b.blocker_id = target and b.blocked_id = auth.uid())
  ) then return; end if;
  if not exists (select 1 from public.profiles p where p.id = target and p.is_active) then return; end if;

  insert into public.profile_visits (profile_id, visitor_id)
  values (target, auth.uid())
  on conflict (profile_id, visitor_id) do update
    set visit_count = public.profile_visits.visit_count + 1,
        last_visited_at = now();
end;
$$;
revoke all on function public.record_profile_visit(uuid) from public, anon;
grant execute on function public.record_profile_visit(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261007040000', 'founder_sees_ghost_visits')
on conflict (version) do nothing;

commit;
