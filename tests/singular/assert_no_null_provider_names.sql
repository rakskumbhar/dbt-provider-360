select *
from {{ ref('dim_provider_360') }}
where provider_display_name is null
   or trim(provider_display_name) = ''

