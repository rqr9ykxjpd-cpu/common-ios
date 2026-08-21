-- İki şey: ekibe Pro ve `profiles` üzerindeki yazma yetkisinin daraltılması.
--
-- İkisi aynı dosyada, çünkü birincisi ikincisi olmadan güvenli değil.
--
-- Idempotent; tekrar çalıştırmak güvenlidir.

begin;

-- ------------------------------------------- profiles: sütun bazında yazma
--
-- `authenticated` rolüne tablo seviyesinde UPDATE verilmişti
-- (20260817133000). Sonra 20260819120000 içinde
-- `revoke update (badge) ... from authenticated` yazıldı ama bu Postgres'te
-- işe yaramaz: tablo seviyesindeki yetki bütün sütunları kapsar ve tek bir
-- sütun için geri alınamaz. Postgres bu durumda sessizce bir uyarı basıp
-- hiçbir şey yapmaz.
--
-- Sonuç: kullanıcı kendi satırında istediği sütunu yazabiliyordu. `badge`
-- yazılabildiği için herkes kendini "Common Kurucusu" ya da moderatör
-- yapabilirdi; `is_verified` yazılabildiği için doğrulanmış görünebilirdi.
--
-- Doğru yol tek yol: tablo yetkisini kaldırıp yalnızca gerçekten yazılan
-- sütunu açmak. İstemci `profiles` üzerinde doğrudan sadece `avatar_path`
-- yazıyor (fotoğraf yükleme/kaldırma); metin alanları `save_my_profile`,
-- görünürlük `set_visible_place`, etkinlik `touch_last_active` üzerinden
-- gidiyor ve hepsi security definer, yani bu kısıttan etkilenmiyor.
revoke update on public.profiles from authenticated, anon;
grant update (avatar_path) on public.profiles to authenticated;

-- ------------------------------------------------------------ ekibe Pro
--
-- Kurucu ve moderatörler uygulamayı çalıştıran insanlar; kendi uygulamalarına
-- abone olmaları anlamsız. Kademeyi elle yazmak yerine rozetten türetiyoruz:
-- yeni bir moderatör atandığında ayrıca bir şey yapmak gerekmiyor, rozet
-- alındığında Pro da kendiliğinden kalkıyor.
--
-- Bu ancak yukarıdaki yetki daraltmasıyla birlikte güvenli: rozet
-- yazılabilir olsaydı herkes kendine kurucu deyip bedava Pro olurdu.
create or replace function public.plan_of(account uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when exists (
      select 1 from public.profiles
      where id = account and badge in ('founder', 'moderator')
    ) then 'pro'
    else coalesce((
      select plan from public.subscriptions
      where user_id = account
        and (expires_at is null or expires_at > now())
    ), 'free')
  end;
$$;

revoke all on function public.plan_of(uuid) from public, anon, authenticated;

-- Arayüz de aynı cevabı almalı, yoksa sınırlar kalkıyor ama ekranlar kilitli
-- kalıyordu.
create or replace function public.my_plan()
returns text language sql stable security definer set search_path = '' as $$
  select public.plan_of(auth.uid());
$$;

revoke all on function public.my_plan() from public, anon;
grant execute on function public.my_plan() to authenticated;

-- Rozeti yalnızca sunucu tarafı verebilir. Kurucu/moderatör atamanın tek yolu.
--
--   select public.set_badge('<kullanıcı-uuid>', 'founder');
--   select public.set_badge(id, 'moderator') from auth.users where email = '...';
create or replace function public.set_badge(account uuid, new_badge text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_badge not in ('none', 'verified', 'moderator', 'founder') then
    raise exception 'Invalid badge';
  end if;
  update public.profiles set badge = new_badge::public.profile_badge where id = account;
end;
$$;

revoke all on function public.set_badge(uuid, text) from public, anon, authenticated;
grant execute on function public.set_badge(uuid, text) to service_role;

commit;
