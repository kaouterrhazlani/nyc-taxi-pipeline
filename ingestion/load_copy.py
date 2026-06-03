"""Ingestion NYC Yellow Taxi — Méthode 2 (stage interne + COPY INTO).

Pour chaque fichier Parquet :
  1. téléchargement depuis la source (HTTP GET)
  2. PUT du fichier dans le stage interne Snowflake
  3. COPY INTO de la table (Snowflake charge en parallèle, côté serveur)

La table est créée automatiquement à partir du schéma Parquet (INFER_SCHEMA).
COPY INTO est idempotent : un fichier déjà chargé n'est pas rechargé
(PUT OVERWRITE=FALSE pour ne pas réinitialiser l'historique de chargement).

Config : ingestion/config_copy.yaml (distinct du config.yaml de la Méthode 1).
"""

import logging
import os
import tempfile

import requests
import snowflake.connector
import yaml
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("load_copy")

# Config située à côté de ce script (indépendant du dossier d'exécution)
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config_copy.yaml")


def load_config(path=CONFIG_PATH):
    with open(path, "r") as f:
        return yaml.safe_load(f)


def connect(sf):
    conn = snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        role=os.getenv("SNOWFLAKE_ROLE"),
        warehouse=sf["warehouse"],
        database=sf["database"],
        schema=sf["schema"],
    )
    logger.info("Connecté à Snowflake (%s.%s)", sf["database"], sf["schema"])
    return conn


def ensure_setup(conn, ing):
    """Crée le file format et le stage s'ils n'existent pas (idempotent)."""
    cur = conn.cursor()
    cur.execute(f"CREATE FILE FORMAT IF NOT EXISTS {ing['file_format']} TYPE = PARQUET")
    cur.execute(
        f"CREATE STAGE IF NOT EXISTS {ing['stage']} "
        f"FILE_FORMAT = {ing['file_format']}"
    )


def download(url, dest_path, timeout):
    """Télécharge un fichier en streaming (sans tout charger en mémoire)."""
    with requests.get(url, stream=True, timeout=timeout) as resp:
        resp.raise_for_status()
        with open(dest_path, "wb") as f:
            for chunk in resp.iter_content(chunk_size=1024 * 1024):
                f.write(chunk)


def put_file(conn, local_path, stage):
    """Pousse un fichier local dans le stage interne.

    OVERWRITE = FALSE : si le fichier est déjà dans le stage, on ne le ré-uploade
    pas. C'est essentiel pour l'idempotence : ré-uploader changerait l'horodatage
    du fichier et COPY INTO le rechargerait (= doublons). AUTO_COMPRESS = FALSE
    car le Parquet est déjà compressé."""
    # file:// + chemin absolu ; on remplace les \ éventuels pour la portabilité
    uri = "file://" + os.path.abspath(local_path).replace("\\", "/")
    conn.cursor().execute(
        f"PUT '{uri}' @{stage} OVERWRITE = FALSE AUTO_COMPRESS = FALSE"
    )


def create_table_from_stage(conn, table_name, stage, file_format):
    """Crée la table avec les bons types, déduits des fichiers du stage."""
    conn.cursor().execute(
        f"""
        CREATE TABLE IF NOT EXISTS {table_name}
        USING TEMPLATE (
            SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
                   WITHIN GROUP (ORDER BY ORDER_ID)
            FROM TABLE(
                INFER_SCHEMA(
                    LOCATION      => '@{stage}',
                    FILE_FORMAT   => '{file_format}'
                )
            )
        )
        """
    )


def copy_into(conn, table_name, stage, file_format):
    """Charge tous les fichiers du stage dans la table.

    Renvoie le nombre de fichiers effectivement traités (les fichiers déjà
    chargés lors d'un run précédent sont automatiquement ignorés)."""
    cur = conn.cursor()
    cur.execute(
        f"""
        COPY INTO {table_name}
        FROM @{stage}
        FILE_FORMAT = (FORMAT_NAME = '{file_format}')
        MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
        ON_ERROR = ABORT_STATEMENT
        """
    )
    rows = cur.fetchall()
    for row in rows:
        # row[0] = nom du fichier, row[1] = statut (LOADED / LOAD_SKIPPED...)
        logger.info("  COPY %s -> %s", row[0], row[1])
    return len(rows)


def recap(conn, table_name):
    cur = conn.cursor()
    # tpep_pickup_datetime est chargé en NUMBER (microsecondes epoch) dans RAW :
    # on convertit à la volée pour le récap (TO_TIMESTAMP avec scale=6).
    cur.execute(
        f"""
        SELECT
            YEAR(TO_TIMESTAMP("tpep_pickup_datetime", 6))  AS annee,
            MONTH(TO_TIMESTAMP("tpep_pickup_datetime", 6)) AS mois,
            COUNT(*)                                        AS nb_trajets
        FROM {table_name}
        GROUP BY annee, mois
        ORDER BY annee, mois
        """
    )
    logger.info("Récapitulatif %s :", table_name)
    for annee, mois, nb in cur.fetchall():
        if annee is None:
            continue
        logger.info("  %s-%02d : %s trajets", annee, mois, f"{nb:,}")


def main():
    load_dotenv()
    config = load_config()
    sf = config["snowflake"]
    ing = config["ingestion"]
    table = ing["table_name"]
    stage = ing["stage"]
    fmt = ing["file_format"]

    conn = connect(sf)
    try:
        ensure_setup(conn, ing)

        # 1 + 2 : télécharger puis PUT chaque fichier dans le stage
        with tempfile.TemporaryDirectory() as tmp:
            for fichier in ing["fichiers"]:
                url = f"{ing['base_url']}/{fichier}"
                local_path = os.path.join(tmp, fichier)
                logger.info("⬇  %s", fichier)
                try:
                    download(url, local_path, ing["timeout"])
                    put_file(conn, local_path, stage)
                    logger.info("  déposé dans @%s", stage)
                except Exception as e:
                    logger.error("  erreur sur %s : %s ❌", fichier, e)

            # 3 : créer la table (si besoin) puis COPY INTO
            create_table_from_stage(conn, table, stage, fmt)
            loaded = copy_into(conn, table, stage, fmt)
            logger.info("COPY terminé (%s fichier(s) traité(s))", loaded)

        recap(conn, table)
    finally:
        conn.close()
        logger.info("Ingestion terminée")


if __name__ == "__main__":
    main()
