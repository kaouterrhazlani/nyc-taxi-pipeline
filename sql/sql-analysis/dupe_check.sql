WITH verif_doublons_parfaits AS (
    SELECT 
        source_file,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'VendorID', "VendorID",
            'tpep_pickup_datetime', "tpep_pickup_datetime",
            'tpep_dropoff_datetime', "tpep_dropoff_datetime",
            'passenger_count', "passenger_count",
            'trip_distance', "trip_distance",
            'RatecodeID', "RatecodeID",
            'store_and_fwd_flag', "store_and_fwd_flag",
            'PULocationID', "PULocationID",
            'DOLocationID', "DOLocationID",
            'payment_type', "payment_type",
            'fare_amount', "fare_amount",
            'extra', "extra",
            'mta_tax', "mta_tax",
            'tip_amount', "tip_amount",
            'tolls_amount', "tolls_amount",
            'improvement_surcharge', "improvement_surcharge",
            'total_amount', "total_amount",
            'congestion_surcharge', "congestion_surcharge",
            'Airport_fee', "Airport_fee"
        ) AS contenu_ligne,
        COUNT(*) AS nb_repetitions
    FROM nyc_taxi_yellow
    GROUP BY source_file, contenu_ligne
    HAVING COUNT(*) > 1
)
SELECT 
    source_file,
    COUNT(*) AS nb_groupes_strictement_identiques,
    SUM(nb_repetitions) AS total_lignes_impactees,
    SUM(nb_repetitions - 1) AS total_doublons_parfaits_a_supprimer
FROM verif_doublons_parfaits
GROUP BY source_file;