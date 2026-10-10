-- Kişi kartında kullanıcı adı (@nick): güvenli okuma fonksiyonu.
--
-- Uygulama kartın altındaki @nick'i `profiles` tablosundan doğrudan okuyordu.
-- O tablonun okuma kuralı yalnızca bağlantılı olduğun, gönderi/story/yorum
-- paylaşmış ya da sana bildirim göndermiş kişilerin satırını açıyor (doğum
-- tarihi, okul e-postası gibi alanlar da aynı satırda). Bu yüzden çoğu kartta
-- nick görünmüyordu: 11 Ekim'de bir kullanıcı 33 hesaptan 7'sininkini
-- görebiliyordu. Bu fonksiyon yalnızca kullanıcı adını döndürür; tablo
-- kuralları değişmez. 1.1.4 (build 17) bunu kullanıyor; eski sürümler eskisi gibi.
begin;

create or replace function public.profile_username(target uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.username
  from public.profiles p
  where p.id = target
    and auth.uid() is not null
    and p.is_active
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    );
$$;
revoke all on function public.profile_username(uuid) from public, anon;
grant execute on function public.profile_username(uuid) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261011020000', 'profile_username_rpc')
on conflict (version) do nothing;

commit;
