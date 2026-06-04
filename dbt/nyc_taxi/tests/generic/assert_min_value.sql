{% test assert_min_value(model, column_name, min_value) %}
SELECT *
FROM {{ model }}
WHERE {{ column_name }} < {{ min_value }}
{% endtest %}