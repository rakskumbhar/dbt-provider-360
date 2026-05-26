{{ config(
    materialized='incremental',
    unique_key='npi',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with impacted_npis as (
    select distinct npi
    from {{ ref('slv_provider_validated') }}
    where is_valid_record
      and npi is not null
    {% if is_incremental() %}
      and silver_loaded_at > (
          select coalesce(max(silver_loaded_at), timestamp '1900-01-01')
          from {{ this }}
      )
    {% endif %}
),

ranked as (
    select
        provider_sk,
        provider_id,
        npi,
        tin,
        provider_first_name,
        provider_last_name,
        organization_name,
        provider_type,
        taxonomy_code,
        credential,
        gender,
        address_line_1,
        address_line_2,
        city,
        state,
        zip5,
        phone,
        email,
        network_status,
        source_system,
        source_file_name,
        source_record_number,
        ingested_at,
        bronze_record_key,
        silver_loaded_at,
        row_number() over (
            partition by npi
            order by ingested_at desc, source_file_name desc, source_record_number desc
        ) as provider_rank
    from {{ ref('slv_provider_validated') }}
    where is_valid_record
      and npi in (select npi from impacted_npis)
)

select
    provider_sk,
    provider_id,
    npi,
    tin,
    provider_first_name,
    provider_last_name,
    organization_name,
    provider_type,
    taxonomy_code,
    credential,
    gender,
    address_line_1,
    address_line_2,
    city,
    state,
    zip5,
    phone,
    email,
    network_status,
    source_system,
    source_file_name,
    source_record_number,
    ingested_at,
    bronze_record_key,
    silver_loaded_at
from ranked
where provider_rank = 1
