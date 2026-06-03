-- Table analytique (couche FINAL) : résumé journalier des trajets.
-- Se branche sur le modèle de staging via ref() -> DBT gère l'ordre d'exécution.

select
    pickup_date,
    count(*)                          as nb_trajets,
    round(sum(total_amount), 2)       as revenu_total,
    round(avg(total_amount), 2)       as ticket_moyen,
    round(avg(trip_distance), 2)      as distance_moyenne_miles,
    round(avg(trip_duration_min), 2)  as duree_moyenne_min,
    round(avg(tip_amount), 2)         as pourboire_moyen

from {{ ref('stg_yellow_taxi') }}

group by pickup_date
order by pickup_date
