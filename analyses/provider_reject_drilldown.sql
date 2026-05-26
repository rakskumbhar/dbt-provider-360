select
    source_system,
    source_file_name,
    reject_reason_text,
    count(*) as rejected_records
from {{ ref('slv_provider_rejects') }}
group by 1, 2, 3
order by rejected_records desc

