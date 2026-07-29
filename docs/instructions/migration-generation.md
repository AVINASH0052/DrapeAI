# Profile: Migrations

Use when changing Postgres schema.

## Do

1. Add incremental SQL under `api/db/migrations/` and/or Alembic per repo convention.
2. Document columns/indexes in [../backend/database_schema.md](../backend/database_schema.md).
3. Note rollback approach in the PR.
4. Prefer additive migrations; avoid destructive drops without a backfill plan.
5. Keep demo/seed scripts idempotent.

## Don’t

- Edit historical migrations that already ran in shared environments
- Ship app code that requires a migration without including the migration
