# Contrôle qualité — NYC Yellow Taxi (`nyc_taxi_yellow`)

Document de synthèse des analyses SQL du dossier `sql/sql-analysis/`, croisées avec la documentation officielle TLC.

## Source et références TLC

| Ressource | Lien |
| :--- | :--- |
| Page des trip records | [TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) |
| Dictionnaire Yellow (PDF, mars 2025) | [data_dictionary_trip_records_yellow.pdf](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf) |
| Guide utilisateur | [trip_record_user_guide.pdf](https://www.nyc.gov/assets/tlc/downloads/pdf/trip_record_user_guide.pdf) |

**Contexte (TLC)** : les fichiers Parquet mensuels proviennent des Technology Service Providers (TSP), pas de la TLC. La commission ne garantit pas l’exactitude des données. Publication mensuelle avec délai d’environ deux mois. Les zones `PULocationID` / `DOLocationID` (1–263) se joignent au référentiel [Taxi Zones](https://data.cityofnewyork.us/Transportation/NYC-Taxi-Zones/d3c5-ddgc).

**Champs utiles pour ce contrôle** :

| Champ | Règle TLC (résumé) |
| :--- | :--- |
| `tpep_pickup_datetime` / `tpep_dropoff_datetime` | Engagement / désengagement du taximètre |
| `trip_distance` | Distance en miles (taximètre) |
| `RatecodeID` | 1 = standard, 2 = JFK, 3 = Newark, 4 = Nassau/Westchester, 5 = négocié, 6 = group ride, **99 = null/inconnu** |
| `passenger_count` | Saisie conducteur ; pas de liste fermée dans le dictionnaire, mais valeur métier attendue ≥ 1 pour un trajet facturé |
| `total_amount` | Montant total ; négatifs / extrêmes = anomalies TSP ou corrections |

**Périmètre analysé** : 28 fichiers `yellow_tripdata_YYYY-MM.parquet` (2024-01 → 2026-04), **~104,8 M** lignes au total (agrégat des requêtes globales).

---

## Synthèse exécutive

| Dimension | Ordre de grandeur | Gravité | Action pipeline |
| :--- | :--- | :--- | :--- |
| Dates vs mois fichier | &lt; 21 lignes / fichier (souvent 0–5) | Faible | Tolérance J-1 déjà prévue dans `taxi_yellow_clean.sql` |
| Doublons parfaits | **5** lignes à supprimer sur 4 mois | Très faible | `QUALIFY ROW_NUMBER() = 1` |
| `RatecodeID` | ~18,7 % NULL ; **99** = 1,7 M ; codes 1–6 = ~79,6 % | Moyenne | Filtrer ou mapper 99 ; exclure NULL |
| `passenger_count` | ~18,7 % NULL ; **713 k** à 0 ; **7–9** = 448 lignes | Élevée | `BETWEEN 1 AND 5` (ou 6 selon modèle) |
| `trip_distance` | 1,5–4 % ≤ 0 ; max jusqu’à **386 088** miles | Élevée | `BETWEEN 0.1 AND 100` |
| `total_amount` | ~1,5–3 % négatifs ; max jusqu’à **863 380 $** | Élevée | `BETWEEN 3.50 AND 500` |

Les volumes d’anomalies temporelles et de doublons sont négligeables. Les pertes principales au nettoyage viennent des **NULL**, **passenger_count = 0**, **distances** et **montants** hors plage réaliste.

---

## 1. Cohérence des dates avec le mois du fichier

**Requête** : [analyse_check_dropoff_deposit.sql](analyse_check_dropoff_deposit.sql)  
**Résultat** : [analyse_check_dropoff_deposit_result.csv](analyse_check_dropoff_deposit_result.csv)

**Logique** :

- `vraies_anomalies_pickup` : pickup hors mois du fichier **et** antérieur au dernier jour du mois précédent (erreurs type 2008/2045).
- `anomalies_dropoff_passe` : dropoff et pickup tous deux strictement avant le mois du fichier.

**Constats** (extrait) :

| Fichier | Trajets | Anomalies pickup | Anomalies dropoff passé |
| :--- | ---: | ---: | ---: |
| yellow_tripdata_2024-06.parquet | 3 539 193 | 4 | **21** |
| yellow_tripdata_2025-01.parquet | 3 475 226 | 0 | 13 |
| yellow_tripdata_2024-12.parquet | 3 668 371 | 3 | 10 |
| yellow_tripdata_2026-04.parquet | 3 800 664 | 4 | 4 |

Sur l’ensemble des mois : **0 à 7** anomalies pickup par fichier, **0 à 21** dropoff « passé ». Taux &lt; 0,001 %.

**Alignement TLC** : les horodatages doivent refléter le cycle taximètre ; un léger débordement fin/début de mois entre fichiers mensuels est attendu (TLC / guide Parquet).

**Recommandation** : conserver la règle `DATE_TRUNC('month', pickup) = mois_fichier OR pickup entre J-1 et début de mois` (voir `sql/transformations/nyc/models/staging/taxi_yellow_clean.sql`).

---

## 2. Doublons exacts (toutes colonnes métier)

**Requête** : [dupe_check.sql](dupe_check.sql)  
**Résultat** : [dupe_check_result.csv](dupe_check_result.csv)

| Fichier | Groupes identiques | Lignes impactées | Doublons à supprimer |
| :--- | ---: | ---: | ---: |
| yellow_tripdata_2024-02.parquet | 1 | 2 | 1 |
| yellow_tripdata_2024-07.parquet | 1 | 2 | 1 |
| yellow_tripdata_2024-10.parquet | 2 | 4 | 2 |
| yellow_tripdata_2025-07.parquet | 1 | 2 | 1 |

**Total** : 4 fichiers, **5** doublons parfaits sur ~104,8 M lignes (&lt; 0,000005 %).

**Recommandation** : déduplication par clé métier (`QUALIFY ROW_NUMBER() … = 1`) — déjà en place dans `taxi_yellow_clean.sql`.

---

## 3. `RatecodeID`

**Requête** : [rate_id_check.sql](rate_id_check.sql)  
**Résultat** : [check_rate_id_result.csv](check_rate_id_result.csv)

| RatecodeID | Lignes | % (approx.) | Interprétation TLC |
| :--- | ---: | ---: | :--- |
| *(vide / NULL)* | 19 560 035 | 18,7 % | Absence de code |
| 1 (standard) | 78 929 566 | 75,3 % | Valide |
| 2 (JFK) | 3 043 075 | 2,9 % | Valide |
| 3 (Newark) | 326 025 | 0,3 % | Valide |
| 4 (Nassau/Westchester) | 249 814 | 0,2 % | Valide |
| 5 (négocié) | 893 175 | 0,9 % | Valide |
| 6 (group ride) | 139 | ~0 % | Valide |
| **99** | 1 768 363 | 1,7 % | **Null/inconnu (code officiel TLC)** |

**Écart doc initiale** : seuls **1 à 6** sont des tarifs ; **99** est documenté comme null/inconnu, pas comme erreur au sens strict.

**Recommandation** : pour l’analytique « course standard », filtrer `RatecodeID IN (1,2,3,4,5,6)` ou traiter 99 comme NULL métier ; exclure les lignes sans `RatecodeID` si le type de tarif est requis.

---

## 4. `passenger_count`

**Requête** : [passenger_count.sql](passenger_count.sql)  
**Résultat** : [passenger_count_result.csv](passenger_count_result.csv)

| Valeur | Lignes | % (approx.) | Commentaire |
| :--- | ---: | ---: | :--- |
| NULL | 19 560 035 | 18,7 % | Même volume que `RatecodeID` NULL (lignes souvent incomplètes) |
| 0 | 713 746 | 0,7 % | Taxi à vide / saisie invalide pour trajet facturé |
| 1 | 67 152 351 | 64,1 % | Majoritaire |
| 2–5 | 6 328 410 | 6,0 % | Plage réaliste taxi |
| 6 | 334 799 | 0,3 % | Van / saisie haute (seuil variable selon modèle) |
| 7–9 | 448 | ~0 % | Aberrant (capacité taxi standard) |

**Alignement TLC** : valeur saisie par le conducteur ; le dictionnaire n’impose pas de maximum, mais **0** et **NULL** ne sont pas exploitables pour des KPI « passagers transportés ».

**Recommandation** : `passenger_count BETWEEN 1 AND 5` dans `taxi_yellow_clean.sql` ; le modèle `dbt/nyc_taxi/models/staging/stg_clean_trips.sql` utilise `<= 6` — harmoniser si besoin.

---

## 5. Distances (`trip_distance`)

**Requête** : [check_distances.sql](check_distances.sql)  
**Résultat** : [check_distances_result.csv](check_distances_result.csv)

**Seuils de la requête** : `<= 0`, `> 100` miles, et trajets « gratuits longue distance » (`trip_distance > 5` et `total_amount <= 3.5`).

**Exemples marquants** :

| Fichier | Trajets | Distance ≤ 0 | Distance &gt; 100 | Max (miles) | Gratuits longue dist. |
| :--- | ---: | ---: | ---: | ---: | ---: |
| yellow_tripdata_2025-04.parquet | 3 970 553 | 91 439 (2,3 %) | 306 | 386 088,43 | 19 820 |
| yellow_tripdata_2025-05.parquet | 4 591 845 | 141 121 (3,1 %) | 370 | 263 103,98 | 44 763 |
| yellow_tripdata_2024-12.parquet | 3 668 371 | 75 450 (2,1 %) | 129 | 328 827,63 | 15 105 |

Les maxima (centaines de milliers de miles) indiquent des **défauts taximètre / TSP**, pas des trajets réels.

**Alignement TLC** : `trip_distance` = distance taximètre en miles ; valeurs négatives ou nulles sont incohérentes pour un trajet terminé facturé.

**Recommandation** : `trip_distance BETWEEN 0.1 AND 100` (pipeline actuel) ; le seuil 200 miles dans `stg_clean_trips.sql` est plus permissif — à réduire pour cohérence.

---

## 6. Montants (`total_amount`)

**Requête** : [check_total_amount.sql](check_total_amount.sql)  
**Résultat** : [check_total_amount_result.csv](check_total_amount_result.csv)

**Exemple — mois mis en évidence dans l’analyse** (`yellow_tripdata_2024-12.parquet`) :

| Indicateur | Valeur |
| :--- | ---: |
| Trajets | 3 668 371 |
| `total_amount` &lt; 0 | 70 496 (~1,9 %) |
| Pire négatif | -951,00 $ |
| `total_amount` = 0 | 606 |
| `total_amount` &gt; 500 | 78 |
| Maximum | 3 037,10 $ |

**Autres pics observés** (erreurs extrêmes ponctuelles) :

- Max global relevé : **863 380,37 $** (`yellow_tripdata_2025-01.parquet`)
- Autres fichiers : 325 528 $, 335 550 $, 46 269 $, etc.

Les négatifs peuvent correspondre à **annulations / ajustements** côté TSP ; ils restent exclus d’un dataset « revenu course ».

**Recommandation** : `total_amount BETWEEN 3.50 AND 500` et `fare_amount >= 2.50` (`taxi_yellow_clean.sql`) ; exclure explicitement `total_amount < 0` si les annulations ne sont pas modélisées.

---

## Matrice : contrôle → règle de nettoyage

| Fichier SQL | Règle métier proposée | Implémentation existante |
| :--- | :--- | :--- |
| `analyse_check_dropoff_deposit.sql` | Pickup = mois fichier ± 24 h | `taxi_yellow_clean.sql` (raccord fichier) |
| `dupe_check.sql` | Déduplication | `QUALIFY ROW_NUMBER()` |
| `rate_id_check.sql` | Codes 1–6 ; traiter 99 | À ajouter si besoin analytique tarif |
| `passenger_count.sql` | `1–5` (ou `1–6`) | `BETWEEN 1 AND 5` / `stg_clean_trips` `<= 6` |
| `check_distances.sql` | `0.1–100` miles | `taxi_yellow_clean` ; `stg_clean_trips` &lt; 200 |
| `check_total_amount.sql` | `3.50–500`, fare ≥ 2.50 | `taxi_yellow_clean.sql` |

Détail des transformations dbt : [../transformations/transfo.md](../transformations/transfo.md) et [../transformations/nyc/models/staging/taxi_yellow_clean.sql](../transformations/nyc/models/staging/taxi_yellow_clean.sql).

---

## Limites connues

1. **TLC** : pas de garantie d’exactitude ; anomalies connues dans l’écosystème open data NYC taxi.
2. **Corrélation NULL** : ~19,56 M lignes ont à la fois `RatecodeID` et `passenger_count` NULL — traiter comme **lignes incomplètes** plutôt que deux problèmes indépendants.
3. **Fichiers futurs** : présence de `2026-01` à `2026-04` dans l’ingestion ; vérifier la disponibilité officielle sur le site TLC avant production.
4. **Écarts entre modèles** : `taxi_yellow_clean.sql` (Snowflake/dbt legacy sous `sql/transformations/nyc`) et `stg_clean_trips.sql` (`dbt/nyc_taxi`) n’appliquent pas exactement les mêmes seuils — documenter le modèle cible pour Power BI / reporting.

---

## Rejouer les contrôles

Exécuter chaque `.sql` sur la table `nyc_taxi_yellow` (Snowflake), exporter en CSV dans ce dossier, puis mettre à jour les tableaux de ce document si le périmètre de fichiers change.
