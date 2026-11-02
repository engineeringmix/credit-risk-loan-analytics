# Credora Finance — Credit Risk & Loan Approval Analytics Platform

End-to-end credit risk analytics on a retail lending book: governed MySQL
database, default-prediction model (ROC-AUC 0.70), 0-100 risk scoring,
and a Streamlit BI dashboard.

## Status
Modeling and risk-scoring notebooks have been run end-to-end. Results
below are real, not placeholders.

## Portfolio
- 5,000 customers, 5,000 bureau records, 7,500 loan applications
- 40,079 transactions (last 6 months)
- 3,403 disbursed loans, 46.4% approval rate, 23.4% observed default rate

## Architecture
```
CSV (datasets/)
  -> MySQL, PK/FK enforced (sql/credit_risk_platform.sql)
  -> Feature engineering, customer-grain transaction aggregates (notebooks/02, src/features.py)
  -> Classification: LR / DT / RF / XGBoost (notebooks/03, src/train.py)
  -> 0-100 risk score (notebooks/04, src/risk_score.py)
  -> scored_customers table in MySQL
  -> Streamlit dashboard (dashboard/app.py)
```

## Results

| Model | ROC-AUC | Recall @0.5 | Precision @0.5 | F1 @0.5 | Passes recall>=0.70? |
|---|---|---|---|---|---|
| **Logistic Regression (champion)** | **0.703** | 0.623 | 0.372 | 0.466 | No |
| Random Forest | 0.681 | 0.497 | 0.369 | 0.424 | No |
| XGBoost | 0.667 | 0.384 | 0.391 | 0.387 | No |
| Decision Tree | 0.647 | 0.616 | 0.350 | 0.447 | No |

**None of the four candidate models cleared the PRD's recall >= 0.70
target at the default 0.5 threshold.** Champion selection fell back to
best-ROC-AUC-overall (Logistic Regression) — this is a genuine gap
against the PRD's stated ROC-AUC >= 0.80 target, not a rounding
difference. State this plainly if asked; don't imply the model hit
target.

**Decision threshold: 0.20** (lowest threshold in the sweep where
recall >= 0.70). At this threshold: recall 0.9245, precision 0.269,
F1 0.417. In plain terms: about 73% of loans flagged as "predicted
default" are false alarms. This is a deliberate trade-off — catching
defaulters matters more than avoiding false positives for an
advisory tool a human reviews, not an auto-decision system — but be
ready to explain it, not just report the number.

**Top default drivers (SHAP, from feature_importance.csv):**
1. debt_to_income_ratio (0.508)
2. credit_score (0.310)
3. applicant_monthly_income (0.249)
4. annual_income (0.248)
5. avg_balance (0.203)

These match domain expectations and cross-check against SQL query 10's
finding that default rate rises with DTI and falls with credit score —
that consistency is worth calling out as a validation step, not
just a modeling artefact.

## Reproduce
1. `mysql -u root -p < sql/credit_risk_platform.sql`
   (edit the `LOAD DATA INFILE` paths to point at your MySQL secure
   upload directory, or copy datasets/ CSVs there first)
2. `pip install -r requirements.txt`
3. Set `MYSQL_PASSWORD`:
   - Windows: `setx MYSQL_PASSWORD "yourpassword"`, then restart your terminal/IDE
   - Mac/Linux: `export MYSQL_PASSWORD=yourpassword`
4. Run notebooks in order, top to bottom, no skipping cells:
   `notebooks/01_eda.ipynb` -> `02_feature_engineering.ipynb` ->
   `03_modeling.ipynb` -> `04_risk_scoring.ipynb`
5. Confirm `scored_customers` exists in MySQL:
   `SELECT COUNT(*) FROM scored_customers;` (expect 3,403)
6. From a terminal (not inside a notebook):
   `cd dashboard && streamlit run app.py`

## Privacy
email/phone excluded from modeling and dashboards (PRD non-functional
requirement). No PII in commits.

## Known limitations (be upfront about these, don't discover them live in an interview)
- ROC-AUC 0.70, below the PRD's 0.80 target — none of the 4 candidate
  models cleared it; this is the most important number to be honest
  about in an interview
- Decision threshold (0.20) trades heavy false positives for high
  recall — 73% of flagged loans are false alarms at this setting
- Trained on a synthetic/simulated book, not production-validated
- No fair-lending bias review
- No drift monitoring or retraining pipeline
- Risk bands (0-33/34-66/67-100) are a fixed rule, not tuned against
  a specific business cost function
