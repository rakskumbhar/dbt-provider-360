{% snapshot provider_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='npi',
      strategy='check',
      check_cols=[
        'tin',
        'provider_display_name',
        'taxonomy_code',
        'credential',
        'network_status',
        'address_line_1',
        'city',
        'state',
        'zip5',
        'phone',
        'email'
      ]
    )
}}

select *
from {{ ref('dim_provider_360') }}

{% endsnapshot %}

