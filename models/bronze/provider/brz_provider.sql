{{ config(
    materialized='incremental',
    unique_key='bronze_record_key',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with source_data as (
    select *
    from {{ ref('raw_provider') }}
    {% if is_incremental() %}
        where {{ dbt_utils.generate_surrogate_key(['source_system', 'source_file_name', 'source_record_number']) }} not in (
            select bronze_record_key from {{ this }}
        )
    {% endif %}
)
--adding comment to test commit
select
    cast(provider_id as {{ dbt.type_string() }}) as provider_id,
    cast(npi as {{ dbt.type_string() }}) as npi,
    cast(tin as {{ dbt.type_string() }}) as tin,
    cast(provider_first_name as {{ dbt.type_string() }}) as provider_first_name,
    cast(provider_last_name as {{ dbt.type_string() }}) as provider_last_name,
    cast(organization_name as {{ dbt.type_string() }}) as organization_name,
    upper(cast(provider_type as {{ dbt.type_string() }})) as provider_type,
    upper(cast(taxonomy_code as {{ dbt.type_string() }})) as taxonomy_code,
    upper(cast(credential as {{ dbt.type_string() }})) as credential,
    upper(cast(gender as {{ dbt.type_string() }})) as gender,
    cast(address_line_1 as {{ dbt.type_string() }}) as address_line_1,
    cast(address_line_2 as {{ dbt.type_string() }}) as address_line_2,
    cast(city as {{ dbt.type_string() }}) as city,
    upper(cast(state as {{ dbt.type_string() }})) as state,
    cast(zip_code as {{ dbt.type_string() }}) as zip_code,
    cast(phone as {{ dbt.type_string() }}) as phone,
    lower(cast(email as {{ dbt.type_string() }})) as email,
    upper(cast(network_status as {{ dbt.type_string() }})) as network_status,
    cast(source_system as {{ dbt.type_string() }}) as source_system,
    cast(source_file_name as {{ dbt.type_string() }}) as source_file_name,
    cast(source_record_number as integer) as source_record_number,
    cast(ingested_at as timestamp) as ingested_at,
    {{ dbt_utils.generate_surrogate_key(['source_system', 'source_file_name', 'source_record_number']) }} as bronze_record_key,
    current_timestamp as dbt_loaded_at
from source_data
