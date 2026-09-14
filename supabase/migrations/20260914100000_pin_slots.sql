-- Sabitleme sıralı: kurucu gönderiyi 1., 2., 3. ... sıraya sabitler.
-- pinned_at "ne zaman" (aynı sıradakiler arasında yeni olan önce), pinned_slot
-- "kaçıncı sıra". Eski `set_post_pinned(bool)` yerine `set_post_pin_slot`.

begin;

alter table public.posts add column if not exists pinned_slot smallint;
alter table public.posts drop constraint if exists posts_pinned_slot_check;
alter table public.posts add constraint posts_pinned_slot_check
  check (pinned_slot is null or pinned_slot between 1 and 20);
update public.posts set pinned_slot = 1 where pinned_at is not null and pinned_slot is null;

drop function if exists public.set_post_pinned(uuid, boolean);

-- slot null → sabitlemeyi kaldır.
create or replace function public.set_post_pin_slot(target uuid, slot integer)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if slot is null then
    update public.posts set pinned_at = null, pinned_slot = null where id = target;
  else
    update public.posts
      set pinned_at = now(), pinned_slot = least(greatest(slot, 1), 20)
      where id = target;
  end if;
end;
$$;
revoke all on function public.set_post_pin_slot(uuid, integer) from public, anon;
grant execute on function public.set_post_pin_slot(uuid, integer) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914100000', 'pin_slots') on conflict (version) do nothing;

commit;
