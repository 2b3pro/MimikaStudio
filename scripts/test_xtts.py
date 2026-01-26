#!/usr/bin/env python3
"""
Test XTTS2 Voice Cloning Engine
Generates sample audio files in runs/xtts/
"""

import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))

from tts.xtts_engine import get_xtts_engine
import shutil

RUNS_DIR = Path(__file__).parent.parent / "runs" / "xtts"
VOICES_DIR = Path(__file__).parent.parent / "backend" / "data" / "samples" / "voices"

def main():
    print("=" * 50)
    print("XTTS2 Voice Cloning Test")
    print("=" * 50)

    # Setup output directory
    RUNS_DIR.mkdir(parents=True, exist_ok=True)

    # Get engine
    print("\nLoading XTTS2 model (this may take a while on first run)...")
    engine = get_xtts_engine()
    engine.load_model()
    print("Model loaded successfully!")

    # Test texts
    test_texts = [
        ("greeting", "Hello! Welcome to the text to speech demonstration."),
        ("quote", "Even in the darkest nights, a single spark of hope can ignite the fire of determination."),
        ("question", "How are you doing today? I hope everything is going well."),
    ]

    # Available voices
    voices = list(VOICES_DIR.glob("*.wav"))
    print(f"\nFound {len(voices)} voices: {[v.stem for v in voices]}")

    # Generate samples
    results = []
    for voice_path in voices[:2]:  # Test with first 2 voices
        voice_name = voice_path.stem
        print(f"\n--- Testing voice: {voice_name} ---")

        for text_id, text in test_texts:
            print(f"  Generating: {text_id}...")
            try:
                output_path = engine.generate(
                    text=text,
                    speaker_wav_path=str(voice_path),
                    language="English",
                    speed=0.8
                )

                # Copy to runs folder with descriptive name
                dest_path = RUNS_DIR / f"{voice_name}_{text_id}.wav"
                shutil.copy(output_path, dest_path)

                results.append({
                    "voice": voice_name,
                    "text_id": text_id,
                    "output": str(dest_path),
                    "size": dest_path.stat().st_size,
                    "status": "success"
                })
                print(f"    ✓ Saved: {dest_path.name} ({dest_path.stat().st_size:,} bytes)")

            except Exception as e:
                results.append({
                    "voice": voice_name,
                    "text_id": text_id,
                    "status": "failed",
                    "error": str(e)
                })
                print(f"    ✗ Failed: {e}")

    # Summary
    print("\n" + "=" * 50)
    print("XTTS Test Summary")
    print("=" * 50)
    success = sum(1 for r in results if r["status"] == "success")
    print(f"Total: {len(results)}, Success: {success}, Failed: {len(results) - success}")
    print(f"Output directory: {RUNS_DIR}")
    print("\nGenerated files:")
    for f in sorted(RUNS_DIR.glob("*.wav")):
        print(f"  - {f.name} ({f.stat().st_size:,} bytes)")

if __name__ == "__main__":
    main()
