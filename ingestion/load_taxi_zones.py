import os
import sys
import requests
import pandas as pd
import yaml
import base64
from io import StringIO
from dotenv import load_dotenv
from snowflake.snowpark import Session
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

load_dotenv()

with open("config.yaml", "r") as f:
    config = yaml.safe_load(f)

sf = config["snowflake"]
zones_cfg = config["taxi_zones"]
auth = config.get("auth", {})

private_key_b64 = os.getenv("SNOWFLAKE_PRIVATE_KEY_B64")
if private_key_b64:
    pem_data = base64.b64decode(private_key_b64)
else:
    key_path = os.path.expanduser(auth.get("private_key_path", "~/.ssh/snowflake_key.p8"))
    with open(key_path, "rb") as f:
        pem_data = f.read()

pk = serialization.load_pem_private_key(pem_data, password=None, backend=default_backend())
pkb = pk.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)

session = Session.builder.configs({
    "account": os.getenv("SNOWFLAKE_ACCOUNT"),
    "user": os.getenv("SNOWFLAKE_USER"),
    "private_key": pkb,
    "warehouse": sf["warehouse"],
    "database": sf["database"],
    "schema": zones_cfg["target_schema"],
}).create()

print("Connexion Snowpark etablie")
print("\nChargement taxi zones...")

resp = requests.get(zones_cfg["url"], timeout=30)
resp.raise_for_status()

df = pd.read_csv(StringIO(resp.text))
df.columns = ['LOCATION_ID', 'BOROUGH', 'ZONE', 'SERVICE_ZONE']
print(f"  {len(df)} zones lues depuis TLC")

snow_df = session.create_dataframe(df)
snow_df.write.save_as_table(
    f"{sf['database']}.{zones_cfg['target_schema']}.{zones_cfg['target_table']}",
    mode="overwrite"
)

print(f"  {len(df)} zones chargees dans {zones_cfg['target_schema']}.{zones_cfg['target_table']}")
session.close()
print("\ntermine")
