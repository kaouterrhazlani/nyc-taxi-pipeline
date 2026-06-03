## installer dbt
pip install dbt-snowflake
cd /sql/transformations/dbt init nyv

suivre l'installer

lancer les modeles : 
dbt run
lancer un fichier particulier: 
dbt run --select fichier.sql


## transfo effectuées
| Dimension | Règle Métier | Seuil / Filtre SQL | Justification Technique / Métier |
| :--- | :--- | :--- | :--- |
| **Doublons** | Zéro doublon parfait | `QUALIFY ROW_NUMBER() OVER(...) = 1` | Éliminer les doublons parfaits dus à des bugs d'injection. |
| **Temporel** | Cohérence chronologique | `dropoff_datetime > pickup_datetime` | Logique de base : l'arrivée doit être après le départ. |
| **Raccord Fichier** | Cohérence avec le mois du fichier | `pickup_datetime` doit correspondre au mois du `source_file` (ou max 24h avant). | Élimine les erreurs massives de dates (ex: année 2008 ou 2045 dans un fichier de 2024) tout en acceptant les débordements légitimes de fin de mois. |
| **Tarification** | Prix réalistes | `total_amount BETWEEN 3.50 AND 500.00`<br>`AND fare_amount >= 2.50` | Élimine les montants négatifs, les zéros et les aberrations à 300 000 $. |
| **Volumétrie physique** | Distance réaliste | `trip_distance BETWEEN 0.1 AND 100.00` | Élimine les compteurs GPS défectueux (ex: 390 000 miles). |
| **Capacité** | Volume de passagers | `passenger_count BETWEEN 1 AND 9` | Exclut les taxis à vide (0). Le seuil à 9 inclut les Vans et Limousines. |