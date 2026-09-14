# Common fresh project bootstrap

Target: `wwogjakgwzwmffyzpjjo` (the user's new Common project).
`common-fresh.sql` combines the migrations through
`20260911190000_revoke_campus_people_and_swipes.sql` inside sequential
transactions. It refuses to run if any public table already exists. Do not use
on the old project.

Validated with the in-memory `Tests/sql/fresh-install.mjs` Supabase scaffold,
including private-photo access, reporting, content-safety, place-people,
gallery-photo limit, and revoked campus-people / right-swipe client access.
Later files after the last live bootstrap are pushed with `supabase db push`
/ SQL editor and recorded in `supabase_migrations.schema_migrations`. Auth
providers and Edge Function secrets are configured separately from this SQL.

Live install has 27 application tables with RLS and three private media
buckets. Configure Apple/Google Auth, Edge Functions and server secrets
separately. No old users or data are migrated.

Signed links can be used by anyone holding them until expiry; blocking stops
new reads/signing, not a previously downloaded image or unexpired link.
