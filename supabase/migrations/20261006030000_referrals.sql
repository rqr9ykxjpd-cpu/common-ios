-- Davet: kayıtta "Seni kim davet etti?" alanına davet edenin kullanıcı adı
-- yazılır. Davet edilen öğrenci e-postasını doğrulayınca davet edene 1 hafta
-- Plus ve bildirim.
--
-- Ödül doğrulamaya bağlı: her doğrulama gerçek bir okul e-postası, sahte
-- hesapla Plus toplanamıyor. Davet eden bir kez ve hesabın ilk 14 gününde
-- yazılabiliyor; eski kullanıcı sonradan "beni o davet etti" diyemiyor.
-- Tabloya istemci doğrudan erişmiyor, yalnızca aşağıdaki fonksiyonlar.
begin;

create table if not exists public.referrals (
  invitee_id uuid primary key references public.profiles(id) on delete cascade,
  inviter_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  rewarded_at timestamptz,
  constraint referrals_not_self check (invitee_id <> inviter_id)
);
create index if not exists referrals_inviter_idx on public.referrals (inviter_id);
alter table public.referrals enable row level security;
revoke all on public.referrals from public, anon, authenticated;

-- Kayıt ekranında yazarken: bu kullanıcı adında açık bir hesap var mı.
-- username_available zaten var olanı ele veriyor; bu da fazlasını değil.
create or replace function public.inviter_exists(candidate text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.profiles p
    where p.username = lower(ltrim(btrim(candidate), '@'))
      and p.is_active
      and p.id <> auth.uid()
  );
$$;
revoke all on function public.inviter_exists(text) from public, anon;
grant execute on function public.inviter_exists(text) to authenticated;

-- Davet edene 1 hafta Plus. Parayla alınmış aboneliğe (Apple yönetiyor),
-- Pro olana (kurucu, moderatör, hediye Pro) ve süresiz hediye Plus'a
-- dokunulmaz; süreli hediye Plus'ın üstüne eklenir. Bildirim her durumda.
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

-- Öğrenci e-postası doğrulandığı an (yalnızca ilk kez).
create or replace function public.referral_reward_on_verify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.edu_verified_at is not null and old.edu_verified_at is null then
    perform public.reward_referral(new.id);
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_referral_reward on public.profiles;
create trigger profiles_referral_reward
after update of edu_verified_at on public.profiles
for each row execute function public.referral_reward_on_verify();

-- Kayıt bitince bir kez. Zaten doğrulanmışsa ödül hemen.
create or replace function public.set_my_inviter(inviter_username text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  ben public.profiles;
  davetci uuid;
begin
  select * into ben from public.profiles where id = auth.uid() and is_active;
  if not found then
    raise exception 'REFERRAL_NO_PROFILE';
  end if;
  if exists (select 1 from public.referrals where invitee_id = ben.id) then
    raise exception 'REFERRAL_ALREADY_SET';
  end if;
  if ben.created_at < now() - interval '14 days' then
    raise exception 'REFERRAL_TOO_LATE';
  end if;

  select p.id into davetci
  from public.profiles p
  where p.username = lower(ltrim(btrim(inviter_username), '@')) and p.is_active;
  if davetci is null then
    raise exception 'REFERRAL_NOT_FOUND';
  end if;
  -- Kendini ya da seni davet etmiş birini yazamazsın.
  if davetci = ben.id or exists (
    select 1 from public.referrals r where r.invitee_id = davetci and r.inviter_id = ben.id
  ) then
    raise exception 'REFERRAL_SELF';
  end if;

  insert into public.referrals (invitee_id, inviter_id) values (ben.id, davetci);
  if ben.edu_verified_at is not null then
    perform public.reward_referral(ben.id);
  end if;
end;
$$;
revoke all on function public.set_my_inviter(text) from public, anon;
grant execute on function public.set_my_inviter(text) to authenticated;

-- Ayarlardaki "Arkadaşını davet et": kaç kişi katıldı, kaçı doğruladı.
create or replace function public.my_referral_summary()
returns table (joined integer, verified integer)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer, count(r.rewarded_at)::integer
  from public.referrals r
  where r.inviter_id = auth.uid();
$$;
revoke all on function public.my_referral_summary() from public, anon;
grant execute on function public.my_referral_summary() to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261006030000', 'referrals')
on conflict (version) do nothing;

commit;
