# Testing New Data, Incremental Audit, and SCD Snapshots

This project uses `seeds/providers/raw_provider.csv` as the active raw provider feed. To test a new batch, replace that file with a new version of the same column layout, then rerun dbt.

## Batch 2 Scenario

The file below is a ready-made second batch:

```text
sample_data/provider_scenarios/raw_provider_batch_2_scd_test.csv
```

It contains:

- `P001`: same NPI as batch 1, but address, phone, and email changed.
- `P002`: same organization NPI as batch 1, but suite, phone, email, and network status changed.
- `P006`: new valid provider.
- `P007`: new invalid provider with bad TIN, expected to go to rejects.

## Test Flow

Start from your current successful batch 1 state.

### 1. Confirm Current Gold and Snapshot State

```sql
select npi, provider_display_name, address_line_1, phone, email, network_status
from analytics_gold.dim_provider_360
order by npi;

select npi, provider_display_name, network_status, dbt_valid_from, dbt_valid_to
from snapshots.provider_snapshot
order by npi, dbt_valid_from;
```

### 2. Replace Active Seed With Batch 2

From the project root:

```bash
cp sample_data/provider_scenarios/raw_provider_batch_2_scd_test.csv seeds/providers/raw_provider.csv
```

### 3. Load and Rebuild Provider Models

```bash
dbt seed --full-refresh
dbt run --select tag:provider360
dbt test --select tag:provider360
```

Expected model counts:

- `slv_provider_validated`: 4 rows
- `slv_provider_clean`: 3 rows
- `slv_provider_rejects`: 1 row
- `dim_provider_360`: 3 rows

### 4. Run Snapshot Again

```bash
dbt snapshot
```

Expected result:

- Existing `P001`/NPI `1234567893` gets a closed historical snapshot row and a new current row.
- Existing `P002`/NPI `1999999998` gets a closed historical snapshot row and a new current row.
- New `P006`/NPI `2222222222` gets a new snapshot row.

Check:

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

### 5. Test Incremental Audit Models

Run audit again:

```bash
dbt run --select tag:audit
```

Check that a new invocation was added:

```sql
select invocation_id, model_name, row_count, audited_at
from analytics_audit.audit_model_row_counts
order by audited_at desc, model_name;
```

Check new reject summary:

```sql
select source_file_name, reject_reason_text, rejected_record_count, audited_at
from analytics_audit.audit_reject_summary
order by audited_at desc;
```

## Best Practice For Real New Data

For real files, keep the same raw landing contract:

- Same column names.
- Source metadata always populated.
- Business identifiers stored as text.
- One immutable source file name per delivery.
- One source record number per row.
- `ingested_at` populated by your ingestion framework.

In production, avoid manually replacing CSV seeds. Use ingestion tables instead, and point `brz_provider` to a real `source()` table.
