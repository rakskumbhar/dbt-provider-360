# Provider 360 dbt Project on PostgreSQL

Enterprise-ready dbt starter for a healthcare Provider 360 implementation on PostgreSQL using bronze, silver, and gold medallion architecture.

## What Is Included

- Bronze ingestion views over raw provider feeds.
- Silver cleansing, standardization, validation, and reject handling.
- Gold provider 360 dimensions and quality marts.
- Generic and singular data tests for NPI, TIN, ZIP, taxonomy, status, and uniqueness.
- Audit macros for run start, run end, model load counts, and failure summary.
- Optional PostgreSQL `pg_notify` alert hook for external email delivery services.
- Snapshot for provider history / SCD2 tracking.
- CI workflow for dbt deps, compile, seed, run, and test.
- Example seeds so the project can be exercised without a source system.

## Documentation Map

- [docs/POSTGRES_SETUP.md](docs/POSTGRES_SETUP.md): PostgreSQL database, schemas, roles, and dbt profile setup.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): Provider 360 architecture, medallion design, data flow, and enterprise patterns.
- [docs/CODE_WALKTHROUGH.md](docs/CODE_WALKTHROUGH.md): Detailed explanation of how each model, macro, test, snapshot, and script works.
- [docs/OPERATIONS.md](docs/OPERATIONS.md): Daily runbook, quality gates, reject triage, audit, alerting, and promotion.
- [docs/TESTING_NEW_DATA.md](docs/TESTING_NEW_DATA.md): How to test a new batch, incremental audit models, and SCD snapshots.
- [docs/INCREMENTAL_PROCESSING.md](docs/INCREMENTAL_PROCESSING.md): Production-style incremental processing and batch 1/batch 2 test commands.

## Suggested Run Order

```bash
dbt deps
dbt seed
dbt run --select tag:provider360
dbt test --select tag:provider360
dbt snapshot
dbt run --select tag:audit
```

For a wrapper script, run:

```bash
./scripts/run_provider_360.sh
```

## Layering

- `bronze`: Raw, lightly typed, source-aligned provider data.
- `silver`: Cleaned provider records, standardized fields, survivorship-ready keys, and rejects.
- `gold`: Business-consumable Provider 360 dimensions and quality summaries.
- `audit`: Operational logging, model row counts, and data quality summaries.

## Production Notes

1. Replace seed-backed sources with external tables, ingestion tables, or vendor landing tables.
2. Copy `profiles.yml.example` into your dbt profile location and set environment variables.
3. Configure role-based access by schema: raw/bronze read-only, silver restricted, gold consumer-facing.
4. Set `enable_email_alerts: true`, `postgres_notification_channel`, and `email_alert_recipients` only after configuring an external worker that listens for PostgreSQL notifications and sends email.
5. Use separate databases or schemas for `dev`, `qa`, and `prod`.

## Quick PostgreSQL Profile

Copy the example profile:

```bash
mkdir -p ~/.dbt
cp profiles.yml.example ~/.dbt/profiles.yml
```

Set these environment variables or edit the copied profile:

```bash
export DBT_POSTGRES_HOST=localhost
export DBT_POSTGRES_PORT=5432
export DBT_POSTGRES_USER=provider_360_user
export DBT_POSTGRES_PASSWORD=provider_360_password
export DBT_POSTGRES_DATABASE=provider_360_dev
```
