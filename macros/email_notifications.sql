{% macro notify_run_status(results) %}
    {% if not var('enable_email_alerts', false) %}
        {% do log("Email alerts disabled. Set enable_email_alerts=true after configuring an external notification runner.", info=true) %}
        {{ return('') }}
    {% endif %}

    {% set failed_nodes = [] %}
    {% for result in results %}
        {% if result.status in ['error', 'fail'] %}
            {% do failed_nodes.append(result.node.name ~ ' (' ~ result.status ~ ')') %}
        {% endif %}
    {% endfor %}

    {% if failed_nodes | length == 0 %}
        {% set subject = 'Provider 360 dbt run succeeded' %}
        {% set body = 'Provider 360 dbt run succeeded. invocation_id=' ~ invocation_id %}
    {% else %}
        {% set subject = 'Provider 360 dbt run failed' %}
        {% set body = 'Provider 360 dbt failures: ' ~ failed_nodes | join(', ') ~ '. invocation_id=' ~ invocation_id %}
    {% endif %}

    {{ send_postgres_notification(subject, body) }}
{% endmacro %}

{% macro send_postgres_notification(subject, body) %}
    {% set notification_channel = var('postgres_notification_channel', 'provider_360_dbt_alerts') %}
    {% set recipients = var('email_alert_recipients', []) %}

    {% if recipients | length == 0 %}
        {% do log("Alert requested but email_alert_recipients is missing. Logging only.", info=true) %}
        {{ return('') }}
    {% endif %}

    {% set sql %}
        select pg_notify(
            '{{ notification_channel }}',
            '{{ {"subject": subject, "body": body, "recipients": recipients} | tojson | replace("'", "''") }}'
        )
    {% endset %}

    {% if execute %}
        {% do run_query(sql) %}
    {% endif %}
{% endmacro %}
