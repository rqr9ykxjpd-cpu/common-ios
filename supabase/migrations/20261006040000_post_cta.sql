-- Gönderiye düğme: yorumun yanında "Davet et", "Simgeni seç" ya da "Plus'a
-- geç". Yalnızca resmi Common hesabı, kendi gönderisine ekler.
-- Eski sürümler bu sütunu seçmiyor; düğme yalnızca 1.1.2 ve sonrasında görünür.
begin;

alter table public.posts add column if not exists cta text;
alter table public.posts drop constraint if exists posts_cta_valid;
alter table public.posts add constraint posts_cta_valid
  check (cta is null or cta in ('invite', 'app_icon', 'plus'));

create or replace function public.set_post_cta(target uuid, action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if action is not null and action not in ('invite', 'app_icon', 'plus') then
    raise exception 'INVALID_CTA';
  end if;
  update public.posts p
  set cta = action
  where p.id = target
    and p.author_id = auth.uid()
    and auth.uid() = '0f10b6c0-1f30-4ec0-9103-365cc005fe3b';
  if not found then
    raise exception 'FORBIDDEN';
  end if;
end;
$$;
revoke all on function public.set_post_cta(uuid, text) from public, anon;
grant execute on function public.set_post_cta(uuid, text) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261006040000', 'post_cta')
on conflict (version) do nothing;

commit;
