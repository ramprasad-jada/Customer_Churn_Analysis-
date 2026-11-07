"""Feature engineering - the pandas twin of the customer_churn_features SQL view."""
import pandas as pd

NUMERIC_FEATURES = ["age", "monthly_fee", "failed_payment_rate", "total_tickets", "unresolved_tickets"]
CATEGORICAL_FEATURES = ["gender", "city", "plan_name"]
MODEL_FEATURES = NUMERIC_FEATURES + CATEGORICAL_FEATURES
# Deliberately NOT used for modelling: tenure_days, total_payments, failed_payments.
# For churned customers these stop growing at the churn date, so they leak the outcome.


def build_features(tables, as_of=None):
    as_of = pd.Timestamp(as_of) if as_of is not None else pd.Timestamp.today().normalize()
    c, s, p = tables["customers"], tables["subscriptions"], tables["plans"]
    pay, tick, churn = tables["payments"], tables["support_tickets"], tables["churn_records"]

    pay_agg = (pay.assign(failed=(pay.payment_status == "Failed").astype(int))
                  .groupby("subscription_id")
                  .agg(total_payments=("payment_id", "count"), failed_payments=("failed", "sum"))
                  .reset_index())
    tick_agg = (tick.assign(unresolved=(tick.resolution_status != "Resolved").astype(int))
                    .groupby("customer_id")
                    .agg(total_tickets=("ticket_id", "count"), unresolved_tickets=("unresolved", "sum"))
                    .reset_index())
    churned_ids = set(churn.loc[churn.churn_status == "Churned", "customer_id"])

    df = (c.merge(s, on="customer_id", how="inner")
            .merge(p, on="plan_id", how="inner")
            .merge(pay_agg, on="subscription_id", how="left")
            .merge(tick_agg, on="customer_id", how="left"))
    for col in ["total_payments", "failed_payments", "total_tickets", "unresolved_tickets"]:
        df[col] = df[col].fillna(0).astype(int)
    df["failed_payment_rate"] = (df.failed_payments / df.total_payments.where(df.total_payments > 0)).fillna(0)
    df["tenure_days"] = (df.end_date.fillna(as_of) - df.start_date).dt.days
    df["churned"] = df.customer_id.isin(churned_ids).astype(int)
    keep = ["customer_id", "customer_name", "age", "gender", "city", "plan_name", "monthly_fee",
            "tenure_days", "total_payments", "failed_payments", "failed_payment_rate",
            "total_tickets", "unresolved_tickets", "subscription_status", "churned"]
    return df[keep]
