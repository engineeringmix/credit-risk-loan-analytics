# ============================================================
# CREDORA FINANCE — Credit Risk & Loan Approval Analytics
# Day 8: BI Dashboard (Streamlit)
# RUN:  streamlit run app.py
# PREREQUISITE: setx MYSQL_PASSWORD "password" + restart terminal
# All 8 PRD components read from MySQL (credora_risk).
# ============================================================

import os
import pandas as pd
import numpy as np
import streamlit as st
import plotly.express as px
from sqlalchemy import create_engine, URL

# ---------- Page config ----------
st.set_page_config(
    page_title="Credora | Credit Risk Analytics",
    page_icon="🏦",
    layout="wide",
)

st.title("🏦 Credora Finance — Credit Risk & Loan Approval Analytics")
st.caption("Retail lending decision support · default prediction · "
           "portfolio risk monitoring")


# ---------- Data layer ----------
@st.cache_data(ttl=600)
def load_data():
    url = URL.create(
        drivername="mysql+mysqlconnector",
        username="root",
        password=os.environ["MYSQL_PASSWORD"],
        host="localhost",
        database="credora_risk",
    )
    engine = create_engine(url)
    data = {
        "customers": pd.read_sql("SELECT * FROM customers", engine),
        "credit": pd.read_sql("SELECT * FROM credit_history", engine),
        "loans": pd.read_sql("SELECT * FROM loan_applications", engine),
        "scored": pd.read_sql("SELECT * FROM scored_customers", engine),
    }
    return data


try:
    data = load_data()
except Exception as e:
    st.error(f"Database connection failed: {e}")
    st.stop()

customers, credit, loans, scored = (
    data["customers"], data["credit"], data["loans"], data["scored"])

disbursed = loans[loans["disbursed_flag"] == 1]
decided = loans[loans["approval_status"].isin(["Approved", "Rejected"])]

# ---------- Sidebar filters ----------
st.sidebar.header("Filters")
loan_types = st.sidebar.multiselect(
    "Loan type", sorted(loans["loan_type"].unique()),
    default=sorted(loans["loan_type"].unique()))
states = st.sidebar.multiselect(
    "State", sorted(customers["state"].unique()),
    default=sorted(customers["state"].unique()))
risk_cats = st.sidebar.multiselect(
    "Risk category", ["Low", "Medium", "High"],
    default=["Low", "Medium", "High"])

loans_f = loans[loans["loan_type"].isin(loan_types)]
disbursed_f = disbursed[disbursed["loan_type"].isin(loan_types)]
scored_f = scored[scored["risk_category"].isin(risk_cats)]

# ---------- 1. KPI cards (PRD components 1 & 2) ----------
c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("Applications", f"{len(loans_f):,}")
c2.metric("Approval rate",
          f"{(decided['approval_status'] == 'Approved').mean() * 100:.1f}%")
c3.metric("Disbursed loans", f"{len(disbursed_f):,}")
c4.metric("Default rate",
          f"{disbursed_f['loan_default'].mean() * 100:.1f}%")
c5.metric("Disbursed value",
          f"₹{disbursed_f['approved_amount'].sum() / 1e7:,.0f} Cr")

st.divider()

# ---------- 2. Trends row (components 1, 6, 7) ----------
loans_f = loans_f.copy()
loans_f["app_month"] = pd.to_datetime(
    loans_f["application_date"]).dt.to_period("M").astype(str)
monthly = loans_f.groupby("app_month").agg(
    applications=("application_id", "count"),
    approved=("approval_status", lambda s: (s == "Approved").sum()),
    rejected=("approval_status", lambda s: (s == "Rejected").sum()),
).reset_index()
monthly["approval_rate"] = monthly["approved"] / monthly["applications"] * 100

left, right = st.columns(2)
with left:
    st.subheader("Monthly application volume & approval rate")
    fig = px.bar(monthly, x="app_month", y="applications",
                 labels={"applications": "Applications", "app_month": "Month"})
    st.plotly_chart(fig, use_container_width=True)
with right:
    st.subheader("Approval vs rejection trend")
    fig = px.area(monthly, x="app_month", y=["approved", "rejected"],
                  labels={"value": "Applications", "app_month": "Month",
                          "variable": "Decision"})
    st.plotly_chart(fig, use_container_width=True)

# ---------- 3. Risk row (components 2, 3, 4) ----------
left, mid, right = st.columns(3)

with left:
    st.subheader("Default rate by loan type")
    dr = (disbursed_f.groupby("loan_type")["loan_default"]
          .mean().mul(100).sort_values(ascending=False).reset_index())
    st.plotly_chart(px.bar(dr, x="loan_type", y="loan_default",
                           labels={"loan_default": "Default rate %",
                                   "loan_type": "Loan type"}),
                    use_container_width=True)

with mid:
    st.subheader("Customer risk distribution")
    risk_counts = scored_f["risk_category"].value_counts().reset_index()
    risk_counts.columns = ["risk_category", "count"]
    st.plotly_chart(
        px.pie(risk_counts, names="risk_category", values="count",
               hole=0.55, color="risk_category",
               color_discrete_map={"Low": "#2e7d32",
                                   "Medium": "#ef6c00",
                                   "High": "#c62828"}),
        use_container_width=True)

with right:
    st.subheader("Credit score distribution")
    st.plotly_chart(
        px.histogram(credit, x="credit_score", nbins=40,
                     labels={"credit_score": "Credit score"}),
        use_container_width=True)

st.divider()

# ---------- 4. Geography (component 5) ----------
st.subheader("Geographic distribution of applications")
geo = (loans_f.merge(customers[["customer_id", "state"]],
                     on="customer_id")
       .groupby("state").agg(
           applications=("application_id", "count"),
           approved_amt=("approved_amount", "sum")).reset_index()
       .sort_values("applications", ascending=False))
st.plotly_chart(px.bar(geo, x="state", y="applications",
                       hover_data=["approved_amt"],
                       labels={"applications": "Applications"}),
                use_container_width=True)

st.divider()

# ---------- 5. High-risk watchlist (component 8) ----------
st.subheader("🚨 High-risk customer watchlist")
watch = (scored_f.merge(customers[["customer_id", "first_name",
                                   "last_name", "city", "state"]],
                        on="customer_id")
         .merge(credit[["customer_id", "credit_score"]],
                on="customer_id")
         .sort_values("risk_score", ascending=False))
watch = watch[["customer_id", "first_name", "last_name", "city", "state",
               "credit_score", "default_probability", "risk_score",
               "risk_category"]]
st.dataframe(
    watch.style.format({"default_probability": "{:.1%}"}),
    use_container_width=True, height=400,
)
st.caption(f"{len(watch):,} records · filtered by sidebar · "
           "sorted by risk score")

st.divider()
st.caption("Credora Finance · Credit Risk Analytics Platform · "
           "Model: champion classifier from Week 3 · "
           "Scores: P(default) × 100, bands 0–33 / 34–66 / 67–100")