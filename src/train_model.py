"""
Train and evaluate churn prediction models.

Run:  python src/train_model.py              (uses MySQL if DB_PASSWORD is set, else CSV files)
Outputs:
  models/churn_model.joblib       best model (full sklearn Pipeline)
  models/metrics.json             evaluation results for every candidate model
  reports/feature_importance.csv  permutation importance on the held-out test set
  data/churn_risk_scores.csv      churn probability for every customer who has not churned
"""
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix, f1_score, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

try:
    from src.database import load_tables
    from src.features import CATEGORICAL_FEATURES, MODEL_FEATURES, NUMERIC_FEATURES, build_features
except ImportError:  # running as `python src/train_model.py`
    from database import load_tables
    from features import CATEGORICAL_FEATURES, MODEL_FEATURES, NUMERIC_FEATURES, build_features

ROOT = Path(__file__).resolve().parents[1]
SEED = 42


def make_pipeline(estimator):
    pre = ColumnTransformer([
        ("num", StandardScaler(), NUMERIC_FEATURES),
        ("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES),
    ])
    return Pipeline([("prep", pre), ("model", estimator)])


def main():
    tables, source = load_tables()
    feats = build_features(tables)
    print(f"Data source: {source} | customers with a subscription: {len(feats)} "
          f"| churn rate: {feats.churned.mean():.1%}")

    X, y = feats[MODEL_FEATURES], feats["churned"]
    X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.2, stratify=y, random_state=SEED)

    candidates = {
        "baseline_majority": DummyClassifier(strategy="most_frequent"),
        "logistic_regression": LogisticRegression(max_iter=1000, class_weight="balanced"),
        "random_forest": RandomForestClassifier(n_estimators=300, min_samples_leaf=5,
                                                class_weight="balanced", random_state=SEED),
    }
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
    results, fitted = {}, {}
    for name, est in candidates.items():
        pipe = make_pipeline(est)
        cv_auc = cross_val_score(pipe, X_tr, y_tr, cv=cv, scoring="roc_auc")
        pipe.fit(X_tr, y_tr)
        proba = pipe.predict_proba(X_te)[:, 1]
        pred = (proba >= 0.5).astype(int)
        results[name] = {
            "cv_roc_auc_mean": round(float(cv_auc.mean()), 3),
            "cv_roc_auc_std": round(float(cv_auc.std()), 3),
            "test_roc_auc": round(float(roc_auc_score(y_te, proba)), 3),
            "test_precision": round(float(precision_score(y_te, pred, zero_division=0)), 3),
            "test_recall": round(float(recall_score(y_te, pred, zero_division=0)), 3),
            "test_f1": round(float(f1_score(y_te, pred, zero_division=0)), 3),
            "confusion_matrix [[TN, FP], [FN, TP]]": confusion_matrix(y_te, pred).tolist(),
        }
        fitted[name] = pipe
        print(f"{name:20s} CV AUC {cv_auc.mean():.3f} +/- {cv_auc.std():.3f} | test AUC "
              f"{results[name]['test_roc_auc']:.3f} | precision {results[name]['test_precision']:.2f} "
              f"| recall {results[name]['test_recall']:.2f}")

    real = {k: v for k, v in results.items() if k != "baseline_majority"}
    best = max(real, key=lambda k: real[k]["cv_roc_auc_mean"])
    print(f"Best model by cross-validated AUC: {best}")

    (ROOT / "models").mkdir(exist_ok=True)
    (ROOT / "reports").mkdir(exist_ok=True)
    joblib.dump(fitted[best], ROOT / "models" / "churn_model.joblib")
    meta = {"best_model": best, "n_train": int(len(X_tr)), "n_test": int(len(X_te)),
            "features": MODEL_FEATURES, "results": results,
            "note": "Trained on synthetic data when using the bundled CSVs; metrics show the pipeline works, "
                    "not real-world accuracy."}
    (ROOT / "models" / "metrics.json").write_text(json.dumps(meta, indent=2))

    imp = permutation_importance(fitted[best], X_te, y_te, scoring="roc_auc", n_repeats=20, random_state=SEED)
    (pd.DataFrame({"feature": MODEL_FEATURES, "importance_mean": imp.importances_mean.round(4),
                   "importance_std": imp.importances_std.round(4)})
       .sort_values("importance_mean", ascending=False)
       .to_csv(ROOT / "reports" / "feature_importance.csv", index=False))

    # score customers who have not churned
    active = feats[feats.churned == 0].copy()
    active["churn_probability"] = fitted[best].predict_proba(active[MODEL_FEATURES])[:, 1].round(3)
    active["risk_band"] = pd.cut(active.churn_probability, [-0.01, 0.33, 0.6, 1.0], labels=["Low", "Medium", "High"])
    (active[["customer_id", "customer_name", "plan_name", "city", "churn_probability", "risk_band"]]
        .sort_values("churn_probability", ascending=False)
        .to_csv(ROOT / "data" / "churn_risk_scores.csv", index=False))
    print("Saved model, metrics, feature importance and churn_risk_scores.csv")


if __name__ == "__main__":
    main()
