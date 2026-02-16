#!/bin/bash
# Post-start command: Runs every time the container starts

set -e

echo "Running post-start tasks..."

echo ""
echo "Python: $(which python) ($(python --version))"

echo ""
echo "Container ready!"
