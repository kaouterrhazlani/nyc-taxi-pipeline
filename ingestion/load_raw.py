import io
import os
import sys

import pandas as pd
import requests
import yaml
from dotenv import load_dotenv
from snowflake.connector.pandas_tools import write_pandas

sys.path.insert(0, os.path.dirname(__file__))
from snowflake_auth import get_snowflake_connection

load_dotenv()

with open("config.yaml", "r") as f:
    config = yaml.safe_load(f)

sf = config["snowflake"]
ing = config["ingestion"]
tech_cols = ing.get("technical_columns", [])

conn = get_snowflake_connection(config)
print("connecte a snowflake")

if ing.get("truncate_before_load", False):
    cur = conn.cursor()
    cur.execute(f"TRUNCATE TABLE IF EXISTS {sf['schema']}.{ing['table_name']}")
    print("table videe")
    cur.close()

table_exists = False


def get_existing_columns(conn, table_name):
    try:
        cur = conn.cursor()
        cur.execute(f"SHOW COLUMNS IN TABLE {sf['schema']}.{table_name}")
        return [row[2] for row in cur.fetchall()]
    except Exception:
        return []


def add_missing_columns(conn, table_name, df):
    existing = get_existing_columns(conn, table_name)
    if not existing:
        return
    cur = conn.cursor()
    for col in df.columns:
        if col not in existing and col not in tech_cols:
            print(f"  nouvelle colonne detectee : {col}")
            cur.execute(
                f'ALTER TABLE {sf["schema"]}.{table_name} ADD COLUMN "{col}" FLOAT'
            )


fichiers = []
for annee in ing["annees"]:
    for mois in range(1, 13):
        fichiers.append(
            f"yellow_tripdata_{annee}-{str(mois).zfill(2)}.parquet")

for fichier in fichiers:
    print(f"\n{fichier}")
    try:
        url = f"{ing['base_url']}/{fichier}"
        resp = requests.get(url, timeout=ing["timeout"])

        if resp.status_code == 404:
            print("  non disponible - ignore")
            continue
        resp.raise_for_status()

        df = pd.read_parquet(io.BytesIO(resp.content))
        print(f"  {len(df):,} lignes lues")

        df[tech_cols[0]] = fichier
        df[tech_cols[1]] = pd.Timestamp.now()

        if table_exists:
            add_missing_columns(conn, ing["table_name"], df)

        _, _, nrows, _ = write_pandas(
            conn,
            df,
            ing["table_name"],
            auto_create_table=True,
            overwrite=False,
        )
        table_exists = True
        print(f"  {nrows:,} lignes chargees")

    except Exception as e:
        print(f"  erreur : {e}")

conn.close()
print("\ntermine")
