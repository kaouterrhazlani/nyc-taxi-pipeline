{{ config(
    materialized='table',
    schema='FINAL'
) }}

SELECT
    pickup_location_id,
    COUNT(*)                    AS total_pickups,
    AVG(total_amount)           AS avg_fare,
    AVG(trip_distance)          AS avg_distance,
    AVG(trip_duration_min)      AS avg_duration_min,
    AVG(tip_rate)               AS avg_tip_rate
FROM {{ ref('stg_clean_trips') }}
GROUP BY pickup_location_id
ORDER BY total_pickups DESC
