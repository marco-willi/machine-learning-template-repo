#!/bin/bash
# Post-start command: Runs every time the container starts

set -e

echo "Running post-start tasks..."

# Ensure Poetry is on PATH (installed during post-create)
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "Python : $(which python) ($(python --version 2>&1))"
echo "Poetry : $(poetry --version)"
echo "Venv   : /workspace/.venv"

echo ""
echo "Container ready!"
