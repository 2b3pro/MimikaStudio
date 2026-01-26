"""Test streaming generation endpoint."""
from fastapi.testclient import TestClient

from main import app


def test_streaming_endpoint_requires_params():
    """Test that streaming endpoint validates parameters."""
    client = TestClient(app)
    # Custom mode without speaker should fail
    response = client.post("/api/qwen3/generate/stream", json={
        "text": "hi",
        "mode": "custom",
    })
    assert response.status_code == 400
