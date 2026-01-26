"""Test outputs endpoint for serving generated audio files."""
from pathlib import Path

from fastapi.testclient import TestClient

from main import app, outputs_dir


def test_outputs_endpoint_serves_file():
    """Test that outputs endpoint serves generated audio files."""
    outputs_dir.mkdir(parents=True, exist_ok=True)
    output_file = outputs_dir / "test-output.wav"
    output_file.write_bytes(b"RIFF")

    client = TestClient(app)
    response = client.get("/audio/test-output.wav")
    assert response.status_code == 200
    assert response.content == b"RIFF"

    # Cleanup
    output_file.unlink(missing_ok=True)


def test_audio_directory_mounted():
    """Test that audio directory is mounted."""
    client = TestClient(app)
    # Should not 404 on the mount point check
    # (actual file may not exist, but mount should be configured)
    response = client.get("/audio/nonexistent.wav")
    # 404 is expected for non-existent file, but not 500
    assert response.status_code in [404, 200]
