{{ config(
    materialized='incremental',
    unique_key='bronze_record_key',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with bronze as (
    select *
    from {{ ref('brz_provider') }}
    {% if is_incremental() %}
        where bronze_record_key not in (
            select bronze_record_key from {{ this }}
        )
    {% endif %}
),

standardized as (
    select
        provider_id,
        nullif(regexp_replace(npi, '[^0-9]', '', 'g'), '') as npi,
        nullif(regexp_replace(tin, '[^0-9]', '', 'g'), '') as tin,
        initcap(trim(provider_first_name)) as provider_first_name,
        initcap(trim(provider_last_name)) as provider_last_name,
        initcap(trim(organization_name)) as organization_name,
        provider_type,
        taxonomy_code,
        credential,
        gender,
        initcap(trim(address_line_1)) as address_line_1,
        initcap(trim(address_line_2)) as address_line_2,
        initcap(trim(city)) as city,
        state,
        left(regexp_replace(zip_code, '[^0-9]', '', 'g'), 5) as zip5,
        regexp_replace(phone, '[^0-9]', '', 'g') as phone,
        email,
        network_status,
        source_system,
        source_file_name,
        source_record_number,
        ingested_at,
        bronze_record_key,
        dbt_loaded_at
    from bronze
),

validated as (
    select
        *,
        array_remove(array[
            case when npi is null then 'NPI_NULL' end,
            case when npi is not null and npi !~ '^[0-9]{10}$' then 'NPI_NOT_10_DIGITS' end,
            case when tin is null then 'TIN_NULL' end,
            case when tin is not null and tin !~ '^[0-9]{9}$' then 'TIN_NOT_9_DIGITS' end,
            case when provider_type not in ('INDIVIDUAL', 'ORGANIZATION') then 'INVALID_PROVIDER_TYPE' end,
            case when provider_type = 'INDIVIDUAL' and (provider_first_name is null or provider_last_name is null) then 'INDIVIDUAL_NAME_MISSING' end,
            case when provider_type = 'ORGANIZATION' and organization_name is null then 'ORGANIZATION_NAME_MISSING' end,
            case when state is null or state !~ '^[A-Z]{2}$' then 'INVALID_STATE' end,
            case when zip5 is null or zip5 !~ '^[0-9]{5}$' then 'INVALID_ZIP' end,
            case when email is not null and email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' then 'INVALID_EMAIL' end,
            case when network_status not in ('ACTIVE', 'TERMINATED', 'PENDING') then 'INVALID_NETWORK_STATUS' end
        ], null) as reject_reasons
    from standardized
)

select
    {{ dbt_utils.generate_surrogate_key(['npi', 'tin', 'provider_id']) }} as provider_sk,
    *,
    cardinality(reject_reasons) = 0 as is_valid_record,
    current_timestamp as silver_loaded_at
from validated
