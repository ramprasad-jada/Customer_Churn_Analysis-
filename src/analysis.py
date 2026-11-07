"""Pure-pandas churn analysis helpers (used by the dashboard, notebook and tests)."""
import pandas as pd


def churn_rate_by(features, column):
    out = (features.groupby(column)
                   .agg(customers=("churned", "size"), churned=("churned", "sum"))
                   .reset_index())
    out["churn_rate_pct"] = (100 * out.churned / out.customers).round(2)
    return out.sort_values("churn_rate_pct", ascending=False)


def age_group(series):
    bins = [0, 24, 34, 44, 54, 200]
    labels = ["Under 25", "25-34", "35-44", "45-54", "55+"]
    return pd.cut(series, bins=bins, labels=labels)


def kpis(features, churn_records):
    total = len(features)
    churned = int(features.churned.sum())
    at_risk = int((churn_records.churn_status == "At Risk").sum())
    lost_mrr = float(features.loc[features.churned == 1, "monthly_fee"].sum())
    return dict(customers=total, churned=churned,
                churn_rate_pct=round(100 * churned / total, 1) if total else 0.0,
                at_risk=at_risk, lost_monthly_revenue=lost_mrr)


def monthly_churn(churn_records):
    c = churn_records[(churn_records.churn_status == "Churned") & churn_records.churn_date.notna()]
    return c.groupby(c.churn_date.dt.to_period("M").astype(str)).size().rename("churned_customers")


def monthly_payments(payments):
    p = payments.copy()
    p["month"] = p.payment_date.dt.to_period("M").astype(str)
    out = p.pivot_table(index="month", columns="payment_status", values="payment_amount", aggfunc="sum", fill_value=0)
    return out


def churn_reasons(churn_records):
    c = churn_records[churn_records.churn_status == "Churned"]
    return c.churn_reason.value_counts()
