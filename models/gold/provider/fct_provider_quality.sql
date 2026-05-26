{{ config(
    materialized='incremental',
    unique_key='provider_quality_key',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

{% set ns = namespace(has_max_silver_loaded_at=false) %}
{% if execute and is_incremental() %}
    {% set existing_columns = adapter.get_columns_in_relation(this) %}
    {% for existing_column in existing_columns %}
        {% if existing_column.name | lower == 'max_silver_loaded_at' %}
            {% set ns.has_max_silver_loaded_at = true %}
        {% endif %}
    {% endfor %}
{% endif %}

with impacted_files as (
    select distinct
        source_system,
        source_file_name
    from {{ ref('slv_provider_validated') }}
    where source_system is not null
      and source_file_name is not null
    {% if is_incremental() and ns.has_max_silver_loaded_at %}
      and silver_loaded_at > (
          select coalesce(max(max_silver_loaded_at), timestamp '1900-01-01')
          from {{ this }}
      )
    {% endif %}
),

base as (
    select
        source_system,
        source_file_name,
        count(*) as total_records,
        sum(case when is_valid_record then 1 else 0 end) as accepted_records,
        sum(case when not is_valid_record then 1 else 0 end) as rejected_records,
        max(silver_loaded_at) as max_silver_loaded_at
    from {{ ref('slv_provider_validated') }}
    where (source_system, source_file_name) in (
        select source_system, source_file_name
        from impacted_files
    )
    group by 1, 2
)

select
    {{ dbt_utils.generate_surrogate_key(['source_system', 'source_file_name']) }} as provider_quality_key,
    source_system,
    source_file_name,
    total_records,
    accepted_records,
    rejected_records,
    round(rejected_records::numeric / nullif(total_records, 0), 4) as reject_rate,
    max_silver_loaded_at,
    current_timestamp as gold_loaded_at
from base
