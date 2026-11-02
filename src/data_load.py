"""
Reusable MySQL connection + table loading for the Credora project.
Extracted from the connection boilerplate repeated in every notebook
(01_eda, 02_feature_engineering, 03_modeling, app.py) so it lives in
one place instead of four.

Usage:
    from src.data_load import get_engine, load_all_tables
    engine = get_engine()
    tables = load_all_tables(engine)
    customers = tables["customers"]
"""

import os
import pandas as pd
from sqlalchemy import create_engine, URL


def get_engine(database: str = "credora_risk"):
    """Build a SQLAlchemy engine from the MYSQL_PASSWORD env var.

    Requires MYSQL_PASSWORD to already be set (setx on Windows,
    export on Mac/Linux) — see the README for setup.
    """
    if "MYSQL_PASSWORD" not in os.environ:
        raise RuntimeError(
            "MYSQL_PASSWORD environment variable is not set. "
            "Run: setx MYSQL_PASSWORD \"yourpassword\" (Windows, then "
            "restart your terminal/IDE) or export MYSQL_PASSWORD=... "
            "(Mac/Linux) before running this script."
        )
    url = URL.create(
        drivername="mysql+mysqlconnector",
        username="root",
        password=os.environ["MYSQL_PASSWORD"],
        host="localhost",
        database=database,
    )
    return create_engine(url)


def load_all_tables(engine) -> dict:
    """Load the four core tables as a dict of DataFrames."""
    return {
        "customers": pd.read_sql("SELECT * FROM customers", engine),
        "credit_history": pd.read_sql("SELECT * FROM credit_history", engine),
        "loan_applications": pd.read_sql("SELECT * FROM loan_applications", engine),
        "transactions": pd.read_sql("SELECT * FROM transactions", engine),
    }


def load_scored_customers(engine) -> pd.DataFrame:
    """Load the scored_customers table — only exists after
    04_risk_scoring.ipynb has been run successfully."""
    return pd.read_sql("SELECT * FROM scored_customers", engine)
