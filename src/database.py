"""
Database access for the churn project.

Credentials come from environment variables (or a local .env file), never from source code.
If MySQL is not reachable, load_tables() falls back to the CSV files in data/ so the
dashboard and notebook still work.
"""
import os
from pathlib import Path

import pandas as pd

try:  # optional dependency
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:  # pragma: no cover
    pass

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"

TABLES = ["customers", "plans", "services", "subscriptions",
          "payments", "support_tickets", "churn_records"]
DATE_COLUMNS = {
    "customers": ["registration_date"],
    "subscriptions": ["start_date", "end_date"],
    "payments": ["payment_date"],
    "support_tickets": ["ticket_date"],
    "churn_records": ["churn_date"],
}


def get_engine():
    """SQLAlchemy engine built from DB_* environment variables."""
    from sqlalchemy import create_engine
    from sqlalchemy.engine import URL

    password = os.getenv("DB_PASSWORD")
    if not password:
        raise RuntimeError("DB_PASSWORD is not set. Copy .env.example to .env and fill it in.")
    url = URL.create(
        "mysql+mysqlconnector",
        username=os.getenv("DB_USER", "churn_user"),
        password=password,
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        database=os.getenv("DB_NAME", "customer_churn_analysis"),
    )
    return create_engine(url, pool_pre_ping=True)


def _parse_dates(tables):
    for name, cols in DATE_COLUMNS.items():
        for col in cols:
            tables[name][col] = pd.to_datetime(tables[name][col])
    return tables


def load_from_mysql():
    engine = get_engine()
    with engine.connect() as conn:
        tables = {t: pd.read_sql(f"SELECT * FROM {t}", conn) for t in TABLES}
    return _parse_dates(tables)


def load_from_csv():
    tables = {t: pd.read_csv(DATA_DIR / f"{t}.csv") for t in TABLES}
    return _parse_dates(tables)


def load_tables(prefer_mysql=True):
    """Return (tables_dict, source_label). Falls back to CSV if MySQL fails."""
    if prefer_mysql and os.getenv("DB_PASSWORD"):
        try:
            return load_from_mysql(), "MySQL"
        except Exception as exc:  # connection refused, wrong password, missing tables...
            return load_from_csv(), f"CSV fallback (MySQL unavailable: {type(exc).__name__})"
    return load_from_csv(), "CSV files"


if __name__ == "__main__":
    data, source = load_tables()
    print("Source:", source)
    for name, df in data.items():
        print(f"{name:16s} {len(df):5d} rows")
