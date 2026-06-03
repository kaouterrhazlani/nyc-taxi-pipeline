-- =====================================================================
-- 02_staging.sql — Nettoyage et enrichissement (couche STAGING)
-- Source : RAW.YELLOW_TAXI_TRIPS  ->  Cible : STAGING.CLEAN_TRIPS
-- A exécuter dans un worksheet Snowsight (Run All). Idempotent.
--
-- Rappels :
--  * les colonnes RAW ont une casse mixte -> guillemets doubles obligatoires
--  * tpep_pickup/dropoff_datetime sont en NUMBER (microsecondes epoch)
--    -> conversion avec TO_TIMESTAMP_NTZ(col, 6)
-- =====================================================================

USE WAREHOUSE NYC_TAXI_WH;
USE SCHEMA NYC_TAXI_DB.STAGING;

CREATE OR REPLACE TABLE CLEAN_TRIPS AS
SELECT
    -- Identifiants / dimensions (renommés en snake_case propre)
    "VendorID"                                       AS vendor_id,
    "RatecodeID"                                     AS ratecode_id,
    "PULocationID"                                   AS pickup_location_id,
    "DOLocationID"                                   AS dropoff_location_id,
    "payment_type"                                   AS payment_type,
    "store_and_fwd_flag"                             AS store_and_fwd_flag,
    "passenger_count"                                AS passenger_count,

    -- Dates converties en vrais timestamps
    TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6)      AS pickup_datetime,
    TO_TIMESTAMP_NTZ("tpep_dropoff_datetime", 6)     AS dropoff_datetime,

    -- Mesures
    "trip_distance"                                  AS trip_distance,
    "fare_amount"                                    AS fare_amount,
    "extra"                                          AS extra,
    "mta_tax"                                        AS mta_tax,
    "tip_amount"                                     AS tip_amount,
    "tolls_amount"                                   AS tolls_amount,
    "improvement_surcharge"                          AS improvement_surcharge,
    "congestion_surcharge"                           AS congestion_surcharge,
    "Airport_fee"                                    AS airport_fee,
    "total_amount"                                   AS total_amount,

    -- Colonnes enrichies (utiles pour l'analyse FINAL)
    DATEDIFF(
        'minute',
        TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6),
        TO_TIMESTAMP_NTZ("tpep_dropoff_datetime", 6)
    )                                                AS trip_duration_min,
    DATE(TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6)) AS pickup_date,
    HOUR(TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6)) AS pickup_hour,
    DAYNAME(TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6)) AS pickup_dayname

FROM RAW.YELLOW_TAXI_TRIPS
WHERE
    -- 1. Période valide : le jeu de données couvre 2024-01 à 2025-02
    --    (élimine les ~51 lignes à dates aberrantes : 2002, 2008, 2026...)
    TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6) >= '2024-01-01'
    AND TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6) <  '2025-03-01'

    -- 2. Trajet cohérent dans le temps : la dépose est après la prise en charge
    AND "tpep_dropoff_datetime" > "tpep_pickup_datetime"

    -- 3. Distance plausible : strictement positive et pas absurde (< 1000 miles)
    AND "trip_distance" > 0
    AND "trip_distance" < 1000

    -- 4. Montants non négatifs (des montants < 0 = erreurs de saisie / remboursements)
    AND "fare_amount" >= 0
    AND "total_amount" >= 0

    -- 5. Passagers : on retire les 0 explicites (erreurs), mais on GARDE les NULL
    --    (trajets valides au champ non renseigné — ~5,4 M lignes, 11% des données)
    AND ("passenger_count" IS NULL OR "passenger_count" > 0);
