# NYC Taxi Pipeline — MarvelousSamurai

> Pipeline Data Engineering complet permettant l'ingestion, le nettoyage, la transformation et l'analyse des données publiques NYC Yellow Taxi.
> Réalisé dans le cadre du programme **Simplon Data Engineering P1-2025**.

**[Documentation technique complète](docs/DOCUMENTATION.md)**

---

## Objectif du projet

Construire une architecture Data Warehouse moderne permettant :

- Ingestion de données volumineuses au format Parquet
- Nettoyage et standardisation des données
- Transformations analytiques avec dbt
- Automatisation CI/CD
- Visualisation et reporting

**Dataset :** NYC TLC Yellow Taxi Trip Records | Période : 2024–2026 | Volume brut : ~105 millions de trajets

---

## Architecture

```
NYC TLC Data (CloudFront)
        ↓
RAW Layer (YELLOW_TAXI_TRIPS + TAXI_ZONES)
        ↓
STAGING Layer (stg_clean_trips)
        ↓
FINAL Layer
├── daily_summary
├── zone_analysis
└── hourly_patterns
        ↓
Dashboards (Streamlit / Power BI)
```

---

## Stack Technique

| Domaine | Technologies |
|---|---|
| Data Warehouse | Snowflake |
| Ingestion | Python, Snowpark |
| Transformations | dbt Core |
| CI/CD | GitHub Actions |
| Dashboard | Streamlit, Power BI |
| Qualité | sqlfluff, flake8 |
| Versioning | Git / GitHub |

---

## Structure du projet

```
nyc-taxi-pipeline/
├── ingestion/
├── sql/
├── dbt/
├── dashboard/
├── .github/workflows/
├── docs/
│   └── DOCUMENTATION.md
└── README.md
```

---

## Pipeline

### 1. Ingestion

- Fichiers Parquet TLC via AWS CloudFront
- Données zones NYC (265 zones TLC)
- Stockage Snowflake RAW
- 3 méthodes : write_pandas, COPY INTO, Snowpark

### 2. Nettoyage & Qualité des données

Anomalies détectées et corrigées :

- Distances aberrantes (max RAW : 398 608 miles — GPS glitch)
- Vitesses impossibles (> 100 mph)
- Montants négatifs ou incohérents
- Passagers hors conformité TLC (> 5)
- Durées incohérentes (> 5h ou négatives)

Tests qualité automatisés via dbt :

```bash
cd dbt/nyc_taxi
dbt test    # 69 PASS, 0 ERROR, 0 WARN
```

### 3. Transformations

Tables créées :

- `STAGING.stg_clean_trips`
- `FINAL.daily_summary`
- `FINAL.zone_analysis`
- `FINAL.hourly_patterns`

### 4. Documentation dbt auto-générée

```bash
cd dbt/nyc_taxi
dbt docs generate   # Génère catalog.json + manifest.json dans target/
dbt docs serve      # Interface web → http://localhost:8080
```

L'interface expose le lineage graph, les colonnes, les tests et le SQL compilé de chaque modèle.

### 5. Visualisation

- **Streamlit** : dashboard Python interactif
- **Power BI** : tableaux de bord métier (3 pages)

---

## Installation

```bash
# 1. Cloner
git clone https://github.com/Simplon-DE-P1-2025/nyc-taxi-pipeline-MarvelousSamurai.git
cd nyc-taxi-pipeline-MarvelousSamurai

# 2. Environnement Python
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Credentials
cp .env.example .env
# Éditer .env avec vos credentials Snowflake

# 4. Ingestion
python ingestion/load_copy.py
python ingestion/load_taxi_zones.py

# 5. dbt
cd dbt/nyc_taxi
dbt deps && dbt run && dbt test

# 6. Dashboard
streamlit run dashboard/app.py
```

---

## Résultats

| KPI | Valeur |
|---|---|
| Volume brut | 104M+ trajets |
| Volume nettoyé | 80M+ trajets |
| Taux rétention | 77% |
| Tests dbt | **69 PASS, 0 ERROR** |
| Zones analysées | 265 |
| Documentation dbt | Auto-générée via `dbt docs generate` |

---

## Documentation complète

La documentation détaillée (architecture Snowflake, méthodes d'ingestion, transformations dbt, CI/CD, dashboards, analyses qualité) est disponible dans :

**[docs/DOCUMENTATION.md](docs/DOCUMENTATION.md)**

---

## Équipe MarvelousSamurai

- Kaouter Rhazlani
- Yohan
- Dahani

**Programme :** Simplon Data Engineering P1-2025

---

## Licence

MIT License
