"""Customer Churn Analysis dashboard.   Run:  python -m streamlit run app.py"""
import json
from pathlib import Path

import pandas as pd
import streamlit as st

from src.analysis import age_group, churn_rate_by, churn_reasons, kpis, monthly_churn, monthly_payments
from src.database import load_tables
from src.features import build_features

ROOT = Path(__file__).resolve().parent

st.set_page_config(page_title="Customer Churn Analysis", page_icon="📊", layout="wide")


@st.cache_data(ttl=600, show_spinner="Loading data...")
def get_data():
    tables, source = load_tables()
    return tables, source, build_features(tables)


@st.cache_data(show_spinner=False)
def get_risk_scores():
    path = ROOT / "data" / "churn_risk_scores.csv"
    return pd.read_csv(path) if path.exists() else None


@st.cache_data(show_spinner=False)
def get_metrics():
    path = ROOT / "models" / "metrics.json"
    return json.loads(path.read_text()) if path.exists() else None


try:
    tables, source, features = get_data()
except Exception as exc:
    st.error(f"Could not load data: {exc}")
    st.stop()

st.title("📊 Customer Churn Analysis")
st.caption(f"Data source: {source}")

# ---------------- sidebar filters ----------------
st.sidebar.header("Filters")
cities = st.sidebar.multiselect("City", sorted(features.city.dropna().unique()))
plans = st.sidebar.multiselect("Plan", sorted(features.plan_name.dropna().unique()))
view = features
if cities:
    view = view[view.city.isin(cities)]
if plans:
    view = view[view.plan_name.isin(plans)]
if view.empty:
    st.warning("No customers match the selected filters.")
    st.stop()

ids = set(view.customer_id)
churn_records = tables["churn_records"]
churn_view = churn_records[churn_records.customer_id.isin(ids)]
payments = tables["payments"].merge(
    tables["subscriptions"][["subscription_id", "customer_id"]], on="subscription_id")
payments = payments[payments.customer_id.isin(ids)]
tickets = tables["support_tickets"]
tickets = tickets[tickets.customer_id.isin(ids)]

# ---------------- KPIs ----------------
k = kpis(view, churn_view)
c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("Subscribed customers", f"{k['customers']:,}")
c2.metric("Churned", f"{k['churned']:,}")
c3.metric("Churn rate", f"{k['churn_rate_pct']}%")
c4.metric("At-risk customers", f"{k['at_risk']:,}")
c5.metric("Monthly revenue lost", f"₹{k['lost_monthly_revenue']:,.0f}")

tab_over, tab_seg, tab_pay, tab_risk, tab_data = st.tabs(
    ["Overview", "Segments", "Payments & support", "Risk watchlist", "Raw data"])

with tab_over:
    left, right = st.columns(2)
    with left:
        st.subheader("Churn by plan")
        st.bar_chart(churn_rate_by(view, "plan_name").set_index("plan_name")["churn_rate_pct"])
    with right:
        st.subheader("Churn reasons")
        reasons = churn_reasons(churn_view)
        if reasons.empty:
            st.info("No churned customers in this selection.")
        else:
            st.bar_chart(reasons)
    st.subheader("Churn events per month")
    trend = monthly_churn(churn_view)
    if trend.empty:
        st.info("No dated churn events in this selection.")
    else:
        st.line_chart(trend)

with tab_seg:
    left, right = st.columns(2)
    with left:
        st.subheader("Churn rate by city")
        st.bar_chart(churn_rate_by(view, "city").set_index("city")["churn_rate_pct"])
    with right:
        st.subheader("Churn rate by age group")
        seg = view.assign(age_group=age_group(view.age))
        st.bar_chart(churn_rate_by(seg, "age_group").sort_values("age_group").set_index("age_group")["churn_rate_pct"])
    st.caption("Small segments swing a lot. Check the customer counts before drawing conclusions.")
    st.dataframe(churn_rate_by(view, "city"), width="stretch", hide_index=True)

with tab_pay:
    left, right = st.columns(2)
    with left:
        st.subheader("Payments per month by status")
        st.bar_chart(monthly_payments(payments))
    with right:
        st.subheader("Average per customer: churned vs retained")
        cmp = (view.assign(segment=view.churned.map({1: "Churned", 0: "Retained"}))
                   .groupby("segment")[["total_tickets", "unresolved_tickets", "failed_payment_rate"]].mean().round(2))
        st.dataframe(cmp, width="stretch")
        st.subheader("Tickets by category")
        if tickets.empty:
            st.info("No tickets in this selection.")
        else:
            st.bar_chart(tickets.issue_category.value_counts())

with tab_risk:
    st.subheader("Highest churn risk (customers who have not churned)")
    scores = get_risk_scores()
    if scores is None:
        st.info("No scores yet. Run `python src/train_model.py` to create them.")
    else:
        scores = scores[scores.customer_id.isin(ids)]
        band = st.multiselect("Risk band", ["High", "Medium", "Low"], default=["High"])
        st.dataframe(scores[scores.risk_band.isin(band)], width="stretch", hide_index=True)
        st.caption("Scores come from a model trained with balanced class weights, so read them as a "
                   "relative ranking, not as exact probabilities.")
    m = get_metrics()
    if m:
        best = m["results"][m["best_model"]]
        st.markdown(f"**Model:** {m['best_model'].replace('_', ' ')} | cross-validated ROC-AUC "
                    f"{best['cv_roc_auc_mean']} | test ROC-AUC {best['test_roc_auc']}")
        st.caption(m["note"])

with tab_data:
    for name in ["customers", "subscriptions", "payments", "support_tickets", "churn_records"]:
        with st.expander(f"{name} ({len(tables[name]):,} rows)"):
            st.dataframe(tables[name], width="stretch", hide_index=True)
