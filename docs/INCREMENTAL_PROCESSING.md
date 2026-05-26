# Production-Style Incremental Processing

This project now treats Provider 360 models as production-style incremental models.

The incremental strategy is `merge`, which uses PostgreSQL's standard `MERGE` behavior through dbt:

- matched rows are updated by `unique_key`
- unmatched rows are inserted
- SCD2 history is still handled by `provider_snapshot`

## Model Behavior

| Layer | Model | Incremental Behavior |
| --- | --- | --- |
| Bronze | `brz_provider` | Appends new raw source records by `bronze_record_key`. |
| Silver | `slv_provider_validated` | Appends newly validated bronze records by `bronze_record_key`. |
| Silver | `slv_provider_rejects` | Appends only newly rejected records by `bronze_record_key`. |
| Silver | `slv_provider_clean` | Maintains current best valid provider record by `npi`, but only re-merges NPIs impacted by newly validated rows. |
| Gold | `dim_provider_360` | Maintains current Provider 360 dimension by `npi`, but only re-merges changed/current NPIs from silver clean. |
| Gold | `fct_provider_quality` | Maintains file-level quality facts by source system and file, but only re-merges files impacted by newly validated rows. |
| Audit | audit models | Appends operational audit metrics by dbt invocation or source file. |
| Snapshot | `provider_snapshot` | Tracks SCD2 history from the current gold dimension. |

## Important Concept

The CSV seed is only a local stand-in for a real ingestion table.

In production, an ingestion process should append new raw records to a landing table. Locally, we simulate each new incoming file by replacing `seeds/providers/raw_provider.csv` with a batch file and running:

```bash
dbt seed --full-refresh
```

Then dbt incremental models append or update from that current batch.

Do not run `dbt run --full-refresh` for batch 2 unless you intentionally want to rebuild all dbt models from scratch.

If you rerun the same batch without changing the seed, the optimized models should generally show `MERGE 0` for bronze, validated silver, rejects, clean current-state, and gold current-state models. A non-zero merge should indicate new or impacted records/files.

## Fresh Start With Batch 1

Use this when you want a clean development reset.

```bash
cp sample_data/provider_scenarios/raw_provider_batch_1_initial.csv seeds/providers/raw_provider.csv

dbt seed --full-refresh
dbt run --full-refresh --select tag:provider360
dbt test --select tag:provider360
dbt snapshot
dbt run --select tag:audit
```

Expected after batch 1:

- `brz_provider`: 5 rows
- `slv_provider_validated`: 5 rows
- `slv_provider_clean`: 2 rows
- `slv_provider_rejects`: 2 rows
- `dim_provider_360`: 2 rows

## Incremental Batch 2

Replace only the seed/staging file. Then run dbt models incrementally.

```bash
cp sample_data/provider_scenarios/raw_provider_batch_2_scd_test.csv seeds/providers/raw_provider.csv

dbt seed --full-refresh
dbt run --select tag:provider360
dbt test --select tag:provider360
dbt snapshot
dbt run --select tag:audit
```

Expected after batch 2:

- `brz_provider`: 9 rows total
- `slv_provider_validated`: 9 rows total
- `slv_provider_clean`: 3 current valid providers
- `slv_provider_rejects`: 3 total rejected records
- `dim_provider_360`: 3 current providers
- `provider_snapshot`: closed old rows for changed NPIs and open rows for current values

## Verification Queries

```sql
select count(*) from analytics_bronze.brz_provider;
select count(*) from analytics_silver.slv_provider_validated;
select count(*) from analytics_silver.slv_provider_clean;
select count(*) from analytics_silver.slv_provider_rejects;
select count(*) from analytics_gold.dim_provider_360;
```

Check SCD2 history:

```sql
select
    npi,
    provider_display_name,
    address_line_1,
    phone,
    email,
    network_status,
    dbt_valid_from,
    dbt_valid_to
from snapshots.provider_snapshot
order by npi, dbt_valid_from;
```

Check raw append traceability:

```sql
select
    source_file_name,
    count(*) as raw_records
from analytics_bronze.brz_provider
group by 1
order by 1;
```

## Operational Rule

Use these commands intentionally:

- First build or structural rebuild: `dbt run --full-refresh --select tag:provider360`
- Normal daily batch: `dbt run --select tag:provider360`
- Snapshot after each successful gold build: `dbt snapshot`

This keeps raw and validated history while still presenting current-state provider records in silver clean and gold.
