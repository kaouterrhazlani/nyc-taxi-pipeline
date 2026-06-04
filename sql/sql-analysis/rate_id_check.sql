SELECT "RatecodeID", COUNT(*) 
FROM nyc_taxi_yellow 
GROUP BY "RatecodeID";