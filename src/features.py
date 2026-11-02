"""
Feature engineering logic extracted from notebooks/02_feature_engineering.ipynb
so it can be reused by src/train.py without copy-pasting notebook cells.
The notebook remains the place to explore; this module is the place
that gets imported.
"""

import numpy as np
import pandas as pd

LEAKAGE_COLS = [
    "approval_status", "approved_amount", "decision_date",
    "disbursed_flag", "customer_id", "credit_id",
    "first_name", "last_name", "date_of_birth",
    "customer_since", "as_of_date", "application_date",
]


def aggregate_transactions(transactions: pd.DataFrame) -> pd.DataFrame:
    """Roll transaction-grain data up to one row per customer."""
    credit_amt = (transactions.loc[transactions["transaction_type"] == "Credit"]
                  .groupby("customer_id")["amount"].sum())
    debit_amt = (transactions.loc[transactions["transaction_type"] == "Debit"]
                 .groupby("customer_id")["amount"].sum())
    emi_amt = (transactions.loc[transactions["category"] == "EMI"]
               .groupby("customer_id")["amount"].sum())

    txn_agg = pd.DataFrame({
        "txn_count": transactions.groupby("customer_id").size(),
        "total_inflow": credit_amt,
        "total_outflow": debit_amt,
        "emi_outflow": emi_amt,
        "avg_balance": transactions.groupby("customer_id")["balance_after"].mean(),
    }).fillna(0).reset_index()

    txn_agg["net_cashflow"] = txn_agg["total_inflow"] - txn_agg["total_outflow"]
    txn_agg["inflow_outflow_ratio"] = (
        txn_agg["total_inflow"] / txn_agg["total_outflow"].replace(0, np.nan))
    return txn_agg


def build_modeling_table(loans, credit_history, customers, txn_agg) -> pd.DataFrame:
    """Join all sources, filter to disbursed loans, keep application_id
    as the index (not a feature) so downstream scoring can key back
    to the right customer without relying on row order."""
    model_df = (loans
                .merge(credit_history, on="customer_id", how="left")
                .merge(customers.drop(columns=["email", "phone"]),
                       on="customer_id", how="left")
                .merge(txn_agg, on="customer_id", how="left"))

    model_df = model_df[model_df["disbursed_flag"] == 1].copy()
    model_df["loan_to_income"] = (
        model_df["requested_amount"] / model_df["annual_income"].replace(0, np.nan))

    model_df = model_df.set_index("application_id")
    model_df = model_df.drop(columns=[c for c in LEAKAGE_COLS if c in model_df.columns])
    return model_df


def encode_and_impute(model_df: pd.DataFrame):
    """Split target/features, impute, one-hot encode. Returns X, y
    with application_id preserved as X's index."""
    y = model_df["loan_default"].astype(int)
    X = model_df.drop(columns=["loan_default"])

    cat_cols = X.select_dtypes(include="object").columns.tolist()
    num_cols = X.select_dtypes(include=[np.number]).columns.tolist()

    X[num_cols] = X[num_cols].fillna(X[num_cols].median())
    X[cat_cols] = X[cat_cols].fillna("Unknown")
    X = pd.get_dummies(X, columns=cat_cols, drop_first=True)
    return X, y
