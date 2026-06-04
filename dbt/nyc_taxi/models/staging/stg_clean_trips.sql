{{ config(
    materialized='table'
    ) }}

SELECT
    "VendorID"                  AS vendor_id,
    TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)  AS pickup_datetime,
    TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000) AS dropoff_datetime,
    "passenger_count"           AS passenger_count,
    "trip_distance"             AS trip_distance,
    "PULocationID"              AS pickup_location_id,
    "DOLocationID"              AS dropoff_location_id,
    "payment_type"              AS payment_type,
    "fare_amount"               AS fare_amount,
    "tip_amount"                AS tip_amount,
    "total_amount"              AS total_amount,
    "congestion_surcharge"      AS congestion_surcharge,
    "cbd_congestion_fee"        AS cbd_congestion_fee,
    "_source_file"              AS source_file,
    "_ingestion_date"           AS ingestion_date,

    DATEDIFF('minute',
        TO_TIMESTAMP("tpep_pickup_datetime" / 1000000),
        TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000)
    ) AS trip_duration_min,

    CASE
        WHEN DATEDIFF('minute',
            TO_TIMESTAMP("tpep_pickup_datetime" / 1000000),
            TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000)) > 0
        THEN "trip_distance" / (DATEDIFF('minute',
            TO_TIMESTAMP("tpep_pickup_datetime" / 1000000),
            TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000)) / 60.0)
        ELSE 0
    END AS avg_speed_mph,

    CASE WHEN "fare_amount" > 0
        THEN "tip_amount" / "fare_amount"
        ELSE 0
    END AS tip_rate,

    HOUR(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000))      AS pickup_hour,
    DAYOFWEEK(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) AS pickup_dow,
    DATE(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000))      AS pickup_date,
    MONTHNAME(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) AS pickup_month,

    CASE
        WHEN "trip_distance" < 1  THEN 'short'
        WHEN "trip_distance" < 5  THEN 'medium'
        WHEN "trip_distance" < 15 THEN 'long'
        ELSE 'very_long'
    END AS distance_category,

    CASE
        WHEN HOUR(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) BETWEEN 7 AND 9   THEN 'morning_rush'
        WHEN HOUR(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) BETWEEN 17 AND 19 THEN 'evening_rush'
        WHEN HOUR(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) BETWEEN 22 AND 23
          OR HOUR(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) BETWEEN 0 AND 4   THEN 'night'
        ELSE 'daytime'
    END AS time_period

FROM {{ source('raw', 'YELLOW_TAXI_TRIPS') }}

WHERE
    "fare_amount" > 0
    AND "trip_distance" > 0
    AND "trip_distance" < 50
    AND "passenger_count" > 0
    AND "passenger_count" <= 5
    AND "tip_amount" / "fare_amount" <= 1
    AND TO_TIMESTAMP("tpep_pickup_datetime" / 1000000) >= '2024-01-01'
    AND TO_TIMESTAMP("tpep_pickup_datetime" / 1000000) < '2027-01-01'
    AND DATEDIFF('minute',
        TO_TIMESTAMP("tpep_pickup_datetime" / 1000000),
        TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000)) > 0
    AND DATEDIFF('minute',
        TO_TIMESTAMP("tpep_pickup_datetime" / 1000000),
        TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000)) < 300
    AND "trip_distance" / (
    DATEDIFF('minute',
        TO_TIMESTAMP("tpep_pickup_datetime" / 1000000),
        TO_TIMESTAMP("tpep_dropoff_datetime" / 1000000)
    ) / 60.0) <= 100