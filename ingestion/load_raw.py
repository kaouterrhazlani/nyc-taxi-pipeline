import io
import os

import pandas as pd
import requests
import snowflake.connector
import yaml
from dotenv import load_dotenv
from snowflake.connector.pandas_tools import write_pandas

load_dotenv()

with open("config.yaml", "r") as f:
    config = yaml.safe_load(f)

sf = config["snowflake"]
ing = config["ingestion"]

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse=sf["warehouse"],
    database=sf["database"],
    schema=sf["schema"],
)
print("connecté à snowflake")

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
        if col not in existing:
            print(f"  nouvelle colonne détectée : {col}")
            cur.execute(f'ALTER TABLE {sf["schema"]}.{table_name} ADD COLUMN "{col}" FLOAT')


for fichier in ing["fichiers"]:
    print(f"\n{fichier}")
    try:
        url = f"{ing['base_url']}/{fichier}"
        resp = requests.get(url, timeout=ing["timeout"])
        resp.raise_for_status()

        df = pd.read_parquet(io.BytesIO(resp.content))
        print(f"  {len(df):,} lignes lues")
        
        #colonnes techniques ( nom de fichier source + date d'ingestion)
        df[ing["technical_columns"]["source_file_col"]] = fichier
        df[ing["technical_columns"]["ingestion_date_col"]] = pd.Timestamp.now()

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
        print(f"  {nrows:,} lignes chargées")

    except Exception as e:
        print(f"  erreur : {e}")

conn.close()
print("\nterminé")