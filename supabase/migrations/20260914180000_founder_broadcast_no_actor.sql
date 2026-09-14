-- founder_broadcast: actor_id boş. Kuruculuk duyurusunda aktör gösterilmiyor;
-- actor_id = kurucu olunca kendine giden satır no_self_notification'a takılıyordu.
begin;

create or replace function public.founder_broadcast(title text, body text, test_only boolean default false)
returns integer language plpgsql security definer set search_path = '' as $$
declare adet integer;
begin
  if not public.is_founder() then raise exception 'FOUNDER_ONLY'; end if;
  if char_length(btrim(title)) = 0 then raise exception 'EMPTY_TITLE'; end if;
  if test_only then
    insert into public.notifications (user_id, kind, title, body)
    values (auth.uid(), 'announcement', btrim(title), btrim(body));
    return 1;
  end if;
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'announcement', btrim(title), btrim(body)
  from public.profiles p where p.is_active;
  get diagnostics adet = row_count;
  return adet;
end;
$$;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20260914180000', 'founder_broadcast_no_actor') on conflict (version) do nothing;

commit;
