{{ config(
    materialized='view'
) }}

SELECT
    payment_type_id,
    passenger_count,
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_total_amount,
    ROUND(SUM(tip_amount), 2) AS total_tips_gained,
    ROUND(AVG(tip_amount), 2) AS avg_tip_amount,
    ROUND(SUM(tip_amount) / NULLIF(SUM(fare_amount), 0) * 100, 2) AS tip_ratio_percentage

FROM {{ ref('taxi_yellow_clean') }}
GROUP BY 1, 2