# MimikaStudio Integration Plan

## Overview

Merge MimikaStudio features into TSSUi and rename the project to MimikaStudio.

**Source Project**: `/Volumes/Lexar/mimia/MimikaStudio`
**Target Project**: `/Volumes/SSD4tb/Dropbox/DSS/artifacts/code/TSSUi` → `MimikaStudio`

## Features to Integrate

### 1. Backend - Qwen3 Engine Enhancements

**From MimikaStudio:**
- CustomVoice mode with 9 preset speakers (Ryan, Aiden, Vivian, Serena, Uncle_Fu, Dylan, Eric, Ono_Anna, Sohee)
- Advanced generation parameters (temperature, top_p, top_k, repetition_penalty, seed)
- Streaming generation endpoint
- Model registry with auto-download from HuggingFace
- Voice storage with UUID-based tracking and metadata

**Integration Approach:**
- Update `backend/tts/qwen3_engine.py` with CustomVoice generation method
- Add model registry system
- Add streaming endpoint to `main.py`
- Enhance voice storage with metadata

### 2. Backend - API Enhancements

**New/Updated Endpoints:**
- `POST /api/qwen3/generate` - Add mode (clone/custom), advanced params
- `POST /api/qwen3/generate/stream` - Streaming generation
- `GET /api/qwen3/speakers` - List preset speakers
- `GET /api/qwen3/models` - List models with metadata

### 3. Flutter UI Updates

**From MimikaStudio:**
- Mode toggle: Voice Clone ↔ Preset Voice
- Model size selector (0.6B vs 1.7B)
- Language selector with emoji flags
- Speaker carousel for CustomVoice mode
- Style instruction field
- Advanced parameters panel (collapsible)
- Audio player with generation history
- Voice library with metadata display

### 4. Test Suite

**Import 11 test files:**
- test_health.py
- test_model_registry.py
- test_voice_storage.py
- test_api_generation.py
- test_api_voices.py
- test_device_selection.py
- test_generation_smoke.py
- test_end_to_end.py
- test_streaming_endpoint.py
- test_outputs_endpoint.py
- conftest.py

### 5. CLI Tools

**Update/Rename:**
- `tssctl` → `mimikactl`
- Add: `mimika-download-voices`
- Add: `mimika-download-models`
- Add: `mimika-smoke-test`
- Add: `mimika-tests`

### 6. Project Rename

**Files to update:**
- Directory name: TSSUi → MimikaStudio
- `flutter_app/pubspec.yaml`: name, description
- `flutter_app/macos/Runner.xcodeproj`: bundle ID
- `flutter_app/lib/main.dart`: app title
- `bin/tssctl` → `bin/mimikactl`
- `README.md`: all references

## Execution Order

1. **Backend Engine** - Update qwen3_engine.py with MimikaStudio features
2. **Backend API** - Add new endpoints and parameters
3. **Import Tests** - Copy and adapt test suite
4. **Flutter UI** - Update voice_clone_screen.dart with new features
5. **CLI Tools** - Rename and add new scripts
6. **Project Rename** - Update all references
7. **Documentation** - Merge READMEs

## Files to Copy/Merge

### Direct Copy (adapt paths):
- `MimikaStudio/backend/app/models/registry.py` → `backend/models/registry.py`
- `MimikaStudio/backend/tests/*` → `backend/tests/`
- `MimikaStudio/docs/*` → `docs/`

### Merge (integrate features):
- `MimikaStudio/backend/app/engines/qwen3.py` → `backend/tts/qwen3_engine.py`
- `MimikaStudio/backend/app/api/routes.py` → `backend/main.py`
- `MimikaStudio/frontend/lib/widgets/generation_panel.dart` → `flutter_app/lib/screens/voice_clone_screen.dart`

## Preset Speakers Reference

| Speaker | Language | Character |
|---------|----------|-----------|
| Ryan | English | Dynamic male, strong rhythm |
| Aiden | English | Sunny American male |
| Vivian | Chinese | Bright, young female |
| Serena | Chinese | Warm, gentle female |
| Uncle_Fu | Chinese | Seasoned male, mellow timbre |
| Dylan | Chinese | Beijing youthful male |
| Eric | Chinese | Sichuan lively male |
| Ono_Anna | Japanese | Playful female |
| Sohee | Korean | Warm emotional female |

## Languages

- Auto (auto-detection)
- English 🇬🇧
- Chinese 🇨🇳
- Japanese 🇯🇵
- Korean 🇰🇷
