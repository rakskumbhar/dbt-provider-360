{% macro log_run_start() %}
    {% do log("Provider 360 dbt run started. invocation_id=" ~ invocation_id, info=true) %}
{% endmacro %}

{% macro log_run_end(results) %}
    {% set failures = [] %}
    {% for result in results %}
        {% if result.status in ['error', 'fail'] %}
            {% do failures.append(result.node.name ~ ':' ~ result.status) %}
        {% endif %}
    {% endfor %}

    {% if failures | length > 0 %}
        {% do log("Provider 360 dbt run completed with failures: " ~ failures | join(', '), info=true) %}
    {% else %}
        {% do log("Provider 360 dbt run completed successfully. invocation_id=" ~ invocation_id, info=true) %}
    {% endif %}
{% endmacro %}

