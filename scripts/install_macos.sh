#!/usr/bin/env bash
set -euo pipefail

# MimikaStudio macOS Installation Script
# Installs all dependencies and sets up the project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/backend"
FLUTTER_DIR="$ROOT_DIR/flutter_app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== MimikaStudio macOS Installation ===${NC}"

# ============== Check Prerequisites ==============

echo -e "\n${BLUE}Checking prerequisites...${NC}"

# Check Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found. Installing...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
echo -e "${GREEN}✓ Homebrew${NC}"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Python3 not found. Installing via Homebrew...${NC}"
    brew install python@3.11
fi
PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ $PYTHON_VERSION${NC}"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter not found. Please install Flutter manually:${NC}"
    echo "  https://docs.flutter.dev/get-started/install/macos"
    echo "  Or: brew install --cask flutter"
    exit 1
fi
FLUTTER_VERSION=$(flutter --version | head -1)
echo -e "${GREEN}✓ $FLUTTER_VERSION${NC}"

# ============== Install System Dependencies ==============

echo -e "\n${BLUE}Installing system dependencies...${NC}"

# espeak-ng (required for Kokoro TTS)
if ! command -v espeak-ng &> /dev/null; then
    echo "Installing espeak-ng..."
    brew install espeak-ng
fi
echo -e "${GREEN}✓ espeak-ng${NC}"

# ============== Setup Python Virtual Environment ==============

echo -e "\n${BLUE}Setting up Python virtual environment...${NC}"

cd "$BACKEND_DIR"

if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip

echo "Installing Python dependencies..."
pip install -r requirements.txt

echo -e "${GREEN}✓ Python environment ready${NC}"

# ============== Initialize Database ==============

echo -e "\n${BLUE}Initializing database...${NC}"

python database.py

echo -e "${GREEN}✓ Database initialized and seeded${NC}"

# ============== Setup Flutter ==============

echo -e "\n${BLUE}Setting up Flutter...${NC}"

cd "$FLUTTER_DIR"

echo "Getting Flutter dependencies..."
flutter pub get

echo "Enabling macOS desktop support..."
flutter config --enable-macos-desktop

echo -e "${GREEN}✓ Flutter ready${NC}"

# ============== Download ML Models (Optional) ==============

echo -e "\n${YELLOW}ML models will be downloaded on first use (~3GB total).${NC}"
echo -e "To pre-download now, run: ${BLUE}./bin/tssctl models download${NC}"

# ============== Done ==============

echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "To start MimikaStudio:"
echo -e "  ${BLUE}cd $ROOT_DIR${NC}"
echo -e "  ${BLUE}./bin/tssctl up${NC}"
echo ""
echo "Or start backend only:"
echo -e "  ${BLUE}./bin/tssctl backend start${NC}"
echo ""
echo "API will be available at: http://localhost:8000"
echo "API docs at: http://localhost:8000/docs"
