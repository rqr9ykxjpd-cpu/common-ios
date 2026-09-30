-- Kurucu: bir hesabı elle öğrenci olarak doğrula / doğrulamayı kaldır (1.1).
--
-- Kullanıcılar listesindeki "Doğrulanmamış" süzgecinden. Doğrulama, e-posta
-- bağlantısıyla aynı iz bırakır: edu_verified_at ve (rozeti yoksa) Öğrenci
-- rozeti. Öğrenci kilidi açıksa profiles tetikleyicisi görünürlüğü hemen
-- günceller. Kurucu ve moderatör rozetlerine dokunulmaz.
begin;

create or replace function public.founder_set_student_verified(target uuid, verified boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  dogru boolean := coalesce(verified, false);
  sonuc boolean;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  update public.profiles p
     set edu_verified_at = case when dogru then coalesce(p.edu_verified_at, now()) else null end,
         badge = case
           when dogru and p.badge = 'none' then 'verified'::public.profile_badge
           when not dogru and p.badge = 'verified' then 'none'::public.profile_badge
           else p.badge
         end
   where p.id = target
   returning p.edu_verified_at is not null into sonuc;
  if sonuc is null then raise exception 'Profile not found'; end if;
  return sonuc;
end;
$$;
revoke all on function public.founder_set_student_verified(uuid, boolean) from public, anon;
grant execute on function public.founder_set_student_verified(uuid, boolean) to authenticated;

commit;
