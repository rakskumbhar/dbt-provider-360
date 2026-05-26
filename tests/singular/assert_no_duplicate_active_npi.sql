select npi
from {{ ref('dim_provider_360') }}
where network_status = 'ACTIVE'
group by npi
having count(*) > 1

