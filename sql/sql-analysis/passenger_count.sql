SELECT "passenger_count", COUNT(*) 
FROM nyc_taxi_yellow 
GROUP BY "passenger_count";