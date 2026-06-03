"""Dashboard Streamlit — NYC Yellow Taxi.

Lit les données nettoyées (STAGING.CLEAN_TRIPS) dans Snowflake et affiche
les KPIs et visualisations principales. Les agrégations sont faites côté
Snowflake (rapide) et mises en cache côté Streamlit.

Lancement :
    streamlit run dashboard/app.py
"""

import os

import pandas as pd
import snowflake.connector
import streamlit as st
from dotenv import load_dotenv

load_dotenv()

st.set_page_config(page_title="NYC Taxi Dashboard", page_icon="🚕", layout="wide")

# Libellés des types de paiement (codes TLC)
PAYMENT_LABELS = {
    0: "Non renseigné",
    1: "Carte bancaire",
    2: "Espèces",
    3: "Gratuit",
    4: "Litige",
    5: "Inconnu",
    6: "Annulé",
}


@st.cache_resource
def get_connection():
    """Connexion Snowflake (mise en cache pour toute la session)."""
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        role=os.getenv("SNOWFLAKE_ROLE"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "NYC_TAXI_WH"),
        database=os.getenv("SNOWFLAKE_DATABASE", "NYC_TAXI_DB"),
        schema="STAGING",
    )


@st.cache_data(ttl=3600)
def run_query(sql: str) -> pd.DataFrame:
    """Exécute une requête et renvoie un DataFrame (résultat mis en cache 1h)."""
    cur = get_connection().cursor()
    cur.execute(sql)
    return cur.fetch_pandas_all()


# ---------------------------------------------------------------------------
st.title("🚕 NYC Yellow Taxi — Dashboard")
st.caption("Source : STAGING.CLEAN_TRIPS (données nettoyées 2024 → 2025)")

# --- KPIs principaux --------------------------------------------------------
kpis = run_query(
    """
    SELECT
        COUNT(*)               AS nb_trajets,
        SUM(total_amount)      AS revenu_total,
        AVG(total_amount)      AS ticket_moyen,
        AVG(trip_distance)     AS distance_moyenne
    FROM CLEAN_TRIPS
    """
).iloc[0]

c1, c2, c3, c4 = st.columns(4)
c1.metric("Trajets", f"{int(kpis['NB_TRAJETS']):,}".replace(",", " "))
c2.metric("Revenu total", f"{kpis['REVENU_TOTAL']/1e6:,.1f} M$")
c3.metric("Ticket moyen", f"{kpis['TICKET_MOYEN']:.2f} $")
c4.metric("Distance moyenne", f"{kpis['DISTANCE_MOYENNE']:.2f} mi")

st.divider()

# --- Volume par jour --------------------------------------------------------
col_a, col_b = st.columns(2)

with col_a:
    st.subheader("📅 Trajets par jour")
    daily = run_query(
        """
        SELECT pickup_date AS jour, COUNT(*) AS trajets
        FROM CLEAN_TRIPS
        GROUP BY 1 ORDER BY 1
        """
    )
    st.line_chart(daily, x="JOUR", y="TRAJETS", height=300)

with col_b:
    st.subheader("🕐 Trajets par heure de la journée")
    hourly = run_query(
        """
        SELECT pickup_hour AS heure, COUNT(*) AS trajets
        FROM CLEAN_TRIPS
        GROUP BY 1 ORDER BY 1
        """
    )
    st.bar_chart(hourly, x="HEURE", y="TRAJETS", height=300)

# --- Zones et paiements -----------------------------------------------------
col_c, col_d = st.columns(2)

with col_c:
    st.subheader("📍 Top 10 zones de départ")
    zones = run_query(
        """
        SELECT pickup_location_id AS zone, COUNT(*) AS trajets
        FROM CLEAN_TRIPS
        GROUP BY 1 ORDER BY 2 DESC LIMIT 10
        """
    )
    zones["ZONE"] = zones["ZONE"].astype(str)
    st.bar_chart(zones, x="ZONE", y="TRAJETS", height=300)

with col_d:
    st.subheader("💳 Répartition des paiements")
    pay = run_query(
        """
        SELECT payment_type, COUNT(*) AS trajets
        FROM CLEAN_TRIPS
        GROUP BY 1 ORDER BY 2 DESC
        """
    )
    pay["MODE"] = pay["PAYMENT_TYPE"].map(PAYMENT_LABELS).fillna("Autre")
    st.bar_chart(pay, x="MODE", y="TRAJETS", height=300)

st.divider()
st.caption("Pipeline NYC Taxi — Snowflake + DBT + Streamlit")
