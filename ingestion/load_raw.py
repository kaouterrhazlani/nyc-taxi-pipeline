import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
import requests
import pandas as pd
import io
import os
from dotenv import load_dotenv

load_dotenv()

# Connexion Snowflake
conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse="NYC_TAXI_WH",
    database="NYC_TAXI_DB",
    schema="RAW"
)

print("Connexion Snowflake OK")

# Liste des fichiers à charger
fichiers = [
    f"yellow_tripdata_2024-{str(m).zfill(2)}.parquet"
    for m in range(1, 13)
] + [
    "yellow_tripdata_2025-01.parquet",
    "yellow_tripdata_2025-02.parquet"
]

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"

for fichier in fichiers:
    print(f"\nChargement : {fichier}")
    try:
        url = f"{BASE_URL}/{fichier}"
        response = requests.get(url, timeout=120)
        response.raise_for_status()

        df = pd.read_parquet(io.BytesIO(response.content))
        print(f"  Lignes lues : {len(df):,}")

        success, nchunks, nrows, _ = write_pandas(
            conn,
            df,
            "YELLOW_TAXI_TRIPS",
            auto_create_table=True,
            overwrite=False
        )
        print(f"  Lignes chargées : {nrows:,} ✅")

    except Exception as e:
        print(f"  Erreur : {e} ❌")

conn.close()
print("\nIngestion terminée !")
