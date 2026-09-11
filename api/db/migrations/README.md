# Raw SQL migrations — reference only

> **Alembic is the single source of truth for schema changes.**
> Production deploys run `alembic upgrade head` and nothing else.

These `.sql` files are the historical record of how the schema evolved. They are
kept because they are readable and because several were applied by hand to the
production database before Alembic was introduced. **Do not add new files here.**

## Mapping to Alembic revisions

| SQL file | Alembic revision |
|---|---|
| `init.sql` + `0002`–`0007` | `0001_baseline` (no-op; stamp it) |
| `0008_try_on_visualization.sql` | `0002_try_on` |
| `0009_try_on_jobs.sql` | `0003_try_on_jobs` |
| `0010_tryon_input_checks.sql` | `0004_tryon_input_checks` |
| `0011_try_on_sessions.sql` | `0005_try_on_sessions` |
| `0012_item_processing_status.sql` | `0006_item_processing_status` |
| `0013_item_display_name.sql` | `0007_item_display_name` |
| `0014_avatar_profile.sql` | `0008_avatar_profile` |
| (init + alembic) `try_on_jobs.directives` | `0009_try_on_job_directives` |
| (init + alembic) `outfits.slot_fingerprint` | `0010_avatar_slot_fingerprint` |
| (init + alembic) `items.garment_size` / `garment_fit` | `0011_item_size_fit` |

Every revision uses `IF NOT EXISTS` / `DROP CONSTRAINT IF EXISTS`, so running
`alembic upgrade head` against a database already built from `init.sql` is a
safe no-op rather than an error.

## Adding a schema change

```bash
cd api
alembic revision -m "short description"   # edit the generated file
alembic upgrade head                       # apply locally
```

Then mirror the change into `db/init.sql` so fresh databases stay correct.

## Recovering a database that drifted

If a database was built from `init.sql` and never stamped:

```bash
alembic stamp 0001_baseline
alembic upgrade head
```

If a database had SQL files applied by hand up through `0014`, stamp the
matching revision instead of replaying everything:

```bash
alembic stamp 0008_avatar_profile
```
