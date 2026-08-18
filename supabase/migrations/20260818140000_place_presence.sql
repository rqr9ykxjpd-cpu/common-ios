-- Yer görünürlüğü ("şu an buradayım").
--
-- "Nerede tanışabiliriz" ekranındaki kişiler koda gömülü sabit bir listeydi: herkese aynı
-- sahte isimler görünüyordu ve `togglePresence` yalnızca bellekte çalışıyordu, yani kimse
-- gerçekten bir yerde görünmüyordu.
--
-- Görünürlük bilinçli olarak kısa ömürlü: konum paylaşımı kalıcı olmamalı, bu yüzden
-- `visible_until` alanı var ve süresi dolunca kişi listeden kendiliğinden düşüyor.
--
-- Idempotent; tekrar çalıştırılabilir.

begin;

alter table public.profiles
  add column if not exists visible_place_id uuid references public.places(id) on delete set null,
  add column if not exists visible_until timestamptz;

create index if not exists profiles_visible_place_idx
  on public.profiles (visible_place_id, visible_until)
  where visible_place_id is not null;

-- Görünürlük alanları kolon bazlı okuma yetkisine eklenmeli; `tighten_privacy`
-- migration'ı profiles üzerindeki genel SELECT yetkisini kaldırmıştı.
grant select (visible_place_id, visible_until) on public.profiles to authenticated;

-- Kendi görünürlüğünü ayarla. Yer null ise görünürlük kapanır.
create or replace function public.set_visible_place(target_place uuid, minutes integer default 90)
returns void language plpgsql security definer set search_path = '' as $$
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
$$;

revoke all on function public.set_visible_place(uuid, integer) from public, anon;
grant execute on function public.set_visible_place(uuid, integer) to authenticated;

-- Bir yerde şu an görünen kişiler. Keşifteki filtrelerin aynısı geçerli:
-- doğrulanmış, aktif, engellenmemiş ve kendisi değil.
create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    case when p.last_active_at > now() - interval '1 hour' then 'Yakın zamanda aktif'
         when p.last_active_at > now() - interval '1 day' then 'Bugün aktif'
         else 'Bu hafta aktif' end
  from public.profiles p
  where p.visible_place_id = target_place
    and p.visible_until > now()
    and p.id <> auth.uid()
    and p.is_verified and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.last_active_at desc
  limit 50;
$$;

revoke all on function public.get_people_at_place(uuid) from public, anon;
grant execute on function public.get_people_at_place(uuid) to authenticated;

commit;
