# Provider 360 Operations Runbook

## Daily Batch

```bash
dbt deps
dbt seed --select raw_provider
dbt run --selector provider360_bronze_to_gold
dbt test --selector provider360_quality_gate
dbt snapshot --select provider_snapshot
dbt run --select tag:audit
```

## Quality Gates

Promotion should fail when any of these conditions fail:

- `npi` is null or not 10 digits.
- `tin` is null or not 9 digits.
- active NPI appears more than once in gold.
- provider type is outside `INDIVIDUAL` or `ORGANIZATION`.
- state or ZIP format is invalid.
- provider display name is missing.

## Reject Handling

Rejected rows are stored in `slv_provider_rejects` with the original source keys and pipe-delimited reject reasons. Operational dashboards should use `audit_reject_summary` for trends and `slv_provider_rejects` for record-level triage.

Recommended workflow:

1. Data steward reviews `audit_reject_summary`.
2. Source owner fixes upstream files or MDM data.
3. Batch is reloaded using immutable file metadata.
4. Reject counts are compared across invocations.

## Audit Handling

`audit_model_row_counts` records model counts per `invocation_id`. Use this table to validate volume drift and to reconcile bronze-to-silver-to-gold movement.

## Email Alerts

PostgreSQL does not send email natively from dbt. This project uses `pg_notify` as the database-side alert hook. Enable it only after the platform team creates a listener service, Airflow task, cron worker, Lambda, or application process that listens on the configured channel and sends email through SMTP, SES, SendGrid, or another enterprise email service:

```yaml
vars:
  enable_email_alerts: true
  postgres_notification_channel: provider_360_dbt_alerts
  email_alert_recipients:
    - provider-data-platform@example.com
```

## Environment Promotion

Use separate PostgreSQL databases or schemas for dev, QA, and prod. Recommended controls:

- Dev: full developer privileges in isolated schemas.
- QA: automated deployment, masked production-like data.
- Prod: service account execution with least-privilege grants.
- CI: `dbt deps`, `dbt parse`, `dbt compile`, and selected tests.

## Extension Points

- Add NPPES enrichment into silver as a trusted reference source.
- Add TIN-to-organization hierarchy in gold.
- Add contract, location, specialty, credentialing, and network participation marts.
- Add source freshness checks when replacing the seed with a real raw source.
