"""Smoke tests for generation (requires models to be installed)."""
import os
from pathlib import Path

import pytest


@pytest.mark.skipif(os.getenv("RUN_MODEL_TESTS") != "1", reason="slow model tests")
def test_generation_smoke_clone():
    """Smoke test for voice clone generation."""
    ref_audio = os.getenv("REF_AUDIO_PATH")
    if not ref_audio:
        pytest.skip("REF_AUDIO_PATH not set")

    from tts.qwen3_engine import Qwen3TTSEngine

    engine = Qwen3TTSEngine(model_size="0.6B", mode="clone")
    ref_text = os.getenv("REF_TEXT", "She had your dark suit in greasy wash water all year.")

    output_path = engine.generate_voice_clone(
        text="hello",
        ref_audio_path=ref_audio,
        ref_text=ref_text,
        language="English",
    )
    assert output_path.exists()


@pytest.mark.skipif(os.getenv("RUN_MODEL_TESTS") != "1", reason="slow model tests")
def test_generation_smoke_custom():
    """Smoke test for custom voice generation."""
    from tts.qwen3_engine import Qwen3TTSEngine

    engine = Qwen3TTSEngine(model_size="0.6B", mode="custom")

    output_path = engine.generate_custom_voice(
        text="hello",
        speaker="Ryan",
        language="English",
    )
    assert output_path.exists()
