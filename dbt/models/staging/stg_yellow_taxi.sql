-- Modèle de staging : nettoyage + enrichissement des trajets bruts.
-- Équivalent DBT de sql/02_staging.sql (mais versionné, testé, relié par ref/source).

with source as (

    select * from {{ source('raw', 'yellow_taxi_trips') }}

),

cleaned as (

    select
        -- Identifiants / dimensions
        "VendorID"                                       as vendor_id,
        "RatecodeID"                                     as ratecode_id,
        "PULocationID"                                   as pickup_location_id,
        "DOLocationID"                                   as dropoff_location_id,
        "payment_type"                                   as payment_type,
        "store_and_fwd_flag"                             as store_and_fwd_flag,
        "passenger_count"                                as passenger_count,

        -- Dates converties (NUMBER microsecondes epoch -> TIMESTAMP)
        to_timestamp_ntz("tpep_pickup_datetime", 6)      as pickup_datetime,
        to_timestamp_ntz("tpep_dropoff_datetime", 6)     as dropoff_datetime,

        -- Mesures
        "trip_distance"                                  as trip_distance,
        "fare_amount"                                    as fare_amount,
        "tip_amount"                                      as tip_amount,
        "tolls_amount"                                    as tolls_amount,
        "total_amount"                                   as total_amount,

        -- Colonnes enrichies
        datediff('minute',
                 to_timestamp_ntz("tpep_pickup_datetime", 6),
                 to_timestamp_ntz("tpep_dropoff_datetime", 6)) as trip_duration_min,
        date(to_timestamp_ntz("tpep_pickup_datetime", 6))      as pickup_date,
        hour(to_timestamp_ntz("tpep_pickup_datetime", 6))      as pickup_hour,
        dayname(to_timestamp_ntz("tpep_pickup_datetime", 6))   as pickup_dayname

    from source

    where
        -- période valide (élimine les dates aberrantes)
        to_timestamp_ntz("tpep_pickup_datetime", 6) >= '2024-01-01'
        and to_timestamp_ntz("tpep_pickup_datetime", 6) < '2025-03-01'
        -- trajet cohérent dans le temps
        and "tpep_dropoff_datetime" > "tpep_pickup_datetime"
        -- distance plausible
        and "trip_distance" > 0
        and "trip_distance" < 1000
        -- montants non négatifs
        and "fare_amount" >= 0
        and "total_amount" >= 0
        -- passagers : on garde les NULL, on retire les 0 explicites
        and ("passenger_count" is null or "passenger_count" > 0)

)

select * from cleaned
