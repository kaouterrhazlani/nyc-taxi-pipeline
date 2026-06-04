# NYC Taxi Pipeline — MarvelousSamurai

Pipeline Data Engineering complet permettant l’ingestion, le nettoyage, la transformation et l’analyse des données publiques NYC Yellow Taxi.

Projet réalisé dans le cadre du programme 

**[Documentation technique complète](docs/documentation.md)**


**Simplon Data Engineering P1-2025**.

---

# Objectif du projet

Construire une architecture Data Warehouse moderne permettant :

* ingestion de données volumineuses au format Parquet
* nettoyage et standardisation des données
* transformations analytiques avec dbt
* automatisation CI/CD
* visualisation et reporting

Dataset utilisé :

* Source : NYC TLC Yellow Taxi Trip Records
* Période : 2024–2026
* Volume brut : ~105 millions de trajets

---

# Architecture

```
NYC TLC Data
      ↓

RAW Layer
(YELLOW_TAXI_TRIPS)

      ↓

STAGING Layer
(stg_clean_trips)

      ↓

FINAL Layer
├── daily_summary
├── zone_analysis
└── hourly_patterns

      ↓

Dashboards
(Streamlit / Power BI)
```

Architecture utilisée :

```
RAW → STAGING → FINAL
```

---

# Stack Technique

| Domaine         | Technologies        |
| --------------- | ------------------- |
| Data Warehouse  | Snowflake           |
| Ingestion       | Python, Snowpark    |
| Transformations | dbt Core            |
| CI/CD           | GitHub Actions      |
| Dashboard       | Streamlit, Power BI |
| Qualité         | sqlfluff, flake8    |
| Versioning      | Git / GitHub        |

---

# Structure du Projet

```
nyc-taxi-pipeline/

├── ingestion/
├── sql/
├── dbt/
├── dashboard/
├── .github/workflows/
├── README.md
└── documentation.md
```

---

# Pipeline

## 1. Ingestion

Chargement :

* fichiers Parquet TLC
* données zones NYC
* stockage Snowflake RAW

## 2. Nettoyage

Traitement des anomalies :

* suppression valeurs négatives
* filtrage distances aberrantes
* suppression trajets incohérents
* gestion valeurs manquantes

## 3. Transformations

Création :

* STAGING.stg_clean_trips
* FINAL.daily_summary
* FINAL.zone_analysis
* FINAL.hourly_patterns

## 4. Visualisation

Dashboards :

* Streamlit
* Power BI

---

# Installation

## Cloner

```bash
git clone <repo-url>

cd nyc-taxi-pipeline
```

## Créer environnement

```bash
python -m venv .venv

source .venv/bin/activate

pip install -r requirements.txt
```

## Configurer Snowflake

Créer :

* warehouse
* database
* schemas RAW/STAGING/FINAL

Puis :

```bash
python ingestion/load_copy.py

python ingestion/load_taxi_zones.py
```

## Exécuter dbt

```bash
cd dbt/nyc_taxi

dbt run

dbt test
```

## Dashboard

```bash
streamlit run dashboard/app.py
```

---

# Résultats

| KPI             | Valeur        |
| --------------- | ------------- |
| Volume brut     | 104M+ trajets |
| Volume nettoyé  | 80M+ trajets  |
| Taux rétention  | 77%           |
| Tests dbt       | 66 PASS       |
| Zones analysées | 265           |

---

# Documentation complète

La documentation détaillée du projet (architecture interne, dbt, CI/CD, transformations, monitoring, analyses qualité, etc.) est disponible dans :

**[documentation complète](docs/documentation.md)**

---

# Équipe

MarvelousSamurai

* Kaouter Rhazlani
* Yohan
* Dahani

---

# Licence

MIT License
