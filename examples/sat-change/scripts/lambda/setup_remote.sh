#!/bin/bash
# Setup script for SatChange on Lambda Labs instance
# Run this after SSH-ing into the instance

set -e

echo "=================================================="
echo "SatChange Lambda Labs Environment Setup"
echo "=================================================="

# Configuration
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_ACCESS_TOKEN="${GITHUB_ACCESS_TOKEN:-}"
GCS_BUCKET="${GCS_BUCKET:-satchange-data}"
PROJECT_DIR="sat-change"

# Check if already in project directory
if [[ "$(basename "$PWD")" == "$PROJECT_DIR" ]]; then
    echo "Already in $PROJECT_DIR directory"
    PROJECT_DIR="."
fi

# Step 0: Verify GPU is working
echo ""
echo "[0/6] Verifying GPU..."
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    echo "WARNING: nvidia-smi not found"
fi

# Step 1: Clone repository if not present
if [[ ! -d "$PROJECT_DIR" ]] || [[ "$PROJECT_DIR" == "." && ! -f "pyproject.toml" ]]; then
    echo ""
    echo "[1/6] Cloning repository..."

    # Use token if available
    if [[ -n "$GITHUB_ACCESS_TOKEN" && -n "$GITHUB_USER" ]]; then
        REPO_URL="https://${GITHUB_ACCESS_TOKEN}@github.com/${GITHUB_USER}/sat-change.git"
        echo "Using GitHub token for authentication..."
        git clone "$REPO_URL" "$PROJECT_DIR"
    elif [[ -n "$GITHUB_USER" ]]; then
        echo "Enter your GitHub access token:"
        read -rs TOKEN
        if [[ -n "$TOKEN" ]]; then
            git clone "https://${TOKEN}@github.com/${GITHUB_USER}/sat-change.git" "$PROJECT_DIR"
        else
            echo "ERROR: Token required for private repo"
            exit 1
        fi
    else
        echo "ERROR: GITHUB_USER not set"
        exit 1
    fi
    cd "$PROJECT_DIR"
else
    echo "[1/6] Repository already cloned"
    if [[ "$PROJECT_DIR" != "." ]]; then
        cd "$PROJECT_DIR"
    fi
fi

# Step 2: Update repository
echo ""
echo "[2/6] Updating repository..."
git pull origin main 2>/dev/null || git pull 2>/dev/null || echo "Could not pull (may be OK if fresh clone)"

# Step 3: Install Python dependencies
echo ""
echo "[3/6] Installing Python dependencies..."

# Lambda Labs Best Practice: Use venv with --system-site-packages
# This inherits the pre-installed Lambda Stack (PyTorch, CUDA, NumPy)
# and avoids version conflicts
VENV_DIR="$HOME/.venvs/satchange"

if [[ ! -d "$VENV_DIR" ]]; then
    echo "Creating virtual environment with system packages..."
    python3 -m venv --system-site-packages "$VENV_DIR"
fi

# Activate the virtual environment
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

# Add activation to bashrc for future sessions
if ! grep -q "satchange" ~/.bashrc; then
    {
        echo ""
        echo "# Activate satchange venv"
        echo "source $VENV_DIR/bin/activate"
    } >> ~/.bashrc
fi

# Upgrade pip in venv
pip install -q --upgrade pip

# Install project dependencies (uses system numpy/torch from Lambda Stack)
pip install -q -e ".[dev]"

# Step 4: Setup environment file
echo ""
echo "[4/6] Setting up .env file..."

# Priority: 1) uploaded ~/.env, 2) existing .env, 3) .env.example, 4) default
if [[ -f "$HOME/.env" ]]; then
    cp "$HOME/.env" .env
    echo "Copied .env from home directory (uploaded via lambda-sync-env)"
elif [[ -f ".env" ]]; then
    echo ".env file already exists"
elif [[ -f ".env.example" ]]; then
    cp .env.example .env
    echo "Created .env from .env.example (add your API keys!)"
else
    cat > .env << 'EOF'
# GCS Configuration (for data sync)
GCS_BUCKET=satchange-data

# Weights & Biases (optional)
# WANDB_API_KEY=your-key-here
# WANDB_PROJECT=satchange
EOF
    echo "Created default .env file (add your API keys!)"
fi

# Step 5: Install gcloud for GCS access
echo ""
echo "[5/6] Setting up Google Cloud SDK for data sync..."
if ! command -v gcloud &>/dev/null; then
    if [[ ! -d "/opt/google-cloud-sdk" ]]; then
        echo "Installing Google Cloud SDK..."
        curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz -o /tmp/gcloud.tar.gz
        sudo tar -xf /tmp/gcloud.tar.gz -C /opt
        rm /tmp/gcloud.tar.gz
        /opt/google-cloud-sdk/install.sh --quiet --path-update=true
    fi
    export PATH="/opt/google-cloud-sdk/bin:$PATH"
    echo "export PATH=\"/opt/google-cloud-sdk/bin:\$PATH\"" >> ~/.bashrc
fi

echo ""
echo "[6/6] Data sync options:"
echo "  First authenticate: gcloud auth login"
echo "  Then sync data: gsutil -m rsync -r gs://$GCS_BUCKET/data/extracted/ data/extracted/"
echo "                  gsutil -m rsync -r gs://$GCS_BUCKET/data/processed/ data/processed/"

# Verify setup
echo ""
echo "=================================================="
echo "Setup Complete!"
echo "=================================================="
echo ""
echo "Verifying installation..."
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
python3 -c "import torch; print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"

echo ""
echo "Next steps:"
echo "  1. Setup GCP: make lambda-setup-gcp"
echo "     (authenticates and sets project ID)"
echo "  2. Sync data: make lambda-sync-data"
echo "  3. Run training: make train experiment=dino_sat"
echo "  4. Or smoke test: make smoke-test"
echo ""
