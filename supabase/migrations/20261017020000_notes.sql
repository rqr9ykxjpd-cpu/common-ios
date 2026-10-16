-- Notlar (kurucunun kararı, 17 Ekim): "Kim nerede"de Kulüpler'in altında
-- bölüme göre ders notları. Yalnızca fotoğraf; not, ücretsiz plandaki 5
-- gönderi tavanına sayılmaz ve takılmaz.
--
-- * Not, `posts` tablosunda tür 'notes' olan sıradan bir gönderi; akışta
--   "Ders notu" olarak görünmeye devam eder. Yeni `department` sütunu notun
--   bölümü. Eski sürümler bu sütunu seçmiyor; etkilenmezler.
-- * Bölümler serbest metin ("İktisat", "İktisat(ingilizce)"…): büyük/küçük
--   harf ve baştaki/sondaki boşluk farkı aynı bölüm sayılır. Bölümü boş
--   eski notlar yazarın profildeki bölümüne düşer.
-- * Listeler `security invoker`: gönderilerin RLS'i (gizlenen, engellenen,
--   dondurulmuş yazar) aynen uygulanır.
begin;

alter table public.posts add column if not exists department text;
alter table public.posts drop constraint if exists posts_department_check;
alter table public.posts add constraint posts_department_check
  check (department is null or char_length(btrim(department)) between 1 and 80);
create index if not exists posts_notes_created_idx
  on public.posts (created_at desc) where kind = 'notes';

-- İçerik filtresi bölüm adına da bakar.
drop trigger if exists content_text_safety on public.posts;
create trigger content_text_safety
before insert or update of caption, place_name, department on public.posts
for each row execute function public.check_content_text_before_write('caption', 'place_name', 'department');

-- Gönderi tavanı: canlıdaki tanım (20261016020000) + notlar.
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
  -- Ders notu tavana takılmaz.
  if new.kind = 'notes' then
    return new;
  end if;

  kademe := public.plan_of(new.author_id);
  if kademe in ('plus', 'pro') then
    return new;
  end if;

  select count(*) into adet
  from public.posts p
  where p.author_id = new.author_id
    and p.kind <> 'notes'
    and not exists (select 1 from public.club_events e where e.post_id = p.id);

  if adet >= 5 then
    raise exception 'QUOTA_POST' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- Not olarak açılıp sonra türü değiştirilerek tavan aşılamasın.
create or replace function public.posts_keep_notes_kind()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.kind = 'notes' and new.kind is distinct from 'notes' then
    raise exception 'NOTES_KIND_LOCKED';
  end if;
  return new;
end;
$$;
drop trigger if exists posts_keep_notes_kind on public.posts;
create trigger posts_keep_notes_kind before update of kind on public.posts
for each row execute function public.posts_keep_notes_kind();

-- Notu olan bölümler: en çok kullanılan yazılışıyla, not sayısı ve son not.
create or replace function public.get_note_departments()
returns table (department text, note_count integer, last_at timestamptz)
language sql
stable
security invoker
set search_path = ''
as $$
  with notlar as (
    select coalesce(nullif(btrim(p.department), ''), nullif(btrim(pr.department), '')) as bolum,
           p.created_at
      from public.posts p
      left join public.profiles pr on pr.id = p.author_id
     where p.kind = 'notes'
  )
  select mode() within group (order by n.bolum), count(*)::integer, max(n.created_at)
    from notlar n
   where n.bolum is not null
   group by lower(n.bolum)
   order by max(n.created_at) desc
   limit 200;
$$;
revoke all on function public.get_note_departments() from public, anon;
grant execute on function public.get_note_departments() to authenticated;

-- Bir bölümün notları (yeniden eskiye); gönderiler istemcide her zamanki
-- gibi getirilir.
create or replace function public.get_department_note_ids(department text)
returns setof uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id
    from public.posts p
    left join public.profiles pr on pr.id = p.author_id
   where p.kind = 'notes'
     and lower(coalesce(nullif(btrim(p.department), ''), nullif(btrim(pr.department), '')))
         = lower(btrim(get_department_note_ids.department))
   order by p.created_at desc
   limit 100;
$$;
revoke all on function public.get_department_note_ids(text) from public, anon;
grant execute on function public.get_department_note_ids(text) to authenticated;

notify pgrst, 'reload schema';

insert into supabase_migrations.schema_migrations (version, name)
values ('20261017020000', 'notes')
on conflict (version) do nothing;

commit;
