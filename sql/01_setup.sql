-- =====================================================================
-- 01_setup.sql — Mise en place de l'entrepôt NYC Taxi (Méthode 2 / COPY)
-- A exécuter une fois dans un worksheet Snowsight (bouton "Run All").
-- Tout est idempotent : ré-exécutable sans risque.
-- =====================================================================

-- 1. Moteur de calcul (se met en pause tout seul pour économiser les crédits)
CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- 2. Base et schémas (RAW = brut, STAGING = nettoyé, FINAL = analytique)
CREATE DATABASE IF NOT EXISTS NYC_TAXI_DB;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.RAW;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.FINAL;

-- 3. On se place dans le schéma RAW pour la suite
USE WAREHOUSE NYC_TAXI_WH;
USE SCHEMA NYC_TAXI_DB.RAW;

-- 4. Format de fichier : on déclare que les fichiers sources sont du Parquet
CREATE FILE FORMAT IF NOT EXISTS ff_parquet
  TYPE = PARQUET;

-- 5. Stage interne : le "sas" où le script déposera les fichiers avant COPY
CREATE STAGE IF NOT EXISTS nyc_stage
  FILE_FORMAT = ff_parquet;

-- Vérifications utiles :
-- SHOW SCHEMAS IN DATABASE NYC_TAXI_DB;
-- LIST @nyc_stage;
