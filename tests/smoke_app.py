"""Run app.py end-to-end against a stubbed `streamlit` module (Streamlit itself is not needed).
Checks that every code path executes without errors. Run:  python tests/smoke_app.py"""
import runpy
import sys
from pathlib import Path
from unittest.mock import MagicMock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

st = MagicMock(name="streamlit")
st.cache_data = lambda *a, **k: (lambda f: f)
st.columns.side_effect = lambda n: [MagicMock() for _ in range(n if isinstance(n, int) else len(n))]
st.tabs.side_effect = lambda labels: [MagicMock() for _ in labels]
st.sidebar.multiselect.return_value = []
st.multiselect.return_value = ["High"]
st.stop.side_effect = SystemExit
sys.modules["streamlit"] = st

runpy.run_path(str(ROOT / "app.py"), run_name="__main__")
print("app.py ran end-to-end (no filters). error calls:", st.error.call_count)

# again with filters applied
st.sidebar.multiselect.side_effect = [["Hyderabad", "Mumbai"], ["Basic"]]
runpy.run_path(str(ROOT / "app.py"), run_name="__main__")
print("app.py ran end-to-end (city + plan filters). error calls:", st.error.call_count)
