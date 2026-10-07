-- Davet ödülü, davet eden de doğrulanınca verilir.
--
-- Davet etmek herkese açık; ama öğrenci e-postasını doğrulamamış biri
-- uygulamanın çoğunu kullanamadığı için Plus'ı boşa giderdi. Davet edilen
-- doğrulandığında davet eden henüz hazır değilse ödül bekler; davet eden
-- doğrulandığı (ya da kurucu muaf tuttuğu) an birikmiş her davet için 1'er
-- hafta Plus birden tanımlanır. Kurucu ve moderatör her zaman hazır sayılır.
begin;

create or replace function public.referral_inviter_ready(account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = account
      and p.is_active
      and (p.edu_verified_at is not null or p.edu_exempt or p.badge in ('founder', 'moderator'))
  );
$$;
revoke all on function public.referral_inviter_ready(uuid) from public, anon, authenticated;

-- 20261006030000'deki gövde; tek fark baştaki iki kontrol: davet edilen
-- doğrulanmış, davet eden hazır olmalı. Biri eksikse ödül bekler.
create or replace function public.reward_referral(invitee uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  davet public.referrals;
  abonelik public.subscriptions;
  bitis timestamptz;
  verildi boolean := false;
begin
  select * into davet from public.referrals
  where invitee_id = invitee and rewarded_at is null
  for update;
  if not found then
    return;
  end if;
  if not exists (select 1 from public.profiles where id = invitee and edu_verified_at is not null)
     or not public.referral_inviter_ready(davet.inviter_id) then
    return;
  end if;
  update public.referrals set rewarded_at = now() where invitee_id = invitee;

  -- Satır yoksa (hiç abonelik olmamış) alanlar boş gelir: ücretsiz sayılır.
  select * into abonelik from public.subscriptions where user_id = davet.inviter_id;
  if public.plan_of(davet.inviter_id) <> 'pro'
     and abonelik.original_transaction_id is null
     and not (coalesce(abonelik.plan, 'free') = 'plus' and abonelik.expires_at is null) then
    bitis := greatest(
      coalesce(case when abonelik.plan = 'plus' then abonelik.expires_at end, now()),
      now()
    ) + interval '7 days';
    perform public.set_plan(davet.inviter_id, 'plus', null, 'referral', bitis);
    verildi := true;
  end if;

  -- 'announcement': her sürüm tanıyor; dokununca katılanın kartı açılır.
  insert into public.notifications (user_id, kind, title, body, actor_id)
  values (
    davet.inviter_id,
    'announcement',
    'Davetin katıldı',
    public.profile_display_name(invitee) || ' senin davetinle Common''a katıldı.'
      || case when verildi then ' Sana 1 hafta Plus tanımlandı.' else '' end,
    invitee
  );
end;
$$;
revoke all on function public.reward_referral(uuid) from public, anon, authenticated;

-- Doğrulama anı: kişi davet edilen olarak ödülünü tetikler; davet eden
-- olarak da bekleyen (karşı tarafı doğrulanmış) davetlerini toplar.
create or replace function public.referral_reward_on_verify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  bekleyen record;
begin
  if new.edu_verified_at is not null and old.edu_verified_at is null then
    perform public.reward_referral(new.id);
  end if;
  if (new.edu_verified_at is not null or new.edu_exempt)
     and not (old.edu_verified_at is not null or old.edu_exempt) then
    for bekleyen in
      select r.invitee_id from public.referrals r
      join public.profiles p on p.id = r.invitee_id
      where r.inviter_id = new.id and r.rewarded_at is null and p.edu_verified_at is not null
    loop
      perform public.reward_referral(bekleyen.invitee_id);
    end loop;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_referral_reward on public.profiles;
create trigger profiles_referral_reward
after update of edu_verified_at, edu_exempt on public.profiles
for each row execute function public.referral_reward_on_verify();

-- "Doğrulayan" sayısı ödül verilmiş olanlar değil, e-postasını doğrulamış
-- davet edilenler: ödül davet edenin doğrulanmasını beklerken de görünsün.
create or replace function public.my_referral_summary()
returns table (joined integer, verified integer)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer, count(*) filter (where p.edu_verified_at is not null)::integer
  from public.referrals r
  join public.profiles p on p.id = r.invitee_id
  where r.inviter_id = auth.uid();
$$;
revoke all on function public.my_referral_summary() from public, anon;
grant execute on function public.my_referral_summary() to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261007010000', 'referral_inviter_verified')
on conflict (version) do nothing;

commit;
