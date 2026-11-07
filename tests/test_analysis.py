"""Consistency tests. Run:  python tests/test_analysis.py   (or: pytest tests)"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import pandas as pd

from src.analysis import churn_rate_by, kpis
from src.database import load_from_csv
from src.features import build_features

tables = load_from_csv()
feats = build_features(tables, as_of="2026-11-06")


def test_one_row_per_subscribed_customer():
    assert feats.customer_id.is_unique
    assert len(feats) == tables["subscriptions"].customer_id.nunique()


def test_churn_label_matches_churn_records():
    churned = set(tables["churn_records"].query("churn_status == 'Churned'").customer_id)
    assert set(feats.loc[feats.churned == 1, "customer_id"]) == churned


def test_churn_rate_matches_sql_check():
    # tests/check_churn_sql.py reports 300 customers, 99 churned, 33.0% on the bundled data
    k = kpis(feats, tables["churn_records"])
    assert (k["customers"], k["churned"], k["churn_rate_pct"]) == (300, 99, 33.0)


def test_plan_rates_are_consistent():
    by_plan = churn_rate_by(feats, "plan_name")
    assert by_plan.customers.sum() == len(feats)
    assert by_plan.churned.sum() == feats.churned.sum()


def test_failed_payment_rate_bounds():
    assert feats.failed_payment_rate.between(0, 1).all()


def test_no_orphan_foreign_keys():
    t = tables
    assert t["subscriptions"].customer_id.isin(t["customers"].customer_id).all()
    assert t["payments"].subscription_id.isin(t["subscriptions"].subscription_id).all()
    assert t["support_tickets"].customer_id.isin(t["customers"].customer_id).all()
    assert t["churn_records"].customer_id.isin(t["customers"].customer_id).all()


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("PASS", name)
