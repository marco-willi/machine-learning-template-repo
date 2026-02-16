#!/bin/bash
# Post-create command: Runs once after container is created

set -e

echo "Running post-create setup..."

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# Ensure we're in the workspace
cd /workspace

# Install project dependencies from pyproject.toml
if [ -f "pyproject.toml" ]; then
    echo "Installing dependencies from pyproject.toml..."
    pip install -e ".[dev]"
    echo "Dependencies installed"
else
    echo "Warning: pyproject.toml not found"
fi

# Install pre-commit hooks if .pre-commit-config.yaml exists
if [ -f ".pre-commit-config.yaml" ]; then
    echo ""
    echo "Installing pre-commit hooks..."
    pre-commit install || echo "Warning: Failed to install pre-commit hooks (continuing anyway)"
fi

echo ""
echo "Post-create setup complete!"
