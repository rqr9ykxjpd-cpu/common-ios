import { readFile } from 'node:fs/promises';
import { isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';

// A temporary installation keeps Node dependencies outside the iOS project.
// Without an override, use a normally installed @electric-sql/pglite package.
const modulePath = process.env.PGLITE_MODULE_PATH;
if (modulePath && !isAbsolute(modulePath)) {
  throw new Error('PGLITE_MODULE_PATH must be an absolute path to the installed PGlite entry point.');
}
const { PGlite } = await import(modulePath ? pathToFileURL(modulePath).href : '@electric-sql/pglite');
const readSQL = (path) => readFile(new URL(`../../supabase/${path}`, import.meta.url), 'utf8');
// No dataDir, connection string or network adapter: this database is in memory.
const db = await PGlite.create();
try {
  // Focused schema scaffold, not a substitute for the complete Supabase history.
  // Auth claims and roles preserve the RLS boundaries exercised by the tests.
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, email text);
    create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema public, auth, storage to authenticated, anon, service_role;
    create type public.report_reason as enum ('spam','harassment','inappropriate','fake_profile','other');
    create type public.profile_badge as enum ('none','founder','moderator');
    create table public.profiles(id uuid primary key references auth.users(id), name text,
      birth_date date, gender text, dating_preference text, university text, department text,
      academic_year text, bio text, is_verified boolean, is_active boolean, discovery_enabled boolean, badge profile_badge);
    create table public.posts(id uuid primary key default gen_random_uuid(), author_id uuid references profiles(id), caption text, media_path text, place_name text);
    create table public.stories(id uuid primary key default gen_random_uuid(), author_id uuid references profiles(id), caption text, media_path text);
    create table public.comments(id uuid primary key default gen_random_uuid(), post_id uuid references posts(id) on delete cascade, author_id uuid references profiles(id), body text);
    create table public.matches(id uuid primary key default gen_random_uuid(), user_a uuid references profiles(id), user_b uuid references profiles(id));
    create table public.messages(id uuid primary key default gen_random_uuid(), match_id uuid references matches(id), sender_id uuid references profiles(id), body text);
    create table public.message_requests(id uuid primary key default gen_random_uuid(), body text);
    create table public.profile_interests(profile_id uuid references profiles(id), interest text);
    create table public.profile_prompts(profile_id uuid references profiles(id), answer text);
    create table public.reports(id uuid primary key default gen_random_uuid(), reporter_id uuid not null references profiles(id), reported_id uuid not null references profiles(id), reason report_reason, details text, created_at timestamptz default now());
    create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
    alter table public.reports enable row level security;
    alter table public.messages enable row level security;
    alter table storage.objects enable row level security;
    create policy "reporters read reports" on public.reports for select to authenticated using (reporter_id = auth.uid());
    create policy "reporters insert reports" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
    create policy "members read messages" on public.messages for select to authenticated using (exists(select 1 from public.matches m where m.id = match_id and auth.uid() in (m.user_a,m.user_b)));
    grant select on all tables in schema public to authenticated;
    grant insert on public.reports to authenticated;
    grant select on storage.objects to authenticated;
  `);

  await db.exec(await readSQL('migrations/20260821190000_moderation.sql'));
  const baseline = await readSQL('migrations/20260821200000_close_profile_insert_hole.sql');
  const forceOpen = baseline.match(/create or replace function public\.reports_force_open\(\)[\s\S]+?for each row execute function public\.reports_force_open\(\);/)?.[0];
  if (!forceOpen) throw new Error('Baseline reports_force_open function/trigger was not found. Update this scaffold to match the migration history.');
  await db.exec(forceOpen);

  for (const migration of ['20260910091000_content_reports.sql', '20260910120000_content_text_safety.sql']) {
    await db.exec(await readSQL(`migrations/${migration}`));
    console.log('APPLIED', migration);
  }
  for (const test of ['content_text_safety.sql', 'content_reports.sql']) {
    await db.exec(await readSQL(`tests/${test}`));
    console.log('PASS', test);
  }
  console.log('Isolated SQL tests passed, including RLS checks. No live database connection.');
} catch (error) {
  console.error({ message: error.message, code: error.code, detail: error.detail, where: error.where });
  process.exitCode = 1;
} finally {
  await db.close();
}
