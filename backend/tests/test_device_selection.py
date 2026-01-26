"""Test device selection for Qwen3 engine."""
from tts.qwen3_engine import Qwen3TTSEngine


def test_engine_default_device():
    """Test that engine selects appropriate device."""
    engine = Qwen3TTSEngine(model_size="0.6B")
    device, dtype = engine._get_device_and_dtype()
    # Should return either cuda:0 or cpu
    assert device in ["cuda:0", "cpu", "mps"]
