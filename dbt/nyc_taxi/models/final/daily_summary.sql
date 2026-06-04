{{ config(
    materialized='table',
    schema='FINAL'
) }}

SELECT
    pickup_date,
    COUNT(*)                    AS total_trips,
    SUM(total_amount)           AS total_revenue,
    AVG(trip_distance)          AS avg_distance,
    AVG(trip_duration_min)      AS avg_duration_min,
    AVG(tip_rate)               AS avg_tip_rate,
    AVG(avg_speed_mph)          AS avg_speed_mph
FROM {{ ref('stg_clean_trips') }}
GROUP BY pickup_date
ORDER BY pickup_date
