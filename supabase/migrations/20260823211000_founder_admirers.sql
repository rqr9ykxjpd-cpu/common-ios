-- Kurucuya özel: hesabımı kimler sağa kaydırdı.
--
-- `reactions` üzerindeki okuma kuralı herkese yalnızca KENDİ yaptığı beğenileri
-- gösteriyor (bkz. 20260817133000, "users read own reactions"). Kendisine gelen
-- beğeniyi kimse göremiyor; bu fonksiyon o kuralın tek istisnası.
--
-- İki bilinçli kısıt var:
--
--   1. Rozet kontrolü `is_moderator()` değil, doğrudan 'founder'. Moderatör
--      rozeti ileride başkasına verilirse o kişi bu listeyi görmemeli.
--
--   2. Fonksiyon parametre almıyor. Yani "şu kişiyi kimler beğendi" diye
--      sorulamıyor — yalnızca çağıranın kendi hesabına geleni döndürüyor.
--      Parametre alsaydı kurucu bütün kullanıcıların beğenilerini okuyabilirdi;
--      bu, kullanıcı mahremiyetinde kalıcı bir delik olurdu.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

create or replace function public.who_liked_me()
returns table (
  id uuid,
  name text,
  birth_date date,
  university text,
  department text,
  academic_year text,
  bio text,
  avatar_path text,
  is_verified boolean,
  badge public.profile_badge,
  liked_at timestamptz,
  is_matched boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  -- Tablo alan adları (`id`, `badge`, ...) bu fonksiyonda aynı zamanda birer
  -- değişken. Niteleyici olmadan yazılırsa Postgres "ambiguous column
  -- reference" hatası veriyor; o yüzden her kolon takma adla yazılı.
  if not exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.badge = 'founder'
  ) then
    raise exception 'Founder privileges required';
  end if;

  return query
  select
    p.id,
    p.name,
    p.birth_date,
    p.university,
    p.department,
    p.academic_year,
    p.bio,
    p.avatar_path,
    p.is_verified,
    p.badge,
    r.updated_at,
    exists (
      select 1 from public.matches m
      where m.user_a = least(p.id, auth.uid())
        and m.user_b = greatest(p.id, auth.uid())
        and m.unmatched_at is null
    )
  from public.reactions r
  join public.profiles p on p.id = r.actor_id
  where r.subject_id = auth.uid()
    and r.kind = 'like'
    -- Askıya alınmış hesaplar listede görünmesin: uygulamanın geri kalanında
    -- da `is_active = false` olan profil hiçbir yerde çıkmıyor.
    and p.is_active
    -- Engellediğin ya da seni engelleyen biri listede durmasın.
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by r.updated_at desc;
end;
$$;

revoke all on function public.who_liked_me() from public, anon;
grant execute on function public.who_liked_me() to authenticated;

commit;
