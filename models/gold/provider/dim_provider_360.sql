{{ config(
    materialized='incremental',
    unique_key='npi',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with impacted_providers as (
    select distinct npi
    from {{ ref('slv_provider_clean') }}
    where npi is not null
    {% if is_incremental() %}
      and silver_loaded_at > (
          select coalesce(max(silver_loaded_at), timestamp '1900-01-01')
          from {{ this }}
      )
    {% endif %}
)

select
    provider_sk,
    npi,
    tin,
    provider_id,
    provider_type,
    case
        when provider_type = 'INDIVIDUAL'
            then concat_ws(' ', provider_first_name, provider_last_name)
        else organization_name
    end as provider_display_name,
    provider_first_name,
    provider_last_name,
    organization_name,
    taxonomy_code,
    credential,
    gender,
    network_status,
    address_line_1,
    address_line_2,
    city,
    state,
    zip5,
    phone,
    email,
    source_system,
    ingested_at as source_ingested_at,
    silver_loaded_at,
    current_timestamp as gold_loaded_at
from {{ ref('slv_provider_clean') }}
where npi in (select npi from impacted_providers)
