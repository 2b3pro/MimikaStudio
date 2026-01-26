#!/usr/bin/env bash
set -euo pipefail

# Quick setup script - creates venv and installs dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/backend"

echo "=== MimikaStudio Quick Setup ==="

# Create venv if needed
if [ ! -d "$BACKEND_DIR/venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$BACKEND_DIR/venv"
fi

# Activate and install
echo "Installing Python dependencies..."
source "$BACKEND_DIR/venv/bin/activate"
pip install --upgrade pip
pip install -r "$BACKEND_DIR/requirements.txt"

# Initialize database
echo "Initializing database..."
cd "$BACKEND_DIR"
python database.py

# Flutter deps
echo "Installing Flutter dependencies..."
cd "$ROOT_DIR/flutter_app"
flutter pub get

echo ""
echo "=== Setup Complete ==="
echo "Start with: ./bin/tssctl up"
