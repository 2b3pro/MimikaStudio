#!/usr/bin/env python3
"""
Test Kokoro TTS Engine (British Voices)
Generates sample audio files in runs/kokoro/
"""

import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))

from tts.kokoro_engine import get_kokoro_engine, BRITISH_VOICES
import shutil

RUNS_DIR = Path(__file__).parent.parent / "runs" / "kokoro"

def main():
    print("=" * 50)
    print("Kokoro TTS Test (British Voices)")
    print("=" * 50)

    # Setup output directory
    RUNS_DIR.mkdir(parents=True, exist_ok=True)

    # Get engine
    print("\nLoading Kokoro model...")
    engine = get_kokoro_engine()
    engine.load_model()
    print("Model loaded successfully!")

    # Test texts
    test_texts = [
        ("greeting", "Good morning! The weather today is absolutely splendid."),
        ("polite", "I would be delighted to assist you with that inquiry."),
        ("casual", "Would you fancy a cup of tea? It's freshly brewed."),
    ]

    # All British voices
    print(f"\nBritish voices available: {list(BRITISH_VOICES.keys())}")

    # Generate samples for all British voices
    results = []
    for voice_code, voice_info in BRITISH_VOICES.items():
        print(f"\n--- Testing voice: {voice_code} ({voice_info['name']}, {voice_info['gender']}) ---")

        for text_id, text in test_texts[:1]:  # Just one text per voice for demo
            print(f"  Generating: {text_id}...")
            try:
                output_path = engine.generate(
                    text=text,
                    voice=voice_code,
                    speed=1.0
                )

                # Copy to runs folder
                dest_path = RUNS_DIR / f"{voice_code}_{text_id}.wav"
                shutil.copy(output_path, dest_path)

                results.append({
                    "voice": voice_code,
                    "name": voice_info["name"],
                    "text_id": text_id,
                    "output": str(dest_path),
                    "size": dest_path.stat().st_size,
                    "status": "success"
                })
                print(f"    ✓ Saved: {dest_path.name} ({dest_path.stat().st_size:,} bytes)")

            except Exception as e:
                results.append({
                    "voice": voice_code,
                    "text_id": text_id,
                    "status": "failed",
                    "error": str(e)
                })
                print(f"    ✗ Failed: {e}")

    # Generate comparison with all voices saying same thing
    print("\n--- Generating voice comparison ---")
    comparison_text = "Hello, my name is Emma. How do you do?"
    for voice_code in BRITISH_VOICES.keys():
        name = BRITISH_VOICES[voice_code]["name"]
        text = f"Hello, my name is {name}. How do you do?"
        try:
            output_path = engine.generate(text=text, voice=voice_code, speed=1.0)
            dest_path = RUNS_DIR / f"compare_{voice_code}.wav"
            shutil.copy(output_path, dest_path)
            print(f"  ✓ {voice_code}: {dest_path.name}")
        except Exception as e:
            print(f"  ✗ {voice_code}: {e}")

    # Summary
    print("\n" + "=" * 50)
    print("Kokoro Test Summary")
    print("=" * 50)
    success = sum(1 for r in results if r["status"] == "success")
    print(f"Total: {len(results)}, Success: {success}, Failed: {len(results) - success}")
    print(f"Output directory: {RUNS_DIR}")
    print("\nGenerated files:")
    for f in sorted(RUNS_DIR.glob("*.wav")):
        print(f"  - {f.name} ({f.stat().st_size:,} bytes)")

if __name__ == "__main__":
    main()
