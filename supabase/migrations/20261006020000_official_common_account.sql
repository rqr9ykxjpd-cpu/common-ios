-- Resmi Common hesabı: adı "Common", kullanıcı adı @common, tikli.
--
-- "common" kullanıcı adı taklit edilmesin diye ayrılmış (20260926010000).
-- Kural herkese açılmıyor; kısıt yalnızca bu hesabın kimliğine izin veriyor,
-- uygulamadaki kullanıcı adı ekranı da "common"ı yine reddediyor.
-- Hesap kurucunun test hesabıydı ("Test acc", @test); test hesabı bayrağı
-- duruyor, yani "Tanıyor olabileceğin kişiler"de çıkmıyor.
begin;

alter table public.profiles drop constraint if exists profiles_username_valid;
alter table public.profiles add constraint profiles_username_valid check (
  username is null
  or public.username_is_valid(username)
  or (username = 'common' and id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b')
);

update public.profiles
set name = 'Common',
    username = 'common',
    username_claimed_at = coalesce(username_claimed_at, now()),
    badge = 'verified'
where id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261006020000', 'official_common_account')
on conflict (version) do nothing;

commit;
