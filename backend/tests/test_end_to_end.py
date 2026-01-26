"""End-to-end tests for MimikaStudio backend."""
from fastapi.testclient import TestClient

from main import app


def test_end_to_end():
    """Test basic API flow."""
    client = TestClient(app)

    # Health check
    health = client.get("/api/health")
    assert health.status_code == 200
    assert health.json()["status"] == "ok"

    # List voices
    voices = client.get("/api/qwen3/voices")
    assert voices.status_code == 200
    assert "voices" in voices.json()

    # List speakers
    speakers = client.get("/api/qwen3/speakers")
    assert speakers.status_code == 200
    assert "speakers" in speakers.json()
    assert len(speakers.json()["speakers"]) == 9

    # List models
    models = client.get("/api/qwen3/models")
    assert models.status_code == 200
    assert "models" in models.json()

    # List languages
    languages = client.get("/api/qwen3/languages")
    assert languages.status_code == 200
    assert "languages" in languages.json()

    # System info
    info = client.get("/api/system/info")
    assert info.status_code == 200
    assert "python_version" in info.json()
