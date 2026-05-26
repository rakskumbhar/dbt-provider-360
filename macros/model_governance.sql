{% macro apply_provider360_grants(role_name='PROVIDER_360_READONLY') %}
    {% set schemas = ['bronze', 'silver', 'gold', 'audit'] %}
    {% for schema_name in schemas %}
        {% if target.name in ['prod', 'production'] %}
            {% set physical_schema = schema_name %}
        {% else %}
            {% set physical_schema = target.schema ~ '_' ~ schema_name %}
        {% endif %}

        {% set grant_sql %}
            grant usage on schema {{ physical_schema }} to {{ role_name }};
            grant select on all tables in schema {{ physical_schema }} to {{ role_name }};
            alter default privileges in schema {{ physical_schema }} grant select on tables to {{ role_name }};
        {% endset %}

        {% if execute %}
            {% do run_query(grant_sql) %}
        {% endif %}
    {% endfor %}
{% endmacro %}
