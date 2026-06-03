SELECT 
    source_file,
    COUNT(*) AS total_trajets,
    COUNT(CASE WHEN "trip_distance" <= 0 THEN 1 END) AS nb_distances_nulles_ou_negatives,
    COUNT(CASE WHEN "trip_distance" > 100 THEN 1 END) AS nb_distances_exorbitantes,
    ROUND(MAX("trip_distance"), 2) AS distance_la_plus_longue,
    COUNT(CASE WHEN "trip_distance" > 5 AND "total_amount" <= 3.5 THEN 1 END) AS trajets_gratuits_longue_distance

FROM nyc_taxi_yellow
GROUP BY source_file;