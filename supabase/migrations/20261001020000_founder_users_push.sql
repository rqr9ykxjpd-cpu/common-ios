-- Kurucu kullanıcı listesi: bildirimi açık mı (1.1).
--
-- "Açık" = hesabın kayıtlı bir cihaz jetonu var. 1.1'den itibaren uygulama
-- her açılışta iOS izni kapalıysa jetonu siliyor; böylece bu bilgi son
-- açılıştaki izni gösteriyor. Dönüş tipi değiştiği için fonksiyon önce
-- kaldırılıyor; gövde 20261001010000 ile aynı, yalnız has_push eklendi.
begin;

drop function if exists public.get_founder_users(text, integer);
create function public.get_founder_users(search text default '', lim integer default 50)
returns table (
  id uuid, name text, department text, academic_year text, avatar_path text,
  badge text, is_verified boolean, is_active boolean, plan text,
  created_at timestamptz, last_active_at timestamptz,
  edu_exempt boolean, edu_verified boolean, has_push boolean
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  return query
    select p.id, p.name, p.department, p.academic_year, p.avatar_path,
           p.badge::text, p.is_verified, p.is_active, public.plan_of(p.id),
           p.created_at, p.last_active_at,
           p.edu_exempt, p.edu_verified_at is not null,
           exists (select 1 from public.device_tokens d where d.user_id = p.id)
    from public.profiles p
    where search = '' or p.name ilike '%' || search || '%' or p.department ilike '%' || search || '%'
    order by p.last_active_at desc
    limit greatest(1, least(lim, 200));
end;
$$;
revoke all on function public.get_founder_users(text, integer) from public, anon;
grant execute on function public.get_founder_users(text, integer) to authenticated;

commit;
