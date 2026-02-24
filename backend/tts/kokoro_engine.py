"""Kokoro TTS engine with voice blending on MLX.

Supports all Kokoro-82M voices (American, British, etc.) and weighted
voice blending to create custom voice combinations.

v2.0.0 | 2026-02-17
"""
from __future__ import annotations

import json
import logging
import threading
import uuid
from pathlib import Path
from typing import Optional

import numpy as np
import soundfile as sf

try:
    from mlx_audio.tts import load as load_tts_model
except ImportError:
    load_tts_model = None

try:
    import mlx.core as mx
except Exception:  # pragma: no cover - fallback for non-MLX systems
    mx = None

logger = logging.getLogger(__name__)

# ─── Voice Registry ──────────────────────────────────────────────────
# All voices from Kokoro-82M. Prefix determines language:
#   a = American English, b = British English

KOKORO_VOICES = {
    # American Female
    "af_alloy":   {"name": "Alloy",   "gender": "female", "accent": "american", "grade": "B"},
    "af_aoede":   {"name": "Aoede",   "gender": "female", "accent": "american", "grade": "B+"},
    "af_heart":   {"name": "Heart",   "gender": "female", "accent": "american", "grade": "A"},
    "af_jessica": {"name": "Jessica", "gender": "female", "accent": "american", "grade": "B+"},
    "af_kore":    {"name": "Kore",    "gender": "female", "accent": "american", "grade": "B+"},
    "af_nova":    {"name": "Nova",    "gender": "female", "accent": "american", "grade": "A-"},
    "af_river":   {"name": "River",   "gender": "female", "accent": "american", "grade": "B"},
    "af_sarah":   {"name": "Sarah",   "gender": "female", "accent": "american", "grade": "B+"},
    "af_sky":     {"name": "Sky",     "gender": "female", "accent": "american", "grade": "B-"},
    # American Male
    "am_adam":    {"name": "Adam",    "gender": "male", "accent": "american", "grade": "B+"},
    "am_echo":    {"name": "Echo",    "gender": "male", "accent": "american", "grade": "B"},
    "am_eric":    {"name": "Eric",    "gender": "male", "accent": "american", "grade": "B+"},
    "am_fenrir":  {"name": "Fenrir",  "gender": "male", "accent": "american", "grade": "B"},
    "am_liam":    {"name": "Liam",    "gender": "male", "accent": "american", "grade": "B+"},
    "am_michael": {"name": "Michael", "gender": "male", "accent": "american", "grade": "B"},
    "am_onyx":    {"name": "Onyx",    "gender": "male", "accent": "american", "grade": "B"},
    "am_puck":    {"name": "Puck",    "gender": "male", "accent": "american", "grade": "B"},
    "am_santa":   {"name": "Santa",   "gender": "male", "accent": "american", "grade": "C"},
    # British Female
    "bf_emma":     {"name": "Emma",     "gender": "female", "accent": "british", "grade": "B-"},
    "bf_alice":    {"name": "Alice",    "gender": "female", "accent": "british", "grade": "D"},
    "bf_isabella": {"name": "Isabella", "gender": "female", "accent": "british", "grade": "C"},
    "bf_lily":     {"name": "Lily",     "gender": "female", "accent": "british", "grade": "D"},
    # British Male
    "bm_daniel":  {"name": "Daniel", "gender": "male", "accent": "british", "grade": "D"},
    "bm_fable":   {"name": "Fable",  "gender": "male", "accent": "british", "grade": "C"},
    "bm_george":  {"name": "George", "gender": "male", "accent": "british", "grade": "C"},
    "bm_lewis":   {"name": "Lewis",  "gender": "male", "accent": "british", "grade": "D+"},
}

# Keep BRITISH_VOICES as alias for backward compatibility
BRITISH_VOICES = {k: v for k, v in KOKORO_VOICES.items() if v["accent"] == "british"}

DEFAULT_VOICE = "af_heart"

# Lang code prefix mapping
ACCENT_TO_LANG_CODE = {
    "american": "a",
    "british": "b",
}


class KokoroEngine:
    """Kokoro TTS engine with voice blending on Apple Silicon (MLX)."""

    def __init__(self):
        self.model = None
        self._generate_lock = threading.Lock()
        self.outputs_dir = Path(__file__).parent.parent / "outputs"
        self.outputs_dir.mkdir(parents=True, exist_ok=True)
        self._blends_dir = Path(__file__).parent.parent / "data" / "blended_voices" / "kokoro"
        self._blends_dir.mkdir(parents=True, exist_ok=True)
        self._blended_registry: dict[str, dict] = {}
        self._load_blend_registry()

    def _load_blend_registry(self):
        """Load saved blend recipes from disk."""
        registry_file = self._blends_dir / "blends.json"
        if registry_file.exists():
            try:
                self._blended_registry = json.loads(registry_file.read_text())
            except Exception as e:
                logger.warning(f"Failed to load blend registry: {e}")
                self._blended_registry = {}

    def _save_blend_registry(self):
        """Persist blend recipes to disk."""
        registry_file = self._blends_dir / "blends.json"
        registry_file.write_text(json.dumps(self._blended_registry, indent=2))

    def load_model(self):
        if self.model is None:
            if load_tts_model is None:
                raise ImportError("mlx-audio package not installed. Install with: pip install -U mlx-audio")
            self.model = load_tts_model("mlx-community/Kokoro-82M-bf16")
        return self.model

    def _get_pipeline(self, lang_code: str = "a"):
        """Get the KokoroPipeline for a given language code."""
        self.load_model()
        return self.model._get_pipeline(lang_code)

    def unload(self):
        self.model = None
        if mx is not None:
            mx.clear_cache()

    # ─── Voice Blending ──────────────────────────────────────────────

    def blend_voices(
        self,
        name: str,
        voices: list[str],
        weights: Optional[list[float]] = None,
    ) -> dict:
        """Create a blended voice from multiple Kokoro voice embeddings.

        Args:
            name: Name for the blended voice (used as identifier)
            voices: List of voice codes to blend (e.g. ["af_heart", "am_adam"])
            weights: Blend weights (must sum to 1.0). If None, equal weights used.

        Returns:
            Dict with blend info: name, voices, weights, saved path
        """
        if mx is None:
            raise RuntimeError("MLX not available — blending requires Apple Silicon")

        self.load_model()

        if len(voices) < 2:
            raise ValueError("Need at least 2 voices to blend")

        # Default to equal weights
        if weights is None:
            weights = [1.0 / len(voices)] * len(voices)

        if len(voices) != len(weights):
            raise ValueError(f"voices ({len(voices)}) and weights ({len(weights)}) must match")

        weight_sum = sum(weights)
        if abs(weight_sum - 1.0) > 0.01:
            raise ValueError(f"Weights must sum to 1.0, got {weight_sum}")

        # Validate all source voices exist
        for v in voices:
            if v not in KOKORO_VOICES:
                raise ValueError(f"Unknown voice: {v}. Available: {list(KOKORO_VOICES.keys())}")

        # Load and blend voice embeddings via pipeline
        # Determine lang_code from first voice's accent
        first_accent = KOKORO_VOICES[voices[0]]["accent"]
        lang_code = ACCENT_TO_LANG_CODE.get(first_accent, "a")
        pipeline = self._get_pipeline(lang_code)

        blended = None
        for voice_code, weight in zip(voices, weights):
            embedding = pipeline.load_single_voice(voice_code)
            weighted = embedding * weight
            if blended is None:
                blended = weighted
            else:
                blended = blended + weighted

        # Save the blended embedding as safetensors for persistence
        blend_file = self._blends_dir / f"{name}.safetensors"
        mx.save_safetensors(str(blend_file), {"voice": blended})

        # Record recipe in registry
        recipe = {
            "name": name,
            "voices": voices,
            "weights": weights,
            "file": str(blend_file),
        }
        self._blended_registry[name] = recipe
        self._save_blend_registry()

        logger.info(f"Blended voice '{name}' created from {dict(zip(voices, weights))}")
        return recipe

    def delete_blend(self, name: str) -> bool:
        """Delete a blended voice."""
        if name not in self._blended_registry:
            return False

        # Remove file
        blend_file = self._blends_dir / f"{name}.safetensors"
        if blend_file.exists():
            blend_file.unlink()

        # Remove from registry
        del self._blended_registry[name]
        self._save_blend_registry()
        return True

    def get_blends(self) -> dict[str, dict]:
        """Get all saved blend recipes."""
        return dict(self._blended_registry)

    def _blend_file_path(self, voice: str) -> Optional[Path]:
        """Get the safetensors file path for a blended voice, or None."""
        blend_file = self._blends_dir / f"{voice}.safetensors"
        return blend_file if blend_file.exists() else None

    # ─── Voice Lookup ────────────────────────────────────────────────

    def _resolve_voice(self, voice: str) -> tuple[str, str]:
        """Resolve a voice name to (voice_code_or_path, lang_code).

        For built-in voices, returns (voice_code, lang_code).
        For blended voices, returns (safetensors_path, lang_code) so the
        pipeline loads the blend file directly (Model.generate resets
        pipeline.voices each call).
        """
        # Built-in voice
        if voice in KOKORO_VOICES:
            accent = KOKORO_VOICES[voice]["accent"]
            lang_code = ACCENT_TO_LANG_CODE.get(accent, "a")
            return voice, lang_code

        # Blended voice — return file path so pipeline loads it directly
        if voice in self._blended_registry:
            first_source = self._blended_registry[voice]["voices"][0]
            accent = KOKORO_VOICES.get(first_source, {}).get("accent", "american")
            lang_code = ACCENT_TO_LANG_CODE.get(accent, "a")
            blend_path = self._blend_file_path(voice)
            if blend_path:
                return str(blend_path), lang_code
            logger.warning(f"Blend '{voice}' registered but file missing, falling back")
            return DEFAULT_VOICE, "a"

        # Fallback
        logger.warning(f"Unknown voice '{voice}', falling back to {DEFAULT_VOICE}")
        return DEFAULT_VOICE, "a"

    # ─── Generation ──────────────────────────────────────────────────

    def generate(self, text: str, voice: str = DEFAULT_VOICE, speed: float = 1.0) -> Path:
        """Generate speech and save to WAV file."""
        audio, sample_rate = self.generate_audio(text=text, voice=voice, speed=speed)

        self.outputs_dir.mkdir(parents=True, exist_ok=True)
        short_uuid = str(uuid.uuid4())[:8]
        output_file = self.outputs_dir / f"kokoro-{voice}-{short_uuid}.wav"
        sf.write(str(output_file), audio, sample_rate)

        return output_file

    def generate_audio(self, text: str, voice: str = DEFAULT_VOICE, speed: float = 1.0):
        """Generate audio as a numpy array and sample rate."""
        self.load_model()

        voice, lang_code = self._resolve_voice(voice)

        audio_chunks = []
        sample_rate = 24000
        with self._generate_lock:
            generator = self.model.generate(
                text=text,
                voice=voice,
                speed=speed,
                lang_code=lang_code,
            )
            for result in generator:
                sample_rate = int(getattr(result, "sample_rate", sample_rate))
                audio_chunks.append(np.asarray(result.audio, dtype=np.float32).reshape(-1))
        if not audio_chunks:
            return np.array([], dtype=np.float32), 24000

        full_audio = np.concatenate(audio_chunks)
        return full_audio, sample_rate

    def get_voices(self) -> dict:
        """Get all available voices (built-in + blended)."""
        return KOKORO_VOICES

    def get_all_voices(self) -> dict:
        """Get built-in voices plus blended voices in a unified dict."""
        all_voices = dict(KOKORO_VOICES)
        for name, recipe in self._blended_registry.items():
            source_desc = " + ".join(
                f"{v}({int(w*100)}%)"
                for v, w in zip(recipe["voices"], recipe["weights"])
            )
            all_voices[name] = {
                "name": name,
                "gender": "blended",
                "accent": "blended",
                "grade": "custom",
                "blend_source": source_desc,
                "recipe": recipe,
            }
        return all_voices

    def get_default_voice(self) -> str:
        return DEFAULT_VOICE


# Singleton instance
_engine = None


def get_kokoro_engine() -> KokoroEngine:
    global _engine
    if _engine is None:
        _engine = KokoroEngine()
    return _engine
