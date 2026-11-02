# Model card — Credora default prediction

## Purpose
Estimate P(default) for disbursed retail loans; convert to a 0-100 risk
score and Low/Medium/High category for underwriter decision support.
Advisory only — humans make the final call (PRD non-goal: auto-decisions).

## Training data
- Population: disbursed loans only (target observed): 3,403 rows
- Features: bureau (score, utilization, late payments, prior defaults),
  application (amount, DTI, rate, term, type, collateral),
  demographics (age, employment, residence),
  transaction aggregates (inflow/outflow, EMI, avg balance, ratios)
- Excluded (leakage): approval_status, approved_amount, decision_date,
  disbursed_flag, IDs. Excluded (privacy): email, phone.

## Preprocessing
Median imputation (numeric), 'Unknown' + one-hot (categorical),
stratified 80/20 split (seed 42), 5-fold stratified CV on train only.

## Champion
**Logistic Regression** — ROC-AUC 0.703, Recall 0.623, Precision 0.372,
F1 0.466 on held-out test at the default 0.5 threshold. Decision
threshold tuned to **0.20** for deployment (recall 0.9245, precision
0.269, F1 0.417).

Selection rule: highest ROC-AUC among models clearing recall >= 0.70.
**No model cleared that bar** — Logistic Regression, Random Forest,
XGBoost, and Decision Tree all fell short at the default threshold.
Champion was chosen by fallback to best-ROC-AUC-overall. This is
disclosed here deliberately: the model is below the PRD's ROC-AUC
>= 0.80 target, and that gap should be stated plainly, not implied
away by only reporting the post-threshold-tuning recall number.

## Explainability
SHAP ranking (feature_importance.csv). Top 5 drivers:
1. debt_to_income_ratio
2. credit_score
3. applicant_monthly_income
4. annual_income
5. avg_balance

These match domain expectations and were cross-checked against SQL
query 10 in sql/credit_risk_platform.sql (default rate rises with DTI,
falls with credit score) — consistent direction, which is a genuine
validation signal, not just a modeling artefact.

## Limitations
- ROC-AUC 0.70 is below the PRD's 0.80 target — this is the single
  most important limitation to lead with, not bury
- Threshold 0.20 produces ~73% false-positive rate among flagged loans
  — acceptable for an advisory tool with human review, not for any
  automated decisioning
- Trained on synthetic/simulated book; not production-validated
- No fair-lending bias review (PRD future enhancement)
- Scores Under Review applications only as advisory estimates
- No drift monitoring / retraining pipeline (future work)

## Risk bands
0-33 Low, 34-66 Medium, 67-100 High (PRD 13.7). These bands are a
fixed rule on default_probability x 100, independent of the 0.20
classification threshold used for the binary predicted_default flag —
the two shouldn't be confused when explaining this model.
