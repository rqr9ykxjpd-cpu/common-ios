-- Resmi Common hesabında bölüm ve sınıf yok. Normal hesaplarda ikisi de
-- zorunlu kalıyor; kısıt yalnızca bu hesabın kimliğine boş değere izin
-- veriyor. Uygulama (1.1.2) bu hesapta alanları sormuyor, yerine "Resmi
-- Common hesabı" yazıyor; eski sürümlerde satır boş görünür.
begin;

alter table public.profiles drop constraint if exists profiles_department_check;
alter table public.profiles add constraint profiles_department_check check (
  char_length(btrim(department)) <= 120
  and (char_length(btrim(department)) >= 1 or id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b')
);

alter table public.profiles drop constraint if exists profiles_academic_year_check;
alter table public.profiles add constraint profiles_academic_year_check check (
  char_length(btrim(academic_year)) <= 40
  and (char_length(btrim(academic_year)) >= 1 or id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b')
);

update public.profiles
set department = '', academic_year = ''
where id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261006060000', 'official_account_profile')
on conflict (version) do nothing;

commit;
