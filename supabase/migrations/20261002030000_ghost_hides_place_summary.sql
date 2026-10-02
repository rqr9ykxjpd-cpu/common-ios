-- Hayalet mod "Kim nerede" satırında da gizlesin.
--
-- Kişi listesi (get_people_at_place) hayaletleri 20260911040000'dan beri
-- eliyor; ama satırdaki sayı ve ilk üç fotoğraf (get_place_presence) elemiyordu.
-- Hayalet bir kullanıcı "Buradayım" deyince sayı artıyor, fotoğrafı satırda
-- görünebiliyordu. Kalan her şey (süre, engel, doğrulama) canlıdakiyle aynı.
begin;

create or replace function public.get_place_presence()
returns table (place_id uuid, people_count integer, avatar_paths text[])
language sql stable security definer set search_path = '' as $$
  with gorunen as (
    select p.visible_place_id as place_id, p.id, p.avatar_path, p.last_active_at
    from public.profiles p
    where auth.uid() is not null
      and p.visible_place_id is not null
      and p.visible_until > now()
      and p.is_verified and p.is_active
      -- Kendi satırında kendini görsün; başkasına hayalet görünmez.
      and (p.id = auth.uid() or not coalesce(p.ghost_mode, false))
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = auth.uid())
      )
  )
  select g.place_id,
         count(*)::integer,
         (array_agg(g.avatar_path order by g.last_active_at desc) filter (where g.avatar_path is not null))[1:3]
  from gorunen g
  group by g.place_id;
$$;
revoke all on function public.get_place_presence() from public, anon;
grant execute on function public.get_place_presence() to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261002030000', 'ghost_hides_place_summary')
on conflict (version) do nothing;

commit;
