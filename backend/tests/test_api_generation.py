"""Test Qwen3-TTS generation endpoints."""
from fastapi.testclient import TestClient

from main import app


def test_qwen3_generate_clone_requires_voice():
    """Test that clone mode requires voice_name."""
    client = TestClient(app)
    response = client.post("/api/qwen3/generate", json={
        "text": "hello",
        "mode": "clone",
    })
    assert response.status_code == 400
    assert "voice_name" in response.json()["detail"].lower()


def test_qwen3_generate_custom_requires_speaker():
    """Test that custom mode requires speaker."""
    client = TestClient(app)
    response = client.post("/api/qwen3/generate", json={
        "text": "hello",
        "mode": "custom",
    })
    assert response.status_code == 400
    assert "speaker" in response.json()["detail"].lower()


def test_qwen3_generate_invalid_mode():
    """Test that invalid mode returns error."""
    client = TestClient(app)
    response = client.post("/api/qwen3/generate", json={
        "text": "hello",
        "mode": "invalid",
    })
    assert response.status_code == 400
