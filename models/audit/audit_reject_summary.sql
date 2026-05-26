{{ config(
    unique_key='audit_key',
    on_schema_change='sync_all_columns'
) }}

select
    {{ dbt_utils.generate_surrogate_key(["source_system", "source_file_name", "reject_reason_text"]) }} as audit_key,
    source_system,
    source_file_name,
    reject_reason_text,
    count(*) as rejected_record_count,
    current_timestamp as audited_at
from {{ ref('slv_provider_rejects') }}
group by 1, 2, 3, 4

