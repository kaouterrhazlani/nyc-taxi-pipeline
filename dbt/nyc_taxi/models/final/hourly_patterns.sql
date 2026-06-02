{{ config(
    materialized='table',
    schema='FINAL'
) }}

SELECT
    pickup_hour,
    pickup_dow,
    time_period,
    COUNT(*)                    AS total_trips,
    AVG(total_amount)           AS avg_fare,
    AVG(trip_duration_min)      AS avg_duration_min,
    AVG(tip_rate)               AS avg_tip_rate
FROM {{ ref('stg_clean_trips') }}
GROUP BY pickup_hour, pickup_dow, time_period
ORDER BY pickup_dow, pickup_hour
