#!/bin/bash

# Azure Web App startup script for aiohttp server
echo "Starting NLWeb application..."

# Set Python path (include writable package dir for runtime-installed deps)
export PYTHONPATH=/home/.python-packages:/home/site/wwwroot:$PYTHONPATH

# Ensure Python output is unbuffered for immediate log visibility
export PYTHONUNBUFFERED=1

# Set pip cache directory under /home (wwwroot may be read-only with run-from-package)
export PIP_CACHE_DIR=/home/.pip-cache
mkdir -p "$PIP_CACHE_DIR"

# Navigate to app directory
cd /home/site/wwwroot

# Load environment variables from set_keys.sh if it exists
if [ -f "AskAgent/set_keys.sh" ]; then
    echo "Loading environment variables..."
    source AskAgent/set_keys.sh
fi

# Navigate to Python directory
cd AskAgent/python || exit 1

# Check Python version once
PYTHON_VERSION=$(python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
echo "Python version: $PYTHON_VERSION"

# Check if main packages are installed AND compatible
PACKAGES_OK=true
python -c "import aiohttp, openai, azure.search.documents; from openai.types.chat import ChatCompletion" 2>/dev/null || PACKAGES_OK=false

if [ "$PACKAGES_OK" = "false" ] && [ -f requirements.txt ]; then
    # Check if openai 2.x is the specific problem
    OPENAI_MAJOR=$(python -c "import openai; print(openai.__version__.split('.')[0])" 2>/dev/null)
    if [ "$OPENAI_MAJOR" = "2" ]; then
        echo "Detected incompatible openai 2.x, downgrading to 1.x..."
        pip install -q --cache-dir="$PIP_CACHE_DIR" --target="/home/.python-packages" "openai>=1.12.0,<2.0.0" --force-reinstall --no-deps
        pip install -q --cache-dir="$PIP_CACHE_DIR" --target="/home/.python-packages" -r requirements.txt --no-deps 2>/dev/null
        echo "OpenAI downgrade complete."
    else
        echo "Installing Python dependencies (this may take a moment on first run)..."
        if pip install -q --cache-dir="$PIP_CACHE_DIR" --target="/home/.python-packages" -r requirements.txt; then
            echo "Dependencies installed successfully."
        else
            echo "ERROR: Failed to install dependencies"
            exit 1
        fi
    fi
else
    echo "Dependencies already installed and compatible, skipping pip install."
fi

# Quick verification without verbose output
python -c "import aiohttp" || { echo "ERROR: aiohttp not installed"; exit 1; }

# Start the aiohttp server
echo "Starting aiohttp server on port 8000..."
python -m webserver.aiohttp_server