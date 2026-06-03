{{ config(
    materialized='view'
) }}

SELECT
    pickup_location_id,
    dropoff_location_id,
    COUNT(*) AS total_trips_on_route,
    ROUND(SUM(total_amount), 2) AS total_revenue_on_route,
    ROUND(AVG(total_amount), 2) AS avg_price_per_trip,
    ROUND(AVG(trip_distance * 1.60934), 2) AS avg_distance_km_on_route,
    ROUND(AVG(tip_amount), 2) AS avg_tip_on_route,
    ROUND(SUM(tip_amount) / NULLIF(SUM(fare_amount), 0) * 100, 2) AS tip_percentage_on_route
FROM {{ ref('taxi_yellow_clean') }}
GROUP BY 1, 2