SELECT 
    source_file,
    REGEXP_SUBSTR(source_file, '\\d{4}-\\d{2}') AS mois_fichier,
    COUNT(*) AS total_trajets,
    COUNT(CASE 
        WHEN TO_CHAR(TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6), 'YYYY-MM') != REGEXP_SUBSTR(source_file, '\\d{4}-\\d{2}')
         AND TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6) < DATEADD(day, -1, TO_DATE(REGEXP_SUBSTR(source_file, '\\d{4}-\\d{2}') || '-01'))
        THEN 1 
    END) AS vraies_anomalies_pickup,
    COUNT(CASE 
        WHEN TO_CHAR(TO_TIMESTAMP_NTZ("tpep_dropoff_datetime", 6), 'YYYY-MM') < REGEXP_SUBSTR(source_file, '\\d{4}-\\d{2}') 
         AND TO_CHAR(TO_TIMESTAMP_NTZ("tpep_pickup_datetime", 6), 'YYYY-MM') < REGEXP_SUBSTR(source_file, '\\d{4}-\\d{2}')
        THEN 1 
    END) AS anomalies_dropoff_passe
FROM nyc_taxi_yellow
GROUP BY source_file;