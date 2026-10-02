-- Kim nerede anlık: biri bir yerde "Buradayım" deyince ya da ayrılınca açık
-- ekranlar bir saniye içinde yenilensin.
--
-- Uygulamalar profil tablosunu dinleyemez (kimin nerede olduğu ham hâliyle
-- herkese akardı). Bunun yerine yer başına tek satırlık bir "değişti" damgası
-- tutuluyor: içinde kişi yok, yalnızca yer ve zaman. Ekran damgayı görünce
-- sayıyı ve listeyi her zamanki kurallı fonksiyonlardan (hayalet, engel,
-- doğrulama) yeniden çeker. Hayalet kullanıcının hareketi damga üretmez.
begin;

create table if not exists public.place_activity (
  place_id uuid primary key references public.places(id) on delete cascade,
  changed_at timestamptz not null default now()
);
alter table public.place_activity enable row level security;
revoke all on public.place_activity from public, anon, authenticated;
grant select on public.place_activity to authenticated;
drop policy if exists "members see place activity" on public.place_activity;
create policy "members see place activity" on public.place_activity
  for select to authenticated using (true);

create or replace function public.touch_place_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.visible_place_id is not distinct from old.visible_place_id then
    return new;
  end if;
  if coalesce(new.ghost_mode, false) then
    return new;
  end if;
  if old.visible_place_id is not null then
    insert into public.place_activity (place_id, changed_at)
    values (old.visible_place_id, now())
    on conflict (place_id) do update set changed_at = excluded.changed_at;
  end if;
  if new.visible_place_id is not null then
    insert into public.place_activity (place_id, changed_at)
    values (new.visible_place_id, now())
    on conflict (place_id) do update set changed_at = excluded.changed_at;
  end if;
  return new;
exception
  -- Damga yazılamazsa yer seçimi yine de kaydedilsin.
  when others then return new;
end;
$$;
revoke all on function public.touch_place_activity() from public, anon, authenticated;

drop trigger if exists profiles_place_activity on public.profiles;
create trigger profiles_place_activity
after update of visible_place_id on public.profiles
for each row execute function public.touch_place_activity();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'place_activity'
  ) then
    alter publication supabase_realtime add table public.place_activity;
  end if;
end $$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261002050000', 'place_activity_realtime')
on conflict (version) do nothing;

commit;
