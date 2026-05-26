{{ config(
    unique_key='audit_key',
    on_schema_change='sync_all_columns'
) }}

with model_counts as (
    select 'brz_provider' as model_name, count(*) as row_count from {{ ref('brz_provider') }}
    union all
    select 'slv_provider_validated' as model_name, count(*) as row_count from {{ ref('slv_provider_validated') }}
    union all
    select 'slv_provider_clean' as model_name, count(*) as row_count from {{ ref('slv_provider_clean') }}
    union all
    select 'slv_provider_rejects' as model_name, count(*) as row_count from {{ ref('slv_provider_rejects') }}
    union all
    select 'dim_provider_360' as model_name, count(*) as row_count from {{ ref('dim_provider_360') }}
)

select
    {{ dbt_utils.generate_surrogate_key(["'" ~ invocation_id ~ "'", "model_name"]) }} as audit_key,
    '{{ invocation_id }}' as invocation_id,
    model_name,
    row_count,
    current_timestamp as audited_at
from model_counts

