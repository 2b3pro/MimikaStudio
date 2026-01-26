# MimikaStudio Design Document

## Overview
Flutter-based TTS UI with Python FastAPI backend supporting:
1. **XTTS2 Voice Cloning** - Text + sample voice → cloned speech
2. **Kokoro TTS** - Predefined British voices (8 voices, default: bf_emma)
3. **Qwen3-TTS** - Voice cloning from 3 seconds of audio + premium preset speakers

## Architecture

### Backend (FastAPI, port 8000)
- Unified service handling all TTS engines
- SQLite database for metadata
- Models stored locally in `backend/models/`

### Flutter UI (macOS Desktop)
- Upper tab navigation: Voice Clone | Quick TTS | Language Study
- Connects to backend API

### Control Script (`bin/tssctl`)
- sciencectl-style service orchestration

## API Endpoints

### XTTS (Voice Cloning)
- `POST /api/xtts/generate` - Generate speech with cloned voice
- `GET /api/xtts/voices` - List available voices
- `POST /api/xtts/voices` - Upload new voice sample

### Kokoro (Predefined British Voices)
- `POST /api/kokoro/generate` - Generate with voice code
- `GET /api/kokoro/voices` - List British voices

### Qwen3-TTS
- `POST /api/qwen3/generate` - Generate speech (clone or custom mode)
- `GET /api/qwen3/voices` - List saved voice samples
- `GET /api/qwen3/speakers` - List preset speakers

### Samples
- `GET /api/samples/{engine}` - Sample texts per engine

## Database Schema

```sql
CREATE TABLE sample_texts (
    id INTEGER PRIMARY KEY,
    engine TEXT,
    text TEXT,
    language TEXT,
    category TEXT
);

CREATE TABLE kokoro_voices (
    code TEXT PRIMARY KEY,
    name TEXT,
    gender TEXT,
    quality_grade TEXT,
    is_british INTEGER DEFAULT 1
);

CREATE TABLE language_content (
    id INTEGER PRIMARY KEY,
    title TEXT,
    content_type TEXT,
    content_json TEXT
);

CREATE TABLE xtts_voices (
    id INTEGER PRIMARY KEY,
    name TEXT,
    file_path TEXT
);
```

## British Kokoro Voices
| Code | Name | Gender | Grade |
|------|------|--------|-------|
| bf_emma | Emma | F | B- |
| bf_alice | Alice | F | D |
| bf_isabella | Isabella | F | C |
| bf_lily | Lily | F | D |
| bm_daniel | Daniel | M | D |
| bm_fable | Fable | M | C |
| bm_george | George | M | C |
| bm_lewis | Lewis | M | D+ |

## Sample XTTS Voices (from xtts2-ui)
- Rogger.wav (male)
- natasha.wav (female)
- suzan_clone.wav (female)

## Dependencies
- Python 3.11+, FastAPI, TTS library, kokoro>=0.9.2, espeak-ng
- Flutter 3.x for macOS desktop
