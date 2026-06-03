{{ config(
    materialized='view'
) }}

SELECT
    CAST(pickup_datetime AS DATE) AS trip_date,
    EXTRACT(year FROM pickup_datetime) AS trip_year,
    EXTRACT(month FROM pickup_datetime) AS trip_month,
    COUNT(*) AS total_trips,
    SUM(passenger_count) AS total_passengers,
    ROUND(SUM(trip_distance * 1.60934), 2) AS total_distance_km,
    ROUND(AVG(trip_distance * 1.60934), 2) AS avg_distance_km,
    SUM(DATEDIFF('minute', pickup_datetime, dropoff_datetime)) AS total_duration_minutes,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(SUM(fare_amount), 2) AS total_fare_revenue,
    ROUND(SUM(tip_amount), 2) AS total_tips,
    ROUND(SUM(tolls_amount), 2) AS total_tolls,
    ROUND(SUM(tip_amount) / NULLIF(SUM(fare_amount), 0) * 100, 2) AS global_tip_percentage,
    ROUND(SUM(total_amount) / NULLIF(SUM(DATEDIFF('minute', pickup_datetime, dropoff_datetime)), 0), 2) AS revenue_per_minute

FROM {{ ref('taxi_yellow_clean') }}
GROUP BY 1, 2, 3