"""
Generate a reproducible synthetic dataset for the Customer Churn Analysis project.

Outputs
-------
data/*.csv                 one CSV per table
database/seed_data.sql     INSERT statements for MySQL

Run:  python src/generate_data.py
The data is SYNTHETIC. Churn is simulated from tickets, failed payments, plan
and age, so models trained on it demonstrate the pipeline, not real-world accuracy.
"""
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
N_CUSTOMERS = 300
N_PROSPECTS = 5                      # customers with no subscription yet
REF_DATE = pd.Timestamp("2026-11-06")  # "today" for the dataset

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
DB_DIR = ROOT / "database"

rng = np.random.default_rng(SEED)

CITIES = ["Hyderabad", "Bangalore", "Chennai", "Mumbai", "Delhi", "Pune", "Visakhapatnam"]
CITY_P = [0.22, 0.2, 0.12, 0.14, 0.12, 0.1, 0.1]
FIRST = ["Ravi", "Anil", "Sita", "Priya", "Kiran", "Rahul", "Sneha", "Venkat", "Lakshmi", "Arjun",
         "Divya", "Mohan", "Neha", "Suresh", "Anjali", "Rohit", "Meena", "Vikram", "Pooja", "Ramesh",
         "Swathi", "Karthik", "Deepa", "Manoj", "Harini", "Naveen", "Bhavana", "Sandeep", "Isha", "Tarun"]
LAST = ["Reddy", "Sharma", "Rao", "Kumar", "Naidu", "Patel", "Singh", "Iyer", "Gupta", "Das",
        "Verma", "Nair", "Joshi", "Chowdary", "Mehta"]

PLANS = pd.DataFrame({
    "plan_id": [1, 2, 3, 4],
    "plan_name": ["Basic", "Standard", "Premium", "Family"],
    "monthly_fee": [299.00, 499.00, 799.00, 1099.00],
})
SERVICES = pd.DataFrame({
    "service_id": [1, 2, 3, 4],
    "service_name": ["Mobile", "Broadband", "DTH", "OTT Bundle"],
    "service_type": ["Telecom", "Internet", "Entertainment", "Entertainment"],
})
ISSUES = ["Billing", "Network", "Service Quality", "Plan Change", "Technical"]
REASONS = ["High price", "Poor service quality", "Billing issues", "Moved to competitor", "No longer needed"]
METHODS = ["UPI", "Credit Card", "Debit Card", "Net Banking"]


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def build():
    customers, subs, payments, tickets, churn = [], [], [], [], []
    pay_id = tick_id = churn_id = 1

    for i in range(1, N_CUSTOMERS + N_PROSPECTS + 1):
        name = f"{rng.choice(FIRST)} {rng.choice(LAST)}"
        age = int(np.clip(rng.normal(36, 11), 18, 70))
        gender = rng.choice(["Male", "Female", "Other"], p=[0.48, 0.48, 0.04])
        city = rng.choice(CITIES, p=CITY_P)
        reg = REF_DATE - pd.Timedelta(days=int(rng.integers(120, 1100)))
        customers.append(dict(
            customer_id=i, customer_name=name, age=age, gender=gender, city=city,
            email=f"{name.lower().replace(' ', '.')}{i}@example.com",
            registration_date=reg.date(),
        ))
        if i > N_CUSTOMERS:          # prospects: no subscription
            continue

        plan = rng.choice([1, 2, 3, 4], p=[0.35, 0.32, 0.2, 0.13])
        fee = float(PLANS.loc[PLANS.plan_id == plan, "monthly_fee"].iloc[0])
        service = int(rng.integers(1, 5))
        start = reg + pd.Timedelta(days=int(rng.integers(0, 15)))
        tenure_m = max(2, int((REF_DATE - start).days // 30))

        # behaviour drivers (generated first, churn is then derived from them)
        n_tickets = int(rng.poisson(0.9 + (plan == 1) * 0.4))
        unresolved = int(sum(rng.random(n_tickets) < 0.3))
        fail_rate = float(np.clip(rng.beta(1.2, 9) + (plan == 1) * 0.04, 0, 0.6))

        logit = (-2.0 + 0.55 * (plan == 1) - 0.5 * (plan == 3) - 0.4 * (plan == 4)
                 + 0.30 * n_tickets + 0.70 * unresolved + 4.0 * fail_rate
                 + 0.35 * (age < 25) + rng.normal(0, 0.4))
        p_churn = float(sigmoid(logit))
        churned = rng.random() < p_churn

        if churned:
            life_m = int(rng.integers(2, max(3, tenure_m) + 1))
            end = start + pd.DateOffset(months=life_m)
            end = min(end, REF_DATE - pd.Timedelta(days=3))
            status = "Cancelled" if rng.random() < 0.7 else "Expired"
        else:
            life_m, end, status = tenure_m, None, "Active"

        subs.append(dict(
            subscription_id=i, customer_id=i, plan_id=int(plan), service_id=service,
            start_date=start.date(), end_date=end.date() if end is not None else None,
            subscription_status=status,
        ))

        # monthly payments
        last = end if end is not None else REF_DATE
        d = start
        while d <= last:
            r = rng.random()
            pstatus = "Failed" if r < fail_rate else ("Pending" if r < fail_rate + 0.02 else "Success")
            payments.append(dict(
                payment_id=pay_id, subscription_id=i, payment_date=d.date(),
                payment_amount=fee, payment_method=rng.choice(METHODS), payment_status=pstatus,
            ))
            pay_id += 1
            d = d + pd.DateOffset(months=1)

        # support tickets inside the customer's active window
        span = max(1, (last - start).days)
        for k in range(n_tickets):
            status_t = "Resolved"
            if k < unresolved:
                status_t = rng.choice(["Open", "Escalated", "Pending"])
            tickets.append(dict(
                ticket_id=tick_id, customer_id=i, issue_category=rng.choice(ISSUES),
                resolution_status=status_t,
                ticket_date=(start + pd.Timedelta(days=int(rng.integers(0, span)))).date(),
            ))
            tick_id += 1

        # churn records
        if churned:
            reason = rng.choice(REASONS, p=[0.28, 0.25, 0.17, 0.2, 0.1])
            churn.append(dict(churn_id=churn_id, customer_id=i, churn_status="Churned",
                              churn_date=end.date(), churn_reason=reason))
            churn_id += 1
        elif p_churn > 0.45:
            churn.append(dict(churn_id=churn_id, customer_id=i, churn_status="At Risk",
                              churn_date=None, churn_reason=rng.choice(["High price", "Poor service quality", "Billing issues"])))
            churn_id += 1

    return dict(
        customers=pd.DataFrame(customers), plans=PLANS, services=SERVICES,
        subscriptions=pd.DataFrame(subs), payments=pd.DataFrame(payments),
        support_tickets=pd.DataFrame(tickets), churn_records=pd.DataFrame(churn),
    )


def sql_literal(v):
    if v is None or (isinstance(v, float) and np.isnan(v)) or v is pd.NaT:
        return "NULL"
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return f"{float(v):.2f}"
    return "'" + str(v).replace("'", "''") + "'"


def write_sql(tables, path, batch=100):
    order = ["plans", "services", "customers", "subscriptions", "payments", "support_tickets", "churn_records"]
    lines = ["-- Synthetic seed data (generated by src/generate_data.py)",
             "USE customer_churn_analysis;", "SET FOREIGN_KEY_CHECKS = 0;"]
    for t in order:
        lines.append(f"TRUNCATE TABLE {t};")
    lines.append("SET FOREIGN_KEY_CHECKS = 1;\n")
    for t in order:
        df = tables[t].astype(object).where(tables[t].notna(), None)
        cols = ", ".join(df.columns)
        for s in range(0, len(df), batch):
            chunk = df.iloc[s:s + batch]
            rows = ",\n".join("  (" + ", ".join(sql_literal(v) for v in r) + ")" for r in chunk.itertuples(index=False))
            lines.append(f"INSERT INTO {t} ({cols}) VALUES\n{rows};\n")
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    DATA_DIR.mkdir(exist_ok=True)
    DB_DIR.mkdir(exist_ok=True)
    tables = build()
    for name, df in tables.items():
        df.to_csv(DATA_DIR / f"{name}.csv", index=False)
        print(f"{name:16s} {len(df):5d} rows")
    write_sql(tables, DB_DIR / "seed_data.sql")
    print("Wrote data/*.csv and database/seed_data.sql")
