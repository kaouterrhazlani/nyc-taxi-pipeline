# Guide de collaboration — NYC Taxi Pipeline

Bienvenue sur le projet. Ce document explique comment travailler ensemble efficacement sur ce pipeline data engineering.

---

## Stack technique

| Outil | Rôle |
|-------|------|
| Snowflake | Data Warehouse (RAW / STAGING / FINAL) |
| DBT Core | Transformations SQL versionnées |
| GitHub Actions | CI/CD automatisé |
| Streamlit | Dashboard de visualisation |
| Python + uv | Scripts d'ingestion |

---

## Repos

| Repo | URL | Usage |
|------|-----|-------|
| Perso (origin) | `git@github.com:TON_USERNAME/nyc-taxi-pipeline.git` | Développement quotidien |
| Simplon (upstream) | `git@github.com:Simplon-DE-P1-2025/nyc-taxi-pipeline-kyd.git` | Suivi formateur + livraison |

> Remplace `TON_USERNAME` par ton propre username GitHub.

---

## Installation locale

### 1. Créer ton repo perso sur GitHub

Va sur https://github.com/new :
- **Name** : `nyc-taxi-pipeline`
- **Visibility** : Public
- Ne coche rien d'autre
- Clique **Create repository**

### 2. Cloner le repo Simplon en local

```bash
git clone git@github.com:Simplon-DE-P1-2025/nyc-taxi-pipeline-kyd.git nyc-taxi-pipeline
cd nyc-taxi-pipeline
```

### 3. Configurer les remotes

```bash
# Ton repo perso devient origin
git remote set-url origin git@github.com:TON_USERNAME/nyc-taxi-pipeline.git

# Le repo Simplon devient upstream
git remote add upstream git@github.com:Simplon-DE-P1-2025/nyc-taxi-pipeline-kyd.git

# Vérifier
git remote -v
# origin    git@github.com:TON_USERNAME/nyc-taxi-pipeline.git
# upstream  git@github.com:Simplon-DE-P1-2025/nyc-taxi-pipeline-kyd.git
```

### 4. Créer l'environnement virtuel

```bash
uv venv .venv
source .venv/bin/activate
```

### 5. Installer les dépendances

```bash
uv pip install snowflake-connector-python dbt-snowflake streamlit pandas pyarrow requests python-dotenv
```

### 6. Configurer les variables d'environnement

```bash
cp .env.example .env
```

Remplis `.env` avec tes credentials Snowflake :

```
SNOWFLAKE_ACCOUNT=TON_ACCOUNT_IDENTIFIER
SNOWFLAKE_USER=TON_USERNAME_SNOWFLAKE
SNOWFLAKE_PASSWORD=TON_PASSWORD
SNOWFLAKE_WAREHOUSE=NYC_TAXI_WH
SNOWFLAKE_DATABASE=NYC_TAXI_DB
SNOWFLAKE_SCHEMA=RAW
```

> Ne committe jamais le fichier `.env` — il est dans le `.gitignore`.

---

## Compte Snowflake

Chaque membre travaille sur **son propre compte Snowflake trial** (gratuit, $400 de crédits, 30 jours).

**Créer son compte :**
1. Va sur https://signup.snowflake.com
2. Choisis : **Enterprise** / **AWS** / **Europe (Paris) eu-west-3**
3. Active le compte via l'email reçu

**Setup identique pour tout le monde :**

```sql
CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS NYC_TAXI_DB;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.RAW;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.FINAL;
```

**Structure des worksheets à créer dans Snowsight :**

```
📄 01_setup.sql     ← warehouse, database, schémas
📄 02_staging.sql   ← nettoyage et transformations
📄 03_final.sql     ← tables analytiques
📄 monitoring.sql   ← suivi crédits et qualité données
```

> Toujours utiliser `NYC_TAXI_WH` et non `COMPUTE_WH`.

---

## Architecture Snowflake

```
NYC_TAXI_DB
├── RAW
│   └── yellow_taxi_trips       ← données brutes Parquet
├── STAGING
│   └── clean_trips             ← données nettoyées + enrichies
└── FINAL
    ├── daily_summary           ← résumé journalier
    ├── zone_analysis           ← analyse par zone
    └── hourly_patterns         ← patterns horaires
```

---

## Architecture des branches

```
main          ← production stable (protégée)
  └── dev     ← intégration (protégée)
        ├── feature/ingestion
        ├── feature/staging
        ├── feature/dbt
        ├── feature/orchestration
        ├── feature/streamlit
        ├── feature/monitoring
        └── feature/docs
```

> `main` et `dev` sont protégées — on ne pousse jamais directement dessus.

---

## Workflow Git au quotidien

### Démarrer une tâche

```bash
git checkout dev
git pull origin dev
git checkout feature/staging
```

### Conventional commits

```bash
git commit -m "feat: créer table STAGING.clean_trips"
git commit -m "fix: corriger filtre distances aberrantes"
git commit -m "chore: mettre à jour requirements"
git commit -m "docs: documenter le schéma de nettoyage"
git commit -m "test: ajouter tests DBT not_null"
git commit -m "refactor: simplifier script ingestion"
```

| Préfixe | Quand l'utiliser |
|---------|-----------------|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `chore` | Tâche technique (deps, config) |
| `docs` | Documentation |
| `test` | Tests |
| `refactor` | Refactoring |

### Pousser sur les deux repos

```bash
git push origin feature/staging
git push upstream feature/staging
```

### Ouvrir une PR

1. Va sur `https://github.com/TON_USERNAME/nyc-taxi-pipeline`
2. Clique **"Compare & pull request"**
3. Base : `dev` ← Compare : `feature/staging`
4. Décris ce que tu as fait
5. Clique **"Create pull request"**

Fais la même PR sur le repo Simplon.

### Après le merge

```bash
git checkout dev
git pull origin dev
git pull upstream dev
git branch -d feature/staging
```

---

## Ce que voit le formateur sur Simplon

- Toutes les branches pushées
- Toutes les PRs
- Le Kanban (Project Board)
- Les issues et leur avancement
- L'historique des commits

Pour une bonne lisibilité :
- Pousse régulièrement sur upstream
- Écris des messages de commit clairs
- Mets à jour les issues (In Progress / Done)
- Commente les PRs pour expliquer tes choix techniques

---

## Ingestion des données

```bash
python ingestion/load_raw.py
```

Vérifier dans Snowflake :

```sql
SELECT
    YEAR(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) AS annee,
    MONTH(TO_TIMESTAMP("tpep_pickup_datetime" / 1000000)) AS mois,
    COUNT(*) AS nb_trajets
FROM RAW.YELLOW_TAXI_TRIPS
GROUP BY annee, mois
ORDER BY annee, mois;
```

---


## CI/CD — GitHub Actions

Le pipeline CI/CD se déclenche automatiquement sur chaque push vers `dev` ou `main`, et sur chaque PR.

**État actuel des jobs :**

| Job | État | Description |
|-----|------|-------------|
| Lint | ✅ Actif | Vérifie la qualité du code Python (flake8) |
| DBT | ⏸ Désactivé | Sera activé après initialisation DBT Core |

**Activer le job DBT** (à faire quand DBT est initialisé) :

Dans `.github/workflows/pipeline.yml`, décommenter le bloc `dbt:` et committer.

**Ajouter les secrets GitHub Actions dans ton repo perso :**

```bash
gh secret set SNOWFLAKE_ACCOUNT --body "TON_ACCOUNT"
gh secret set SNOWFLAKE_USER --body "TON_USERNAME"
gh secret set SNOWFLAKE_PASSWORD --body "TON_PASSWORD"
```

---

## Milestones et issues

| # | Milestone | Sprint |
|---|-----------|--------|
| 1 | Setup Snowflake | Jour 1 |
| 2 | Ingestion RAW | Jour 1 |
| 3 | Nettoyage & Staging | Jour 2 |
| 4 | Transformations DBT | Jour 2 |
| 5 | Tables Analytiques | Jour 2 |
| 6 | Orchestration | Jour 3 |
| 7 | Visualisation Streamlit | Jour 3 |
| 8 | Monitoring | Jour 3 |
| 9 | Documentation & Livrables | Jour 3 |

Avant de commencer une tâche :
1. Assigne-toi l'issue
2. Déplace-la en **In Progress** dans le Kanban
3. Travaille sur la branche correspondante
4. Ferme l'issue quand la PR est mergée

---

## Bonnes pratiques

- Un commit = une responsabilité
- Toujours tirer `dev` avant de créer une branche
- Pousser sur `origin` ET `upstream` régulièrement
- Ne jamais committer `.env`, `__pycache__`, `.venv`
- Tester avant d'ouvrir une PR
- Décrire clairement ce que fait la PR

---

## En cas de problème

Ouvre une issue sur le repo Simplon avec le label approprié.
