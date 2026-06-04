SELECT 
    source_file,
    COUNT(*) AS total_trajets,
    COUNT(CASE WHEN "total_amount" < 0 THEN 1 END) AS nb_prix_negatifs,
    ROUND(MIN(CASE WHEN "total_amount" < 0 THEN "total_amount" END), 2) AS pire_prix_negatif,
    COUNT(CASE WHEN "total_amount" = 0 THEN 1 END) AS nb_prix_zero,
    COUNT(CASE WHEN "total_amount" > 500 THEN 1 END) AS nb_prix_exorbitants,
    ROUND(MAX("total_amount"), 2) AS prix_le_plus_eleve_trouve
FROM nyc_taxi_yellow
GROUP BY source_file;