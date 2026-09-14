import { readFile, readdir } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { dirname, resolve } from 'node:path';

// In-memory migration compatibility check; never connects to a live project.
const entry = process.env.PGLITE_MODULE_PATH;
if (!entry) throw new Error('Set PGLITE_MODULE_PATH to the installed PGlite dist/index.js');
const { PGlite } = await import(pathToFileURL(entry).href);
const { pgcrypto } = await import(pathToFileURL(resolve(dirname(entry), 'contrib/pgcrypto.js')).href);
const db = await PGlite.create({ extensions: { pgcrypto } });
let current = 'Supabase scaffold';
try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create role supabase_auth_admin; create role supabase_storage_admin;
    create schema auth; create schema storage; create schema extensions;
    create table auth.users(id uuid primary key, email text, raw_app_meta_data jsonb default '{}', raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create function auth.jwt() returns jsonb language sql stable as
      $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''),'{}')::jsonb $$;
    create table storage.buckets(id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, owner uuid, owner_id text, metadata jsonb);
    create function storage.foldername(text) returns text[] language sql immutable as
      $$ select (string_to_array($1, '/'))[1:array_length(string_to_array($1, '/'), 1)-1] $$;
    alter table storage.objects enable row level security;
    grant usage on schema public, auth, storage to anon, authenticated, service_role;
    grant all on all tables in schema storage to anon, authenticated, service_role;
    alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
    alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
    create publication supabase_realtime;
  `);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  const files = (await readdir(directory)).filter(f => f.endsWith('.sql')).sort();
  if (process.env.COMMON_BOOTSTRAP_SQL) {
    current = 'atomic bootstrap';
    await db.exec(await readFile(process.env.COMMON_BOOTSTRAP_SQL, 'utf8'));
  } else for (const file of files) {
    current = file;
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
    console.log('APPLIED', file);
  }
  console.log('Fresh migration compatibility passed:', files.length);
  for (const test of ['private_profile_media.sql', 'content_reports.sql', 'content_text_safety.sql', 'campus_people.sql', 'place_people.sql', 'profile_right_swipes.sql', 'gallery_photos.sql']) {
    current = test;
    await db.exec(await readFile(new URL(`../../supabase/tests/${test}`, import.meta.url), 'utf8'));
    console.log('PASS', test);
  }
  console.log('PUBLIC TABLES', (await db.query("select tablename, rowsecurity from pg_tables where schemaname='public' order by tablename")).rows);
  console.log('STORAGE BUCKETS', (await db.query('select id, public from storage.buckets order by id')).rows);
} catch (error) {
  console.error({ migration: current, message: error.message, code: error.code, detail: error.detail, where: error.where });
  process.exitCode = 1;
} finally { await db.close(); }
