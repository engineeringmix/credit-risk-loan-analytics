"""
Model training + champion selection logic extracted from
notebooks/03_modeling.ipynb. Keeping this as an importable module
means train.py can be called from a CI script or a Makefile later,
not just from inside a notebook.
"""

import time
import numpy as np
import pandas as pd
from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.metrics import (accuracy_score, precision_score, recall_score,
                              f1_score, roc_auc_score)

RANDOM_STATE = 42
RECALL_TARGET = 0.70  # from PRD — non-negotiable unless you change the PRD


def evaluate_all(models_dict, X_train, X_train_s, y_train, X_test, X_test_s, y_test):
    """Train + cross-validate every candidate model, return a results
    DataFrame and the fitted models."""
    rows, fitted = [], {}
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)

    for name, (model, mode) in models_dict.items():
        Xtr = X_train_s if mode == "scaled" else X_train
        Xte = X_test_s if mode == "scaled" else X_test

        t0 = time.time()
        cv_auc = cross_val_score(model, Xtr, y_train, cv=cv,
                                  scoring="roc_auc", n_jobs=-1)
        model.fit(Xtr, y_train)
        train_sec = time.time() - t0

        pred = model.predict(Xte)
        proba = model.predict_proba(Xte)[:, 1]
        rows.append({
            "Model": name,
            "CV_ROC_AUC": cv_auc.mean(),
            "Accuracy": accuracy_score(y_test, pred),
            "Precision": precision_score(y_test, pred),
            "Recall": recall_score(y_test, pred),
            "F1": f1_score(y_test, pred),
            "ROC_AUC": roc_auc_score(y_test, proba),
            "Train_sec": round(train_sec, 1),
        })
        fitted[name] = (model, mode)

    return pd.DataFrame(rows), fitted


def select_champion(results: pd.DataFrame, fitted: dict):
    """Champion = highest ROC-AUC among models meeting the PRD's
    recall >= 0.70 target. Falls back to best-overall ROC-AUC (with
    a warning) only if nothing clears the bar — that fallback should
    be treated as a signal to revisit feature engineering or
    threshold tuning, not accepted quietly.
    """
    results = results.copy()
    results["passes_recall"] = results["Recall"] >= RECALL_TARGET
    eligible = results[results["passes_recall"]]

    if len(eligible) > 0:
        champion_row = eligible.sort_values("ROC_AUC", ascending=False).iloc[0]
    else:
        champion_row = results.sort_values("ROC_AUC", ascending=False).iloc[0]
        print(f"WARNING: no model met recall >= {RECALL_TARGET}. "
              "Falling back to best ROC-AUC overall — this is below "
              "your PRD target and should be investigated, not shipped.")

    champion_name = champion_row["Model"]
    champion, champion_mode = fitted[champion_name]
    return champion_name, champion, champion_mode, champion_row
