#!/bin/bash
# Post-create command: Runs once after container is created

set -e

echo "Running post-create setup..."

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -
export PATH="$HOME/.local/bin:$PATH"

# Ensure we're in the workspace
cd /workspace


# Configure Poetry to create the venv inside the project at .venv/
poetry config virtualenvs.in-project true

poetry install --with dev

# Auto-activate the in-project venv in every new terminal session
VENV_ACTIVATE="/workspace/.venv/bin/activate"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if ! grep -q "source $VENV_ACTIVATE" "$RC"; then
            {
                echo ""
                echo "# Auto-activate Poetry venv"
                echo "[ -f $VENV_ACTIVATE ] && source $VENV_ACTIVATE"
            } >> "$RC"
        fi
    fi
done

# Install pre-commit hooks if .pre-commit-config.yaml exists
if [ -f ".pre-commit-config.yaml" ]; then
    echo ""
    echo "Installing pre-commit hooks..."
    poetry run pre-commit install || echo "Warning: Failed to install pre-commit hooks (continuing anyway)"
fi

echo ""
echo "Post-create setup complete!"
echo "Venv : /workspace/.venv"
echo "Python: $(/workspace/.venv/bin/python --version)"
