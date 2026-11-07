"""
Smoke-test queries/03_churn_analysis.sql against the CSV data using SQLite.

MySQL-only functions (DATEDIFF, CURDATE, DATE_FORMAT, LEAST) are emulated so the
LOGIC of every query can be checked without a MySQL server. It does not replace
running the file in MySQL, but it catches wrong joins, bad aggregates and typos.
Run:  python tests/check_churn_sql.py
"""
import re
import sqlite3
from datetime import date, datetime
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
REF = date(2026, 11, 6)


def d(x):
    return datetime.strptime(x[:10], "%Y-%m-%d").date()


con = sqlite3.connect(":memory:")
con.create_function("DATEDIFF", 2, lambda a, b: None if a is None or b is None else (d(a) - d(b)).days)
con.create_function("CURDATE", 0, lambda: REF.isoformat())
con.create_function("DATE_FORMAT", 2, lambda v, f: None if v is None else d(v).strftime("%Y-%m"))
con.create_function("LEAST", 2, lambda a, b: min(a, b))

for csv in sorted((ROOT / "data").glob("*.csv")):
    pd.read_csv(csv).to_sql(csv.stem, con, index=False)

sql = (ROOT / "queries" / "03_churn_analysis.sql").read_text()
sql = re.sub(r"^\s*USE .*?;", "", sql, flags=re.M)
sql = sql.replace("CREATE OR REPLACE VIEW", "CREATE VIEW")
# strip comments, split into statements
sql = "\n".join(l for l in sql.splitlines() if not l.strip().startswith("--"))
stmts = [s.strip() for s in sql.split(";") if s.strip()]

ok = 0
for i, s in enumerate(stmts, 1):
    try:
        cur = con.execute(s)
        rows = cur.fetchall()
        ok += 1
        if rows:
            cols = [c[0] for c in cur.description]
            print(f"\n[{i}] {s.splitlines()[0][:70]}")
            print(pd.DataFrame(rows, columns=cols).head(8).to_string(index=False))
    except Exception as e:
        print(f"\n[{i}] FAILED: {e}\n{s[:200]}")
print(f"\n{ok}/{len(stmts)} statements ran")
