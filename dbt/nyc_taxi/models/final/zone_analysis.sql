{{ config(
    materialized='table',
    schema='FINAL'
) }}

SELECT
    z.BOROUGH                   AS borough,
    z.ZONE                      AS zone_name,
    z.SERVICE_ZONE              AS service_zone,
    t.pickup_location_id,
    COUNT(*)                    AS total_pickups,
    AVG(t.total_amount)         AS avg_fare,
    AVG(t.trip_distance)        AS avg_distance,
    AVG(t.trip_duration_min)    AS avg_duration_min,
    AVG(t.tip_rate)             AS avg_tip_rate
FROM {{ ref('stg_clean_trips') }} t
LEFT JOIN {{ source('raw', 'TAXI_ZONES') }} z
    ON t.pickup_location_id = z.LOCATION_ID
WHERE z.BOROUGH IS NOT NULL
  AND z.BOROUGH NOT IN ('Unknown', 'N/A')
GROUP BY z.BOROUGH, z.ZONE, z.SERVICE_ZONE, t.pickup_location_id
ORDER BY total_pickups DESC
