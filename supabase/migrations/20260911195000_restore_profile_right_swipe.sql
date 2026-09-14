-- Profile card right-swipe (interest notification) is not people-directory
-- discovery. Re-enable the RPC; keep get_campus_people revoked.

begin;

revoke all on function public.swipe_right_on_profile(uuid)
  from public, anon;
grant execute on function public.swipe_right_on_profile(uuid)
  to authenticated;

commit;
