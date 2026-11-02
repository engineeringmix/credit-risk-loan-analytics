"""
Risk scoring logic extracted from notebooks/04_risk_scoring.ipynb.
Converts a trained model's P(default) into the 0-100 score and
Low/Medium/High band, and writes scored_customers back to MySQL
keyed on application_id (not row position — see the note in
04_risk_scoring.ipynb Cell 9 for why that distinction matters).
"""

import numpy as np
import pandas as pd


def score_customers(champion, X, scaler=None, champion_mode="raw") -> pd.DataFrame:
    """Score every row in X. X.index must be application_id."""
    X_for_predict = scaler.transform(X) if champion_mode == "scaled" else X
    proba = champion.predict_proba(X_for_predict)[:, 1]

    scored = pd.DataFrame({
        "application_id": X.index,
        "default_probability": proba,
        "risk_score": np.round(proba * 100).astype(int),
    })
    scored["risk_category"] = pd.cut(
        scored["risk_score"], bins=[-1, 33, 66, 100],
        labels=["Low", "Medium", "High"])
    return scored


def write_scored_customers(scored: pd.DataFrame, loans: pd.DataFrame, engine):
    """Merge scored rows onto customer_id via application_id (a real
    key, not row position) and write scored_customers to MySQL."""
    disbursed_keys = loans.loc[loans["disbursed_flag"] == 1,
                               ["application_id", "customer_id"]]

    scored_out = disbursed_keys.merge(
        scored, on="application_id", how="inner", validate="one_to_one")

    if len(scored_out) != len(scored):
        raise ValueError(
            f"Merge produced {len(scored_out)} rows but scored had "
            f"{len(scored)} — some application_ids didn't match. "
            "Check that X.index in the modeling notebook is really "
            "application_id before trusting this output."
        )

    scored_out.to_sql("scored_customers", engine, if_exists="replace", index=False)
    return scored_out
