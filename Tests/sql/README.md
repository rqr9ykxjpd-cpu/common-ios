# Isolated moderation SQL checks

This harness runs the complete content-report and text-safety migrations, then
their rollback integration tests, in an in-memory PostgreSQL-compatible
[PGlite](https://pglite.dev/docs/) database. It never connects to Supabase and
does not need project credentials. Tested with Node.js and PGlite **0.5.8**.

From the repository root, install the test engine into a temporary directory:

```sh
sql_test_dir="$(mktemp -d /tmp/common-sql-tests.XXXXXX)"
npm install --prefix "$sql_test_dir" --ignore-scripts --no-audit --no-fund @electric-sql/pglite@0.5.8
PGLITE_MODULE_PATH="$sql_test_dir/node_modules/@electric-sql/pglite/dist/index.js" node Tests/sql/check.mjs
```

The download requires network access; running the tests afterward does not. No
`node_modules`, package lock or Node build configuration is added to the app.
If PGlite is already installed where Node can resolve it, the environment override
can be omitted. SQL paths are resolved relative to the harness file, not the
current working directory. A failure produces a nonzero exit code.

Expected successful output includes `PASS content_text_safety.sql` and
`PASS content_reports.sql`.

## Scope

The scaffold supplies synthetic auth/users, relevant tables, roles and report /
private-message row-level security. It loads the existing moderation migration
and the actual `reports_force_open` function/trigger before applying both new
migrations. Tests exercise normalization and text rejection, unchanged legacy
text, report ownership/evidence, private-message access boundaries, moderator
permissions, actual content deletion and idempotent resolution.

This focused harness does **not** apply every historical migration or replicate
all production RLS policies, Auth, Storage or Edge Functions. Successful checks
do not prove that an uninspected live database has the required schema. Review
and apply the normal migration history during the separate Supabase setup.
