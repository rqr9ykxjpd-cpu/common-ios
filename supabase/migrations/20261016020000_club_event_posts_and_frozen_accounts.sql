-- 1) Kulüp etkinliği akışta (kurucunun isteği, 16 Ekim): etkinlik açılınca
--    kulübün hesabından akışa bir gönderi düşer.
--    * Gönderi `posts` tablosunda sıradan bir satır (tür 'event'); bağ
--      `club_events.post_id`de. `posts`a sütun eklenmiyor, eski sürümlerin
--      sorguları değişmiyor.
--    * Yeni sürüm bu gönderide metni değil etkinlik kartını çiziyor
--      (`get_post_events`). Eski sürümler (1.1.4) metni okuyor; o yüzden metin
--      başlık, tam tarih, yer ve açıklamayı içeriyor.
--    * Kulübün hesabı yoksa gönderi yazılmaz: kimsenin kişisel hesabından onun
--      yerine paylaşım yapılmıyor.
--    * Etkinlik gönderisi ücretsiz plandaki 5 gönderi tavanına sayılmaz ve
--      tavana takılmaz. Kulüp hesabının kendi yazdığı gönderiler için tavan
--      aynen duruyor.
--    * Düzenlenince metin güncellenir, iptal edilince başına "İptal edildi:"
--      gelir; gönderi ve altındaki yorumlar silinmez.
--    * Gönderi yazılamazsa (içerik filtresi vb.) etkinlik yine açılır.
--
-- 2) Dondurulan hesap (kurucunun kararı, 16 Ekim): uygulama açılışta "Hesabın
--    donduruldu" ekranı gösteriyor. Sunucu da dondurulmuş hesabın beğeni, oy,
--    mesaj isteği, buluşma isteği, sağa kaydırma, kulübe katılma ve etkinliğe
--    katılmasını reddediyor (gönderi, yorum, mesaj, hikâye zaten kapalıydı).
--    Eski sürümde (1.1.4) dondurulan kişi için de geçerli.
begin;

-- ---------------------------------------------------------------- 1) Akış

alter table public.club_events
  add column if not exists post_id uuid references public.posts(id) on delete set null;
create unique index if not exists club_events_post_idx
  on public.club_events (post_id) where post_id is not null;

-- Gönderinin metni (eski sürümler için). Türkçe gün/ay adları elle: sunucunun
-- dil ayarına bağlı kalmasın.
create or replace function public.club_event_post_caption(event_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when e.cancelled_at is not null then 'İptal edildi: ' else '' end
      || e.title || E'\n'
      || extract(day from z.t)::int || ' '
      || (array['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'])[extract(month from z.t)::int]
      || ' '
      || (array['Pazar','Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi'])[extract(dow from z.t)::int + 1]
      || ', ' || to_char(z.t, 'HH24:MI')
      || coalesce(' · ' || nullif(concat_ws(', ', nullif(btrim(pl.name), ''), nullif(btrim(e.place_note), '')), ''), '')
      || case when btrim(e.details) <> '' then E'\n\n' || btrim(e.details) else '' end
    from public.club_events e
    cross join lateral (select e.starts_at at time zone 'Europe/Istanbul' as t) z
    left join public.places pl on pl.id = e.place_id
   where e.id = club_event_post_caption.event_id;
$$;
revoke all on function public.club_event_post_caption(uuid) from public, anon, authenticated;

-- Gönderi tavanı: etkinlik gönderisi sayılmaz; `save_club_event` yazarken
-- (yalnızca o işlemin içinde) tavan atlanır. İstemci bu ayarı değiştiremez:
-- `set_config` PostgREST'ten çağrılamıyor.
create or replace function public.enforce_post_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  kademe text;
  adet integer;
begin
  if coalesce(current_setting('common.event_post', true), '') = 'on' then
    return new;
  end if;

  kademe := public.plan_of(new.author_id);
  if kademe in ('plus', 'pro') then
    return new;
  end if;

  select count(*) into adet
  from public.posts p
  where p.author_id = new.author_id
    and not exists (select 1 from public.club_events e where e.post_id = p.id);

  if adet >= 5 then
    raise exception 'QUOTA_POST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- Canlıdaki tanım (16 Ekim) + akış gönderisi.
create or replace function public.save_club_event(
  event_id uuid, club_id uuid, title text, details text,
  starts_at timestamptz, place_id uuid, place_note text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  hedef uuid := save_club_event.event_id;
  kulup uuid := save_club_event.club_id;
  baslik text := btrim(coalesce(save_club_event.title, ''));
  yeni boolean := save_club_event.event_id is null;
  hesap uuid;
  gonderi uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if hedef is not null then
    select e.club_id into kulup from public.club_events e
     where e.id = hedef and e.cancelled_at is null;
    if not found then raise exception 'EVENT_NOT_FOUND'; end if;
  end if;
  if not exists (select 1 from public.clubs c where c.id = kulup and c.is_active) then
    raise exception 'CLUB_NOT_FOUND';
  end if;
  if not public.can_manage_club(kulup) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  if char_length(baslik) not between 1 and 80 then raise exception 'EVENT_TITLE_INVALID'; end if;
  if save_club_event.starts_at is null
     or save_club_event.starts_at < now() - interval '1 hour'
     or save_club_event.starts_at > now() + interval '1 year' then
    raise exception 'EVENT_TIME_INVALID';
  end if;

  if yeni then
    if (select count(*) from public.club_events e
         where e.club_id = kulup and e.cancelled_at is null and e.starts_at > now()) >= 20 then
      raise exception 'EVENT_LIMIT';
    end if;
    insert into public.club_events (club_id, title, details, starts_at, place_id, place_note, created_by)
    values (kulup, baslik, left(coalesce(btrim(save_club_event.details), ''), 500),
            save_club_event.starts_at, save_club_event.place_id,
            left(coalesce(btrim(save_club_event.place_note), ''), 80), auth.uid())
    returning id into hedef;
  else
    update public.club_events e
       set title = baslik,
           details = left(coalesce(btrim(save_club_event.details), ''), 500),
           starts_at = save_club_event.starts_at,
           place_id = save_club_event.place_id,
           place_note = left(coalesce(btrim(save_club_event.place_note), ''), 80),
           updated_at = now()
     where e.id = hedef;
  end if;

  -- Akış: yeni etkinlikte kulübün hesabından gönderi; düzenlemede metni.
  if yeni then
    select a.profile_id into hesap from public.club_accounts a where a.club_id = kulup;
    if hesap is not null then
      begin
        perform set_config('common.event_post', 'on', true);
        insert into public.posts (author_id, caption, kind)
        values (hesap, public.club_event_post_caption(hedef), 'event')
        returning id into gonderi;
        perform set_config('common.event_post', '', true);
        update public.club_events e set post_id = gonderi where e.id = hedef;
      exception when others then
        -- Gönderi yazılamadı; etkinlik yine açık kalsın.
        perform set_config('common.event_post', '', true);
      end;
    end if;
  else
    begin
      update public.posts p
         set caption = public.club_event_post_caption(hedef)
       where p.id = (select e.post_id from public.club_events e where e.id = hedef);
    exception when others then
      null;
    end;
  end if;

  perform public.refresh_club_next_event(kulup);
  return hedef;
end;
$$;
revoke all on function public.save_club_event(uuid, uuid, text, text, timestamptz, uuid, text) from public, anon;
grant execute on function public.save_club_event(uuid, uuid, text, text, timestamptz, uuid, text) to authenticated;

-- Canlıdaki tanım (16 Ekim) + gönderinin metni.
create or replace function public.cancel_club_event(event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  kulup uuid;
begin
  select e.club_id into kulup from public.club_events e
   where e.id = cancel_club_event.event_id and e.cancelled_at is null;
  if not found then raise exception 'EVENT_NOT_FOUND'; end if;
  if not public.can_manage_club(kulup) then raise exception 'CLUB_MANAGER_ONLY'; end if;
  update public.club_events e set cancelled_at = now(), updated_at = now()
   where e.id = cancel_club_event.event_id;
  begin
    update public.posts p
       set caption = public.club_event_post_caption(cancel_club_event.event_id)
     where p.id = (select e.post_id from public.club_events e where e.id = cancel_club_event.event_id);
  exception when others then
    null;
  end;
  perform public.refresh_club_next_event(kulup);
end;
$$;
revoke all on function public.cancel_club_event(uuid) from public, anon;
grant execute on function public.cancel_club_event(uuid) to authenticated;

-- Akıştaki gönderilerin etkinlikleri: kartta tarih, yer, kaç kişi, ben
-- katılıyor muyum. İptal edilen ve geçmiş etkinlik de gelir (kart öyle yazar).
create or replace function public.get_post_events(post_ids uuid[])
returns table (
  post_id uuid, id uuid, club_id uuid, club_name text, club_icon text, accent_hex text,
  title text, details text, starts_at timestamptz,
  place_id uuid, place_name text, place_note text,
  attendee_count integer, going boolean, attendee_avatars text[], cancelled boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.post_id, e.id, c.id, c.name, c.icon, c.accent_hex,
         e.title, e.details, e.starts_at, e.place_id, pl.name, e.place_note,
         (select count(*)::integer from public.club_event_attendees a
            join public.profiles p on p.id = a.user_id and p.is_active
           where a.event_id = e.id
             and not exists (select 1 from public.blocks b
                              where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
                                 or (b.blocker_id = a.user_id and b.blocked_id = auth.uid()))),
         exists (select 1 from public.club_event_attendees a where a.event_id = e.id and a.user_id = auth.uid()),
         array(select p.avatar_path from public.club_event_attendees a
                 join public.profiles p on p.id = a.user_id and p.is_active and p.avatar_path is not null
                where a.event_id = e.id
                  and not exists (select 1 from public.blocks b
                                   where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
                                      or (b.blocker_id = a.user_id and b.blocked_id = auth.uid()))
                order by a.created_at
                limit 3),
         e.cancelled_at is not null or not c.is_active
    from public.club_events e
    join public.clubs c on c.id = e.club_id
    left join public.places pl on pl.id = e.place_id
   where e.post_id = any(get_post_events.post_ids)
     and auth.uid() is not null
   limit 200;
$$;
revoke all on function public.get_post_events(uuid[]) from public, anon;
grant execute on function public.get_post_events(uuid[]) to authenticated;

-- ---------------------------------------------------------------- 2) Dondurma

-- Yalnızca giriş yapmış ve dondurulmuş kişiyi durdurur. Sunucunun kendi
-- işleri (auth.uid() boş) etkilenmez; `block_inactive_authors`tan farkı bu.
create or replace function public.block_frozen_actor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and exists (select 1 from public.profiles p where p.id = auth.uid() and not p.is_active) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return new;
end;
$$;
revoke all on function public.block_frozen_actor() from public, anon, authenticated;

do $$
declare
  tablo text;
begin
  foreach tablo in array array[
    'post_likes', 'comment_votes', 'story_likes', 'message_requests', 'meeting_requests',
    'profile_right_swipes', 'club_members', 'club_event_attendees'
  ] loop
    if to_regclass('public.' || tablo) is not null then
      execute format('drop trigger if exists %I on public.%I', tablo || '_block_frozen', tablo);
      execute format('create trigger %I before insert on public.%I for each row execute function public.block_frozen_actor()',
                     tablo || '_block_frozen', tablo);
    end if;
  end loop;
end;
$$;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261016020000', 'club_event_posts_and_frozen_accounts')
on conflict (version) do nothing;

commit;
