{% test assert_max_value(model, column_name, max_value) %}
SELECT *
FROM {{ model }}
WHERE {{ column_name }} > {{ max_value }}
{% endtest %}