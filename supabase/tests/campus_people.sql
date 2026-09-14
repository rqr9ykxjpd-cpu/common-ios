-- Directory RPC must stay revoked for clients (App Store 4.3(b)).
begin;

set local role authenticated;
do $$
begin
  begin
    perform public.get_campus_people(20, 0);
    raise exception 'get_campus_people must stay revoked for authenticated';
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
