USE credora_risk;

-- Drop and recreate if you already ran the broken version once
-- (uncomment if you need a clean slate)
-- DROP TABLE IF EXISTS transactions;
-- DROP TABLE IF EXISTS loan_applications;
-- DROP TABLE IF EXISTS credit_history;
-- DROP TABLE IF EXISTS customers;

CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(12) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    gender VARCHAR(10),
    date_of_birth DATE NOT NULL,
    age SMALLINT,
    marital_status VARCHAR(15),
    dependents SMALLINT DEFAULT 0,
    education VARCHAR(30),
    employment_type VARCHAR(20),
    occupation VARCHAR(60),
    annual_income DECIMAL(12,2),
    city VARCHAR(50),
    state VARCHAR(50),
    residence_type VARCHAR(20),
    years_at_residence SMALLINT,
    email VARCHAR(120),
    phone VARCHAR(20),
    kyc_status VARCHAR(15) DEFAULT 'Pending',
    customer_since DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS credit_history (
    credit_id VARCHAR(12) PRIMARY KEY,
    customer_id VARCHAR(12) NOT NULL UNIQUE,
    as_of_date DATE NOT NULL,
    credit_score SMALLINT,
    num_open_accounts SMALLINT,
    num_credit_inquiries_6m SMALLINT,
    credit_utilization_ratio DECIMAL(4,3),
    num_late_payments_30d SMALLINT DEFAULT 0,
    num_late_payments_90d SMALLINT DEFAULT 0,
    num_defaults_prior SMALLINT DEFAULT 0,
    bankruptcies SMALLINT DEFAULT 0,
    total_credit_limit DECIMAL(12,2),
    total_outstanding_debt DECIMAL(12,2),
    oldest_account_age_months SMALLINT,
    CONSTRAINT fk_credit_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS loan_applications (
    application_id VARCHAR(12) PRIMARY KEY,
    customer_id VARCHAR(12) NOT NULL,
    application_date DATE NOT NULL,
    loan_type VARCHAR(20) NOT NULL,
    loan_purpose VARCHAR(50),
    requested_amount DECIMAL(12,2),
    loan_term_months SMALLINT,
    interest_rate DECIMAL(5,2),
    applicant_monthly_income DECIMAL(12,2),
    existing_emi DECIMAL(12,2) DEFAULT 0,
    debt_to_income_ratio DECIMAL(5,3),
    collateral_flag TINYINT DEFAULT 0,
    approval_status VARCHAR(15) NOT NULL,
    approved_amount DECIMAL(12,2) DEFAULT 0,
    decision_date DATE NULL,
    disbursed_flag TINYINT DEFAULT 0,
    loan_default TINYINT NULL,
    CONSTRAINT fk_loan_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id VARCHAR(14) PRIMARY KEY,
    customer_id VARCHAR(12) NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_type VARCHAR(10),
    category VARCHAR(30),
    channel VARCHAR(20),
    amount DECIMAL(12,2),
    balance_after DECIMAL(12,2),
    CONSTRAINT fk_txn_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
);

SHOW GLOBAL VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;

-- ============================================================
-- CUSTOMERS
-- Dates in the real file are ISO format (YYYY-MM-DD) and lines
-- end in plain \n, NOT \r\n. Fixed both below.
-- ============================================================
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    customer_id,
    first_name,
    last_name,
    gender,
    @date_of_birth,
    age,
    marital_status,
    dependents,
    education,
    employment_type,
    occupation,
    annual_income,
    city,
    state,
    residence_type,
    years_at_residence,
    email,
    phone,
    kyc_status,
    @customer_since
)
SET
    date_of_birth = STR_TO_DATE(@date_of_birth, '%Y-%m-%d'),
    customer_since = STR_TO_DATE(@customer_since, '%Y-%m-%d');

-- ============================================================
-- CREDIT_HISTORY
-- ============================================================
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/credit_history.csv'
INTO TABLE credit_history
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    credit_id, customer_id, @as_of_date, credit_score, num_open_accounts,
    num_credit_inquiries_6m, credit_utilization_ratio, num_late_payments_30d,
    num_late_payments_90d, num_defaults_prior, bankruptcies,
    total_credit_limit, total_outstanding_debt, oldest_account_age_months
)
SET
    as_of_date = STR_TO_DATE(@as_of_date, '%Y-%m-%d');

-- ============================================================
-- LOAN_APPLICATIONS
-- This file is a perfectly normal CSV. There is nothing to
-- "convert." decision_date is blank for Under Review / pending
-- rows and loan_default is blank for non-disbursed loans - both
-- handled by the NULLIF logic already in this script.
-- ============================================================
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/loan_applications.csv'
INTO TABLE loan_applications
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    application_id, customer_id, @application_date, loan_type, loan_purpose,
    requested_amount, loan_term_months, interest_rate, applicant_monthly_income,
    existing_emi, debt_to_income_ratio, collateral_flag, approval_status,
    approved_amount, @decision_date, disbursed_flag, @loan_default
)
SET
    application_date = STR_TO_DATE(@application_date, '%Y-%m-%d'),
    decision_date = NULLIF(TRIM(@decision_date), ''),
    loan_default = NULLIF(TRIM(@loan_default), '');

-- ============================================================
-- TRANSACTIONS
-- ============================================================
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    transaction_id, customer_id, @transaction_date, transaction_type,
    category, channel, amount, balance_after
)
SET
    transaction_date = STR_TO_DATE(@transaction_date, '%Y-%m-%d');

-- ============================================================
-- VALIDATION - run these and actually look at the output,
-- don't just check row counts.
-- ============================================================
SELECT COUNT(*) AS customer_rows FROM customers;
SELECT COUNT(*) AS credit_rows FROM credit_history;
SELECT COUNT(*) AS loan_rows FROM loan_applications;
SELECT COUNT(*) AS txn_rows FROM transactions;

-- These two are the real test: if dates loaded correctly you'll
-- see real dates, not NULL or 0000-00-00.
SELECT customer_id, date_of_birth, customer_since FROM customers LIMIT 5;
SELECT application_id, application_date, decision_date FROM loan_applications LIMIT 5;

-- Referential sanity check: should return 0 rows if FKs are clean
SELECT la.application_id
FROM loan_applications la
LEFT JOIN customers c ON la.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
USE credora_risk;

-- ============================================================
-- vw_kpi_summary
-- Single-row feed for dashboard KPI cards:
-- total applications, approval rate, default rate, avg loan amount
-- ============================================================
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT
    COUNT(*) AS total_applications,
    SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) AS total_approved,
    ROUND(100 * SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) / COUNT(*), 1) AS approval_rate_pct,
    SUM(disbursed_flag) AS total_disbursed,
    SUM(CASE WHEN disbursed_flag = 1 AND loan_default = 1 THEN 1 ELSE 0 END) AS total_defaults,
    ROUND(
        100 * SUM(CASE WHEN disbursed_flag = 1 AND loan_default = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(disbursed_flag), 0), 1
    ) AS default_rate_pct,
    ROUND(AVG(requested_amount), 0) AS avg_requested_amount,
    ROUND(AVG(CASE WHEN approval_status = 'Approved' THEN approved_amount END), 0) AS avg_approved_amount
FROM loan_applications;


-- ============================================================
-- vw_monthly_trends
-- Feeds trend line charts: applications, approvals, defaults by month
-- ============================================================
CREATE OR REPLACE VIEW vw_monthly_trends AS
SELECT
    DATE_FORMAT(la.application_date, '%Y-%m') AS app_month,
    COUNT(*) AS total_applications,
    SUM(CASE WHEN la.approval_status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
    ROUND(100 * SUM(CASE WHEN la.approval_status = 'Approved' THEN 1 ELSE 0 END) / COUNT(*), 1) AS approval_rate_pct,
    SUM(la.disbursed_flag) AS disbursed_count,
    SUM(CASE WHEN la.disbursed_flag = 1 AND la.loan_default = 1 THEN 1 ELSE 0 END) AS default_count,
    ROUND(AVG(la.requested_amount), 0) AS avg_requested_amount
FROM loan_applications la
GROUP BY app_month
ORDER BY app_month;


-- ============================================================
-- vw_geo_summary
-- Feeds the geographic view: state-level approval/default rates
-- ============================================================
CREATE OR REPLACE VIEW vw_geo_summary AS
SELECT
    c.state,
    c.city,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(la.application_id) AS total_applications,
    SUM(CASE WHEN la.approval_status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
    ROUND(
        100 * SUM(CASE WHEN la.approval_status = 'Approved' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(la.application_id), 0), 1
    ) AS approval_rate_pct,
    SUM(CASE WHEN la.disbursed_flag = 1 AND la.loan_default = 1 THEN 1 ELSE 0 END) AS default_count,
    ROUND(AVG(ch.credit_score), 0) AS avg_credit_score
FROM customers c
LEFT JOIN loan_applications la ON c.customer_id = la.customer_id
LEFT JOIN credit_history ch ON c.customer_id = ch.customer_id
GROUP BY c.state, c.city
ORDER BY c.state, c.city;


-- ============================================================
-- vw_risk_distribution  /  vw_risk_watchlist
-- *** PLACEHOLDER ONLY ***
-- This is a hand-built rule, NOT a machine-learning output.
-- It exists only so the Tableau shell has something to render
-- while F3 (the classifier) doesn't exist yet.
--
-- The scoring below is a simple weighted composite of:
--   credit_score (bureau score, inverted so lower score = higher risk)
--   credit_utilization_ratio (higher = riskier)
--   num_defaults_prior + num_late_payments_90d (history of defaulting)
--   debt_to_income_ratio from the customer's most recent application
--
-- REPLACE THIS VIEW once F3/F4 produce a real P(default) and a
-- real 0-100 score. Do not present this rule as "the model" —
-- it has no validation, no evaluation metrics, no feature
-- importance. It's scaffolding.
-- ============================================================
CREATE OR REPLACE VIEW vw_risk_placeholder_score AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.state,
    c.city,
    ch.credit_score,
    ch.credit_utilization_ratio,
    ch.num_defaults_prior,
    ch.num_late_payments_90d,
    latest_app.debt_to_income_ratio,
    -- composite placeholder score, scaled to roughly 0-100
    -- (this weighting is arbitrary and NOT validated)
    ROUND(
        GREATEST(0, LEAST(100,
            (100 - (ch.credit_score - 300) / 5.5)            * 0.40   -- lower bureau score -> higher risk
            + (ch.credit_utilization_ratio * 100)             * 0.25   -- higher utilization -> higher risk
            + (ch.num_defaults_prior * 15)                    * 0.20   -- prior defaults -> higher risk
            + (ch.num_late_payments_90d * 10)                 * 0.10   -- recent late payments -> higher risk
            + (COALESCE(latest_app.debt_to_income_ratio, 0) * 10) * 0.05 -- DTI -> higher risk
        )), 1
    ) AS placeholder_risk_score
FROM customers c
JOIN credit_history ch ON c.customer_id = ch.customer_id
LEFT JOIN (
    SELECT la1.customer_id, la1.debt_to_income_ratio
    FROM loan_applications la1
    INNER JOIN (
        SELECT customer_id, MAX(application_date) AS max_date
        FROM loan_applications
        GROUP BY customer_id
    ) latest ON la1.customer_id = latest.customer_id AND la1.application_date = latest.max_date
) latest_app ON c.customer_id = latest_app.customer_id;


CREATE OR REPLACE VIEW vw_risk_distribution AS
SELECT
    CASE
        WHEN placeholder_risk_score < 34 THEN 'Low'
        WHEN placeholder_risk_score < 67 THEN 'Medium'
        ELSE 'High'
    END AS risk_category,
    COUNT(*) AS customer_count
FROM vw_risk_placeholder_score
GROUP BY risk_category;


CREATE OR REPLACE VIEW vw_risk_watchlist AS
SELECT
    customer_id,
    first_name,
    last_name,
    state,
    city,
    credit_score,
    placeholder_risk_score,
    CASE
        WHEN placeholder_risk_score < 34 THEN 'Low'
        WHEN placeholder_risk_score < 67 THEN 'Medium'
        ELSE 'High'
    END AS risk_category
FROM vw_risk_placeholder_score
WHERE placeholder_risk_score >= 67
ORDER BY placeholder_risk_score DESC;


-- ============================================================
-- Sanity checks - run these before opening Tableau
-- ============================================================
SELECT * FROM vw_kpi_summary;
SELECT * FROM vw_monthly_trends LIMIT 5;
SELECT * FROM vw_geo_summary LIMIT 5;
SELECT * FROM vw_risk_distribution;
SELECT * FROM vw_risk_watchlist LIMIT 10;

-- ============================================================
-- ANALYTICAL QUERIES 1-10 (PRD F2)
-- Query 8 depends on vw_risk_placeholder_score above being
-- created first. Query 10 is the data-quality checkpoint -
-- default rate should rise as credit score falls and DTI rises.
-- ============================================================

-- Query 1 — Credit score distribution / analysis
SELECT
    CASE
        WHEN credit_score < 580 THEN 'Poor (<580)'
        WHEN credit_score BETWEEN 580 AND 669 THEN 'Fair (580-669)'
        WHEN credit_score BETWEEN 670 AND 739 THEN 'Good (670-739)'
        WHEN credit_score BETWEEN 740 AND 799 THEN 'Very Good (740-799)'
        ELSE 'Excellent (800+)'
    END AS credit_band,
    COUNT(*) AS customer_count,
    ROUND(AVG(credit_utilization_ratio), 3) AS avg_utilization,
    ROUND(AVG(num_defaults_prior), 2) AS avg_prior_defaults
FROM credit_history
GROUP BY credit_band
ORDER BY MIN(credit_score);

-- Query 2 — Approval trends over time
SELECT
    DATE_FORMAT(application_date, '%Y-%m') AS app_month,
    COUNT(*) AS total_applications,
    SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) AS approved,
    ROUND(100 * SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) / COUNT(*), 1) AS approval_rate_pct
FROM loan_applications
GROUP BY app_month
ORDER BY app_month;

-- Query 3 — Customer segmentation (income x employment)
SELECT
    employment_type,
    CASE
        WHEN annual_income < 300000 THEN 'Low (<3L)'
        WHEN annual_income BETWEEN 300000 AND 700000 THEN 'Mid (3L-7L)'
        WHEN annual_income BETWEEN 700001 AND 1500000 THEN 'High (7L-15L)'
        ELSE 'Very High (15L+)'
    END AS income_band,
    COUNT(*) AS customer_count,
    ROUND(AVG(dependents), 1) AS avg_dependents
FROM customers
GROUP BY employment_type, income_band
ORDER BY employment_type, MIN(annual_income);

-- Query 4 — High-risk customer identification
SELECT
    c.customer_id, c.first_name, c.last_name, c.state,
    ch.credit_score, ch.credit_utilization_ratio,
    ch.num_defaults_prior, ch.bankruptcies, ch.num_late_payments_90d
FROM customers c
JOIN credit_history ch ON c.customer_id = ch.customer_id
WHERE ch.credit_score < 580
   OR ch.num_defaults_prior > 0
   OR ch.bankruptcies > 0
   OR ch.credit_utilization_ratio > 0.75
ORDER BY ch.credit_score ASC;

-- Query 5 — Default-rate analysis by loan type and purpose
SELECT
    loan_type, loan_purpose,
    COUNT(*) AS disbursed_count,
    SUM(CASE WHEN loan_default = 1 THEN 1 ELSE 0 END) AS default_count,
    ROUND(100 * SUM(CASE WHEN loan_default = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS default_rate_pct
FROM loan_applications
WHERE disbursed_flag = 1
GROUP BY loan_type, loan_purpose
ORDER BY default_rate_pct DESC;

-- Query 6 — Loan amount distribution
SELECT
    CASE
        WHEN requested_amount < 200000 THEN 'Under 2L'
        WHEN requested_amount BETWEEN 200000 AND 500000 THEN '2L-5L'
        WHEN requested_amount BETWEEN 500001 AND 1500000 THEN '5L-15L'
        WHEN requested_amount BETWEEN 1500001 AND 5000000 THEN '15L-50L'
        ELSE '50L+'
    END AS amount_band,
    COUNT(*) AS application_count,
    SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
    ROUND(100 * SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) / COUNT(*), 1) AS approval_rate_pct
FROM loan_applications
GROUP BY amount_band
ORDER BY MIN(requested_amount);

-- Query 7 — Approval statistics by loan type
SELECT
    loan_type,
    COUNT(*) AS total_applications,
    SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN approval_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected,
    SUM(CASE WHEN approval_status = 'Under Review' THEN 1 ELSE 0 END) AS under_review,
    ROUND(100 * SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) / COUNT(*), 1) AS approval_rate_pct,
    ROUND(AVG(interest_rate), 2) AS avg_interest_rate
FROM loan_applications
GROUP BY loan_type
ORDER BY approval_rate_pct DESC;

-- Query 8 — Risk categorisation (placeholder score - see notes above)
SELECT
    risk_category,
    COUNT(*) AS customer_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total,
    ROUND(AVG(credit_score), 0) AS avg_credit_score
FROM (
    SELECT *,
        CASE
            WHEN placeholder_risk_score < 34 THEN 'Low'
            WHEN placeholder_risk_score < 67 THEN 'Medium'
            ELSE 'High'
        END AS risk_category
    FROM vw_risk_placeholder_score
) t
GROUP BY risk_category
ORDER BY MIN(placeholder_risk_score);

-- Query 9 — Transaction behaviour patterns
SELECT
    category, channel,
    COUNT(*) AS txn_count,
    ROUND(AVG(amount), 2) AS avg_amount,
    ROUND(SUM(amount), 2) AS total_amount
FROM transactions
GROUP BY category, channel
ORDER BY total_amount DESC;

-- Query 10 — Top default predictors (data-quality checkpoint)
SELECT
    CASE
        WHEN ch.credit_score < 580 THEN 'Poor (<580)'
        WHEN ch.credit_score BETWEEN 580 AND 669 THEN 'Fair'
        WHEN ch.credit_score BETWEEN 670 AND 739 THEN 'Good'
        ELSE 'Very Good+'
    END AS credit_band,
    CASE
        WHEN la.debt_to_income_ratio < 1.0 THEN 'DTI < 1.0'
        WHEN la.debt_to_income_ratio BETWEEN 1.0 AND 2.0 THEN 'DTI 1.0-2.0'
        ELSE 'DTI > 2.0'
    END AS dti_band,
    COUNT(*) AS disbursed_count,
    SUM(CASE WHEN la.loan_default = 1 THEN 1 ELSE 0 END) AS default_count,
    ROUND(100 * SUM(CASE WHEN la.loan_default = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS default_rate_pct
FROM loan_applications la
JOIN credit_history ch ON la.customer_id = ch.customer_id
WHERE la.disbursed_flag = 1
GROUP BY credit_band, dti_band
ORDER BY credit_band, dti_band;
