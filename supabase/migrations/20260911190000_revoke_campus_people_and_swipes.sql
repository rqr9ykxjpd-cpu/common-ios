-- People directory + right-swipe notifications read as dating discovery.
-- Keep tables for history, but stop clients calling the RPCs.

begin;

revoke all on function public.get_campus_people(integer, integer)
  from public, anon, authenticated;
revoke all on function public.swipe_right_on_profile(uuid)
  from public, anon, authenticated;

commit;
