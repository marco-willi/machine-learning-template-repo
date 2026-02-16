#!/bin/bash
# GCP Authentication and Setup Script for Lambda Labs instances
# Run this after setup_remote.sh to configure GCP access for data sync

set -e

echo "=================================================="
echo "GCP Authentication Setup"
echo "=================================================="

# Configuration
GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"
GCS_BUCKET="${GCS_BUCKET:-satchange-data}"

# Check if gcloud is installed
if ! command -v gcloud &>/dev/null; then
    # Check if it's installed but not in PATH
    if [[ -d "/opt/google-cloud-sdk" ]]; then
        export PATH="/opt/google-cloud-sdk/bin:$PATH"
    else
        echo "ERROR: gcloud not found. Run setup_remote.sh first."
        exit 1
    fi
fi

echo "gcloud version: $(gcloud version --format='value(version)' 2>/dev/null || echo 'unknown')"

# Step 1: Authenticate with GCP
echo ""
echo "[1/3] Authenticating with GCP..."
echo "A browser window will open for authentication."
echo "(If on a headless server, use --no-browser flag)"
echo ""

# Check if already authenticated
CURRENT_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || echo "")

if [[ -n "$CURRENT_ACCOUNT" ]]; then
    echo "Already authenticated as: $CURRENT_ACCOUNT"
    read -rp "Re-authenticate? (y/N): " reauth
    if [[ "$reauth" =~ ^[Yy]$ ]]; then
        gcloud auth login --no-launch-browser
    fi
else
    # Use --no-launch-browser for headless servers (like Lambda Labs)
    gcloud auth login --no-launch-browser
fi

# Step 2: Set project ID
echo ""
echo "[2/3] Setting GCP project..."

if [[ -z "$GCP_PROJECT_ID" ]]; then
    echo "Available projects:"
    gcloud projects list --format="table(projectId,name)" 2>/dev/null || echo "  (unable to list projects)"
    echo ""
    read -rp "Enter GCP Project ID: " GCP_PROJECT_ID
fi

if [[ -z "$GCP_PROJECT_ID" ]]; then
    echo "ERROR: Project ID required"
    exit 1
fi

gcloud config set project "$GCP_PROJECT_ID"
echo "Project set to: $GCP_PROJECT_ID"

# Step 3: Verify GCS access
echo ""
echo "[3/3] Verifying GCS access..."

if gsutil ls "gs://$GCS_BUCKET/" &>/dev/null; then
    echo "Successfully accessed gs://$GCS_BUCKET/"
    echo ""
    echo "Bucket contents:"
    gsutil ls "gs://$GCS_BUCKET/" | head -10
else
    echo "WARNING: Could not access gs://$GCS_BUCKET/"
    echo "You may need to:"
    echo "  1. Check the bucket name is correct"
    echo "  2. Ensure your account has access to the bucket"
    echo "  3. Enable the Cloud Storage API for this project"
fi

# Save configuration to .env if in project directory
if [[ -f ".env" ]]; then
    # Update GCP_PROJECT_ID in .env if not already set
    if ! grep -q "^GCP_PROJECT_ID=" .env; then
        {
            echo ""
            echo "# GCP Configuration (added by setup_gcp.sh)"
            echo "GCP_PROJECT_ID=$GCP_PROJECT_ID"
        } >> .env
        echo ""
        echo "Added GCP_PROJECT_ID to .env"
    fi
fi

echo ""
echo "=================================================="
echo "GCP Setup Complete!"
echo "=================================================="
echo ""
echo "Configuration:"
echo "  Project: $GCP_PROJECT_ID"
echo "  Bucket:  gs://$GCS_BUCKET/"
echo ""
echo "Next steps:"
echo "  Sync data:    make lambda-sync-data"
echo "  Or manually:  gsutil -m rsync -r gs://$GCS_BUCKET/data/extracted/ data/extracted/"
echo ""
