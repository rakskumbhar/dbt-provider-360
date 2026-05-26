# Code Walkthrough

## Project Configuration

### `dbt_project.yml`

Defines the project name, paths, medallion model folders, schemas, tags, and run hooks.

Important behavior:

- Bronze models build in the bronze schema.
- Silver models build in the silver schema.
- Gold models build in the gold schema.
- Audit models build incrementally in the audit schema.
- `on-run-start` logs the run start.
- `on-run-end` logs the run result and optionally publishes a notification.

### `profiles.yml.example`

Defines PostgreSQL connection settings using environment variables:

- `DBT_POSTGRES_HOST`
- `DBT_POSTGRES_PORT`
- `DBT_POSTGRES_USER`
- `DBT_POSTGRES_PASSWORD`
- `DBT_POSTGRES_DATABASE`

The profile uses `schema: analytics`. In dev, custom schemas are prefixed by the `generate_schema_name` macro, producing schemas like `analytics_bronze` and `analytics_gold`.

## Seeds

### `seeds/providers/raw_provider.csv`

Small sample provider feed used for local development and demonstration.

It includes:

- Valid individual provider.
- Valid organization provider.
- Missing NPI example.
- Bad TIN and bad email example.
- Duplicate NPI example to demonstrate deduplication.

In production, replace this with a raw source table or ingestion table.

## Bronze Layer

### `models/bronze/provider/brz_provider.sql`

Reads from the seed `raw_provider`.

What it does:

- Casts raw values to stable types.
- Uppercases controlled fields like provider type, taxonomy code, gender, state, and network status.
- Lowercases email.
- Adds `bronze_record_key` using source metadata.
- Adds `dbt_loaded_at` for load observability.

This model is intentionally light. It is not where business validation belongs.

## Silver Layer

### `models/silver/provider/slv_provider_validated.sql`

This is the main data quality model.

Step 1: Standardization

- Removes non-digits from NPI and TIN.
- Converts provider names, addresses, and city to title case.
- Converts ZIP to five digits.
- Removes non-digits from phone.

Step 2: Validation

Builds `reject_reasons` as a PostgreSQL text array using `array_remove(array[...], null)`.

Examples:

```sql
case when npi is null then 'NPI_NULL' end
case when npi is not null and npi !~ '^[0-9]{10}$' then 'NPI_NOT_10_DIGITS' end
case when tin is not null and tin !~ '^[0-9]{9}$' then 'TIN_NOT_9_DIGITS' end
```

Step 3: Validity Flag

```sql
cardinality(reject_reasons) = 0 as is_valid_record
```

If there are no reject reasons, the row is valid.

### `models/silver/provider/slv_provider_clean.sql`

Keeps only valid records and deduplicates by NPI.

The logic ranks rows by latest ingestion:

```sql
row_number() over (
    partition by npi
    order by ingested_at desc, source_file_name desc, source_record_number desc
)
```

Only rank 1 survives. This creates a current clean provider record.

### `models/silver/provider/slv_provider_rejects.sql`

Keeps only invalid records.

It preserves:

- Source identifiers.
- Source file metadata.
- `reject_reasons` array.
- `reject_reason_text`, a pipe-delimited string for simpler reporting.
- `rejected_at` timestamp.

## Gold Layer

### `models/gold/provider/dim_provider_360.sql`

Creates a current provider dimension.

Important logic:

- Individual provider display name uses first name and last name.
- Organization provider display name uses organization name.
- Carries contact, taxonomy, network, and source audit fields.

### `models/gold/provider/fct_provider_quality.sql`

Creates file-level quality metrics.

Metrics:

- `total_records`
- `accepted_records`
- `rejected_records`
- `reject_rate`

This helps operations teams understand whether a source file is degrading in quality.

## Audit Layer

### `models/audit/audit_model_row_counts.sql`

Stores row counts by model and `invocation_id`.

Use this for reconciliation:

- Did bronze receive the expected volume?
- Did silver rejects spike?
- Did gold row counts move unexpectedly?

### `models/audit/audit_reject_summary.sql`

Aggregates reject reasons by source system and file.

This is the main table for data steward triage.

## Tests

### Generic Tests

`tests/generic/npi_10_digit.sql` checks:

```sql
npi is null or npi !~ '^[0-9]{10}$'
```

`tests/generic/tin_9_digit.sql` checks:

```sql
tin is null or tin !~ '^[0-9]{9}$'
```

### Singular Tests

`assert_no_duplicate_active_npi.sql` prevents duplicate active providers in the gold dimension.

`assert_no_null_provider_names.sql` prevents blank display names in the gold dimension.

### Schema Tests

Schema YAML files add:

- `not_null`
- `unique`
- accepted values
- regex checks through `dbt_expectations`
- unique combinations through `dbt_utils`

## Snapshots

### `snapshots/provider_snapshot.sql`

Tracks historical changes to provider records using dbt snapshots.

The snapshot key is `npi`.

Tracked columns include:

- TIN
- Display name
- Taxonomy
- Credential
- Network status
- Address
- Phone
- Email

## Macros

### `audit_logging.sql`

Logs dbt run start and run end status.

### `email_notifications.sql`

Publishes an alert payload to PostgreSQL using `pg_notify` when alerts are enabled.

The payload contains:

- Subject
- Body
- Recipients

An external listener should send the actual email.

### `generate_schema_name.sql`

Controls schema naming.

In dev:

```text
analytics_bronze
analytics_silver
analytics_gold
```

In prod:

```text
bronze
silver
gold
```

### `model_governance.sql`

Provides a helper macro to grant read access to PostgreSQL roles.

Run it with:

```bash
dbt run-operation apply_provider360_grants --args '{"role_name": "provider_360_readonly"}'
```

## Scripts

### `scripts/run_provider_360.sh`

Runs the full local flow:

1. Install dbt packages.
2. Load seed data.
3. Run snapshot.
4. Build provider models.
5. Run provider tests.
6. Build audit models.

