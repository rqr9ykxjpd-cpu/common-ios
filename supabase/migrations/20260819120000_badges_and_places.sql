-- Rozetler, görünürlük kapısı düzeltmesi ve gerçek YÜ birimleri.
--
-- ÖNEMLİ BİR HATA DÜZELTİLİYOR: `is_verified` iki ayrı işi birden yapıyordu.
--
--   1. Kartlardaki mavi tik (görsel rozet)
--   2. Görünürlük kapısı — keşif adayları, tepki verme, fotoğraf okuma, yerdeki
--      kişiler ve profil görünürlüğü dahil dokuz ayrı yerde `and p.is_verified`
--      filtresi var.
--
-- Varsayılanı `false` ve hiçbir kod onu `true` yapmıyordu. Yani kayıt olan
-- kullanıcı ne kimseyi görebiliyor ne de kimseye görünüyordu — Tanış boş
-- geliyor, kimse eşleşemiyor, sebebi de hiçbir yerde yazmıyordu.
--
-- Bu yüzden ikisi ayrılıyor:
--   * `is_verified` → kapı olarak kalıyor ve profilini tamamlayan herkese
--     veriliyor (`save_my_profile` içinde). Üniversite doğrulaması ürün kararıyla
--     zaten kaldırılmıştı, dolayısıyla "içeri girebilir" ölçütü artık budur.
--   * `badge` → yeni sütun, kartlarda görünen işaret. İstemci bunu ayarlayamaz:
--     `save_my_profile` parametresi değil, kolon yetkisi de verilmiyor. Yalnızca
--     panelden elle atanır.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

-- ---------------------------------------------------------------- rozet

do $$
begin
  if not exists (select 1 from pg_type where typname = 'profile_badge') then
    create type public.profile_badge as enum ('none', 'verified', 'moderator', 'founder');
  end if;
end $$;

alter table public.profiles
  add column if not exists badge public.profile_badge not null default 'none';

-- İstemci rozeti kendine veremesin: yazma yetkisi verilmiyor.
revoke update (badge) on public.profiles from authenticated, anon;

-- ---------------------------------------------------------------- kapı

-- Profilini tamamlayan herkes görünür hale gelir. `save_my_profile` gövdesi
-- 20260819000000 ile aynı; yalnızca `is_verified` eklendi.
create or replace function public.save_my_profile(
  profile_name text,
  profile_birth_date date,
  profile_gender public.profile_gender,
  profile_dating_preference public.dating_preference,
  profile_relationship_intent public.relationship_intent,
  profile_university text,
  profile_department text,
  profile_academic_year text,
  profile_bio text,
  profile_interests text[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then raise exception 'Authentication required'; end if;
  if coalesce(cardinality(profile_interests), 0) < 3 then raise exception 'At least three interests are required'; end if;

  insert into public.profiles (
    id, name, birth_date, gender, dating_preference, relationship_intent,
    university, department, academic_year, bio, discovery_enabled, is_verified
  ) values (
    account_id, btrim(profile_name), profile_birth_date, profile_gender,
    profile_dating_preference, profile_relationship_intent, btrim(profile_university),
    btrim(profile_department), btrim(profile_academic_year), btrim(profile_bio), true, true
  ) on conflict (id) do update set
    name = excluded.name, birth_date = excluded.birth_date, gender = excluded.gender,
    dating_preference = excluded.dating_preference, relationship_intent = excluded.relationship_intent,
    university = excluded.university, department = excluded.department,
    academic_year = excluded.academic_year, bio = excluded.bio,
    discovery_enabled = true, is_verified = true;

  delete from public.profile_interests where profile_id = account_id;
  insert into public.profile_interests(profile_id, interest)
  select account_id, btrim(value) from unnest(profile_interests) value;

  delete from public.profile_prompts where profile_id = account_id;
end;
$$;

revoke all on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) from public, anon;
grant execute on function public.save_my_profile(text, date, public.profile_gender, public.dating_preference, public.relationship_intent, text, text, text, text, text[]) to authenticated;

-- Bu migration'dan önce profilini tamamlamış olanlar da açılsın.
update public.profiles set is_verified = true where discovery_enabled and not is_verified;


-- ---------------------------------------------------------------- rozeti istemciye aç
--
-- Rozet, `is_verified`'in bugüne kadar gösterildiği her yerde görünmeli; aksi halde
-- kartta çıkıp sohbette çıkmayan tutarsız bir işaret olur. `is_verified` alanları
-- yerinde bırakılıyor (kapı olarak hâlâ kullanılıyor), yanlarına `badge` ekleniyor.

-- Sohbet ve gönderi yazarları doğrudan `profiles`'tan seçiliyor: kolon okuma izni.
grant select (badge) on public.profiles to authenticated;

-- Keşif adayları
create or replace function public.get_discovery_candidates(page_limit integer default 20, page_offset integer default 0)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, gallery_paths text[], is_verified boolean,
  badge public.profile_badge,
  relationship_intent public.relationship_intent, interests text[],
  prompt_keys text[], prompt_answers text[], compatibility integer,
  compatibility_reasons text[], active_label text
)
language sql security definer set search_path = '' as $$
  with me as (
    select p.id, p.gender, p.dating_preference, p.academic_year,
      coalesce(dp.min_age, 18) as min_age, coalesce(dp.max_age, 30) as max_age,
      coalesce(dp.academic_years, '{}') as academic_years,
      coalesce(dp.departments, '{}') as departments,
      coalesce(dp.require_common_interest, false) as require_common_interest,
      coalesce((select array_agg(interest) from public.profile_interests where profile_id = p.id), '{}') as my_interests
    from public.profiles p
    left join public.discovery_preferences dp on dp.user_id = p.id
    where p.id = auth.uid()
  ),
  candidates as (
    select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
      p.bio, p.avatar_path, p.is_verified, p.badge, p.relationship_intent, p.last_active_at,
      coalesce(array_agg(pi.interest) filter (where pi.interest is not null), '{}') as interests,
      cardinality(array(
        select unnest(coalesce(array_agg(pi.interest) filter (where pi.interest is not null), '{}'))
        intersect
        select unnest((select my_interests from me))
      )) as common_count
    from public.profiles p
    left join public.profile_interests pi on pi.profile_id = p.id
    cross join me
    where p.id <> auth.uid()
      and p.is_verified and p.is_active and p.discovery_enabled
      and extract(year from age(current_date, p.birth_date)) between me.min_age and me.max_age
      and (cardinality(me.academic_years) = 0 or p.academic_year = any(me.academic_years))
      and (cardinality(me.departments) = 0 or p.department = any(me.departments))
      and (me.dating_preference = 'everyone'
           or (me.dating_preference = 'women' and p.gender = 'female')
           or (me.dating_preference = 'men' and p.gender = 'male'))
      and (p.dating_preference = 'everyone'
           or (p.dating_preference = 'women' and me.gender = 'female')
           or (p.dating_preference = 'men' and me.gender = 'male'))
      and not exists (select 1 from public.reactions r where r.actor_id = auth.uid() and r.subject_id = p.id)
      and not exists (select 1 from public.blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    group by p.id
  )
  select c.id, c.name, c.birth_date, c.university, c.department, c.academic_year,
    c.bio, c.avatar_path,
    coalesce((select array_agg(pp.storage_path order by pp.position) from public.profile_photos pp where pp.profile_id = c.id), '{}'),
    c.is_verified, c.badge, c.relationship_intent, c.interests,
    '{}'::text[], '{}'::text[],
    least(99, 55 + least(c.common_count * 10, 30)
      + case when c.academic_year = (select academic_year from me) then 5 else 0 end)::integer as compatibility_score,
    array_remove(array[
      case when c.common_count > 0 then c.common_count || ' ortak ilgi alanı' end,
      case when c.academic_year = (select academic_year from me) then 'Aynı sınıf düzeyi' end
    ], null),
    case
      when c.last_active_at > now() - interval '15 minutes' then 'Şu an aktif'
      when c.last_active_at > now() - interval '1 day' then 'Bugün aktif'
      when c.last_active_at > now() - interval '3 days' then 'Son birkaç gün içinde aktif'
      when c.last_active_at > now() - interval '7 days' then 'Bu hafta aktif'
      else 'Bir süredir uğramadı'
    end
  from candidates c
  where (not (select require_common_interest from me)) or c.common_count > 0
  order by compatibility_score desc, c.last_active_at desc nulls last, c.id
  limit greatest(page_limit, 0) offset greatest(page_offset, 0);
$$;

revoke all on function public.get_discovery_candidates(integer, integer) from public, anon;
grant execute on function public.get_discovery_candidates(integer, integer) to authenticated;


-- Yerdeki kişiler
create or replace function public.get_people_at_place(target_place uuid)
returns table (
  id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge,
  relationship_intent public.relationship_intent, interests text[], active_label text
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge, p.relationship_intent,
    coalesce((select array_agg(pi.interest order by pi.interest)
              from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    public.activity_label(p.last_active_at)
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


-- Profil ziyaretçileri
create or replace function public.get_my_profile_visits()
returns table (
  visitor_id uuid, name text, birth_date date, university text, department text,
  academic_year text, bio text, avatar_path text, is_verified boolean,
  badge public.profile_badge,
  visit_count integer, last_visited_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.birth_date, p.university, p.department, p.academic_year,
    p.bio, p.avatar_path, p.is_verified, p.badge, v.visit_count, v.last_visited_at
  from public.profile_visits v
  join public.profiles p on p.id = v.visitor_id
  where v.profile_id = auth.uid()
    and v.last_visited_at > now() - interval '7 days'
    and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by v.last_visited_at desc
  limit 50;
$$;

revoke all on function public.get_my_profile_visits() from public, anon;
grant execute on function public.get_my_profile_visits() to authenticated;


-- Kendi profilim (rozetimi kendi ekranımda da görebilmek için)
create or replace function public.get_my_profile()
returns table (
  name text, birth_date date, gender public.profile_gender,
  dating_preference public.dating_preference,
  relationship_intent public.relationship_intent,
  university text, department text, academic_year text, bio text,
  badge public.profile_badge,
  interests text[], prompt_keys text[], prompt_answers text[],
  min_age smallint, max_age smallint, academic_years text[], departments text[],
  require_common_interest boolean, campus_only boolean
)
language sql stable security definer set search_path = '' as $$
  select
    p.name, p.birth_date, p.gender, p.dating_preference, p.relationship_intent,
    p.university, p.department, p.academic_year, p.bio, p.badge,
    coalesce((select array_agg(pi.interest order by pi.interest) from public.profile_interests pi where pi.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.prompt_key order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce((select array_agg(pp.answer order by pp.position) from public.profile_prompts pp where pp.profile_id = p.id), '{}'),
    coalesce(dp.min_age, 18::smallint),
    coalesce(dp.max_age, 30::smallint),
    coalesce(dp.academic_years, '{}'),
    coalesce(dp.departments, '{}'),
    coalesce(dp.require_common_interest, false),
    coalesce(dp.campus_only, true)
  from public.profiles p
  left join public.discovery_preferences dp on dp.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- ---------------------------------------------------------------- yerler
--
-- Fakülte adları Yalova Üniversitesi'nin kendi iletişim sayfasından alındı
-- (yalova.edu.tr/iletisim).
--
-- Alan etiketleri tek bir değere indiriliyor. Eskiden aynı kampüs için üç ayrı
-- etiket vardı ("YÜ", "Yalova", "Merkez Kampüs") ve buraya bir de "Merkez Yerleşke"
-- eklenince liste dört başlığa bölünmüş görünüyordu — oysa bu noktaların hepsi
-- merkez kampüste.

insert into public.places (name, area) values
  ('Aytaç Cafe',                          'Merkez Kampüs'),
  ('Mühendislik Fakültesi',               'Merkez Kampüs'),
  ('Sanat ve Tasarım Fakültesi',          'Merkez Kampüs'),
  ('Hukuk Fakültesi',                     'Merkez Kampüs'),
  ('İnsan ve Toplum Bilimleri Fakültesi', 'Merkez Kampüs'),
  ('İlahiyat Fakültesi',                  'Merkez Kampüs'),
  ('Sağlık Bilimleri Fakültesi',          'Merkez Kampüs'),
  ('Spor Bilimleri Fakültesi',            'Merkez Kampüs'),
  ('Tıp Fakültesi',                       'Merkez Kampüs'),
  ('Yabancı Diller Yüksekokulu',          'Merkez Kampüs'),
  ('Yalova Meslek Yüksekokulu',           'Merkez Kampüs'),
  ('Yemekhane',                           'Merkez Kampüs'),
  ('Spor Salonu',                         'Merkez Kampüs')
on conflict (name) do nothing;

-- Eskiden eklenmiş kayıtların etiketleri de tek değere çekiliyor.
update public.places set area = 'Merkez Kampüs' where area <> 'Merkez Kampüs';

commit;
