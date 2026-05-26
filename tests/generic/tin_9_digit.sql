{% test tin_9_digit(model, column_name) %}
select *
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} !~ '^[0-9]{9}$'
{% endtest %}
