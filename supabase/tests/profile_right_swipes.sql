-- Right-swipe RPC must stay revoked for clients (App Store 4.3(b)).
begin;

set local role authenticated;
do $$
begin
  begin
    perform public.swipe_right_on_profile(gen_random_uuid());
    raise exception 'swipe_right_on_profile must stay revoked for authenticated';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlerrm like '%permission denied%' then
        null;
      else
        raise;
      end if;
  end;
end $$;
reset role;

rollback;
