{{ config(
    materialized='incremental',
    unique_key='bronze_record_key',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

select
    bronze_record_key,
    provider_id,
    npi,
    tin,
    provider_type,
    source_system,
    source_file_name,
    source_record_number,
    ingested_at,
    reject_reasons,
    array_to_string(reject_reasons, '|') as reject_reason_text,
    current_timestamp as rejected_at
from {{ ref('slv_provider_validated') }}
where not is_valid_record
{% if is_incremental() %}
  and bronze_record_key not in (
      select bronze_record_key from {{ this }}
  )
{% endif %}
