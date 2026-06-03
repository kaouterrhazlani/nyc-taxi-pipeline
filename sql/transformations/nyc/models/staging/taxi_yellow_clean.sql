{{ config(
    materialized='table'
) }}

WITH source_data AS (
    SELECT * FROM {{ source('nyc_taxi', 'nyc_taxi_yellow') }}
),

renamed_and_typed AS (
    SELECT
        "VendorID" AS vendor_id,
        TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6) AS pickup_datetime,
        TO_TIMESTAMP_NTZ("tpep_dropoff_datetime", 6) AS dropoff_datetime,
        "passenger_count" AS passenger_count,
        "trip_distance" AS trip_distance,
        "RatecodeID" AS rate_code_id,
        "store_and_fwd_flag" AS store_and_fwd_flag,
        "PULocationID" AS pickup_location_id,
        "DOLocationID" AS dropoff_location_id,
        "payment_type" AS payment_type_id,
        "fare_amount" AS fare_amount,
        "extra" AS extra_amount,
        "mta_tax" AS mta_tax,
        "tip_amount" AS tip_amount,
        "tolls_amount" AS tolls_amount,
        "improvement_surcharge" AS improvement_surcharge,
        "total_amount" AS total_amount,
        NVL("congestion_surcharge", 0) AS congestion_surcharge,
        NVL("Airport_fee", 0) AS airport_fee,
        NVL("cbd_congestion_fee", 0) AS cbd_congestion_fee,
        source_file,
        TO_DATE(REGEXP_SUBSTR(source_file, '\\d{4}-\\d{2}') || '-01', 'YYYY-MM-DD') AS file_target_date
    FROM source_data
),

filtered_data AS (
    SELECT * FROM renamed_and_typed
    WHERE 
        dropoff_datetime > pickup_datetime
        AND (
            DATE_TRUNC('month', pickup_datetime) = file_target_date
            OR pickup_datetime BETWEEN DATEADD('day', -1, file_target_date) AND file_target_date
        )
        AND total_amount BETWEEN 3.50 AND 500.00
        AND fare_amount >= 2.50
        AND trip_distance BETWEEN 0.1 AND 100.00
        AND passenger_count BETWEEN 1 AND 5
)

SELECT * FROM filtered_data
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY 
        vendor_id, pickup_datetime, dropoff_datetime, 
        pickup_location_id, dropoff_location_id, trip_distance, total_amount
    ORDER BY source_file
) = 1