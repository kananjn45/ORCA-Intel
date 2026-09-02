"""
tests/conftest.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)

Pytest configuration — makes the backend/ directory importable so that
`from main import app` works from inside the tests/ sub-directory.
"""
import sys
from pathlib import Path

# Add backend/ to sys.path so `import main` and `from app.xxx import yyy` work
# whether pytest is invoked from backend/ or from the repo root.
backend_root = Path(__file__).resolve().parent.parent
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))
