# Data dictionary — Credora Finance credit risk platform

Generated from the schema in `sql/credit_risk_platform.sql`. If you
alter the schema, update this file in the same commit — a stale data
dictionary is worse than none.

## customers (5,000 rows)
| Column | Type | Notes |
|---|---|---|
| customer_id | VARCHAR(12) PK | |
| first_name, last_name | VARCHAR | PII — excluded from modeling |
| gender | VARCHAR(10) | |
| date_of_birth | DATE | PII — excluded from modeling |
| age | SMALLINT | |
| marital_status | VARCHAR(15) | |
| dependents | SMALLINT | default 0 |
| education | VARCHAR(30) | |
| employment_type | VARCHAR(20) | |
| occupation | VARCHAR(60) | |
| annual_income | DECIMAL(12,2) | |
| city, state | VARCHAR(50) | |
| residence_type | VARCHAR(20) | |
| years_at_residence | SMALLINT | |
| email, phone | VARCHAR | PII — excluded from modeling and dashboard per PRD |
| kyc_status | VARCHAR(15) | default 'Pending' |
| customer_since | DATE | |

## credit_history (5,000 rows — one per customer)
| Column | Type | Notes |
|---|---|---|
| credit_id | VARCHAR(12) PK | |
| customer_id | VARCHAR(12) FK, UNIQUE | one-to-one with customers |
| as_of_date | DATE | |
| credit_score | SMALLINT | bureau score, ~300-900 range |
| num_open_accounts | SMALLINT | |
| num_credit_inquiries_6m | SMALLINT | |
| credit_utilization_ratio | DECIMAL(4,3) | 0-1 scale |
| num_late_payments_30d / 90d | SMALLINT | default 0 |
| num_defaults_prior | SMALLINT | default 0 |
| bankruptcies | SMALLINT | default 0 |
| total_credit_limit, total_outstanding_debt | DECIMAL(12,2) | |
| oldest_account_age_months | SMALLINT | |

## loan_applications (7,500 rows)
| Column | Type | Notes |
|---|---|---|
| application_id | VARCHAR(12) PK | primary modeling key — kept as DataFrame index throughout the pipeline |
| customer_id | VARCHAR(12) FK | |
| application_date | DATE | |
| loan_type | VARCHAR(20) | |
| loan_purpose | VARCHAR(50) | |
| requested_amount | DECIMAL(12,2) | |
| loan_term_months | SMALLINT | |
| interest_rate | DECIMAL(5,2) | |
| applicant_monthly_income | DECIMAL(12,2) | |
| existing_emi | DECIMAL(12,2) | default 0 |
| debt_to_income_ratio | DECIMAL(5,3) | |
| collateral_flag | TINYINT | 0/1 |
| approval_status | VARCHAR(15) | Approved / Rejected / Under Review — **leakage: exclude from model features** |
| approved_amount | DECIMAL(12,2) | **leakage: exclude** |
| decision_date | DATE | NULL for Under Review (~173 rows) — **leakage: exclude** |
| disbursed_flag | TINYINT | **leakage: exclude** — this IS the filter that defines the modeling population |
| loan_default | TINYINT | NULL for non-disbursed (~4,097 rows); this is the target variable |

**Ground-truth checkpoints** (verify these after every reload — see
sql/credit_risk_platform.sql validation section):
- 3,403 disbursed loans
- ~23.4% observed default rate among disbursed loans
- ~46.4% approval rate among decided (Approved+Rejected) applications

## transactions (40,079 rows, last 6 months)
| Column | Type | Notes |
|---|---|---|
| transaction_id | VARCHAR(14) PK | |
| customer_id | VARCHAR(12) FK | |
| transaction_date | DATE | |
| transaction_type | VARCHAR(10) | Credit / Debit |
| category | VARCHAR(30) | e.g. EMI, groceries, etc. |
| channel | VARCHAR(20) | |
| amount | DECIMAL(12,2) | |
| balance_after | DECIMAL(12,2) | |

Aggregated to customer grain in `src/features.py::aggregate_transactions`
(txn_count, total_inflow, total_outflow, emi_outflow, avg_balance,
net_cashflow, inflow_outflow_ratio) before joining into the modeling table.

## scored_customers (created by 04_risk_scoring.ipynb — not part of the original load)
| Column | Type | Notes |
|---|---|---|
| application_id | VARCHAR(12) | key used to merge back — NOT row position |
| customer_id | VARCHAR(12) | |
| default_probability | FLOAT | model output, 0-1 |
| risk_score | INT | 0-100, rounded from default_probability |
| risk_category | VARCHAR | Low (0-33) / Medium (34-66) / High (67-100) |

**This table does not exist until 04_risk_scoring.ipynb runs
successfully** — app.py and the Tableau views that depend on it will
fail until then, by design.
