"""Test configuration for MimikaStudio backend tests."""
import sys
from pathlib import Path

# Add backend root to path for imports
backend_root = Path(__file__).resolve().parents[1]
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))
