-- Görünen ad gerçek ad: Apple ya da Google'dan geliyor ve değiştirilemiyor.
-- Sağlayıcı ad vermediyse (Apple adı yalnızca ilk girişte veriyor) görünen
-- ad kullanıcı adıdır; o kişi gerçek adını bir kez yazabilir, sonra kilitlenir.
-- Kullanıcı adı her zaman değişebilir. Kural sunucuda: eski sürümlerden de
-- ad değiştirilemez (NAME_LOCKED). SQL editörü (oturumsuz) ve kurucu serbest.
begin;

alter table public.profiles add column if not exists name_locked boolean not null default false;

-- Bugünkü hesaplar: adı kullanıcı adı gibi görünenler (küçük harf, boşluksuz,
-- ya da kullanıcı adının aynısı) bir kez değiştirebilir; diğerleri kilitli.
-- Tetikleyiciler kapalıyken: güncelleme zamanı ve yer etkinliği oynamasın.
alter table public.profiles disable trigger user;
update public.profiles
set name_locked = not (name ~ '^[a-z0-9_.]+$' or lower(name) = lower(coalesce(username, '')))
  -- Resmi Common hesabının adı kullanıcı adıyla aynı ama gerçek ad; kilitli.
  or id = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b';
alter table public.profiles enable trigger user;

create or replace function public.profiles_name_lock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    -- Kayıtta ad sağlayıcıdan gelir; gelmediyse kullanıcı adı yazılır.
    -- (Kullanıcı adı bu tetikleyiciden önce profiles_default_username ile dolar.)
    new.name_locked := not (new.name ~ '^[a-z0-9_.]+$' or lower(new.name) = lower(coalesce(new.username, '')));
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if new.name is not distinct from old.name then
    new.name_locked := old.name_locked;
    return new;
  end if;
  if public.is_founder() then
    return new;
  end if;
  if old.name_locked then
    raise exception 'NAME_LOCKED';
  end if;
  new.name_locked := true;
  return new;
end;
$$;

drop trigger if exists profiles_name_lock on public.profiles;
create trigger profiles_name_lock
before insert or update on public.profiles
for each row execute function public.profiles_name_lock();

insert into supabase_migrations.schema_migrations (version, name)
values ('20261006050000', 'name_lock')
on conflict (version) do nothing;

commit;
