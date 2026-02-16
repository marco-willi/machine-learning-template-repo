#!/bin/bash
# Train model with automatic GCS sync and optional instance termination
#
# Usage:
#   ./scripts/lambda/train_and_shutdown.sh experiment=dino_sat
#   ./scripts/lambda/train_and_shutdown.sh --no-terminate experiment=dino_sat
#
# After training:
#   - Logs/checkpoints are synced to GCS
#   - On success: instance terminates (unless --no-terminate)
#   - On failure: instance stays up for debugging

set -e

# Project directory (needed to find .env)
PROJECT_DIR="${PROJECT_DIR:-$HOME/sat-change}"

# Load .env file if it exists
if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a  # automatically export all variables
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
fi

# Configuration (now .env is loaded)
LAMBDA_API_KEY="${LAMBDA_API_KEY:?ERROR: LAMBDA_API_KEY not set}"
GCS_BUCKET="${GCS_BUCKET:-satchange-data}"
API_BASE="https://cloud.lambdalabs.com/api/v1"

# Parse flags
AUTO_TERMINATE=true
TRAIN_ARGS=()

for arg in "$@"; do
    case $arg in
        --no-terminate)
            AUTO_TERMINATE=false
            ;;
        *)
            TRAIN_ARGS+=("$arg")
            ;;
    esac
done

echo "=================================================="
echo "SatChange Training with Auto-Sync"
echo "=================================================="
echo "GCS Bucket: gs://$GCS_BUCKET"
echo "Auto-terminate on success: $AUTO_TERMINATE"
echo "Training args: ${TRAIN_ARGS[*]}"
echo ""

# Ensure we're in the project directory
cd "$PROJECT_DIR"

# Activate virtual environment if it exists
if [[ -f "$HOME/.venvs/satchange/bin/activate" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.venvs/satchange/bin/activate"
fi

# Ensure gcloud is in PATH
export PATH="/opt/google-cloud-sdk/bin:$PATH"

# Function to sync logs to GCS
sync_logs() {
    echo ""
    echo "=================================================="
    echo "Syncing logs to GCS..."
    echo "=================================================="

    # Sync logs directory
    if [[ -d "logs" ]]; then
        gsutil -m rsync -r logs/ "gs://$GCS_BUCKET/logs/" && \
            echo "Logs synced to gs://$GCS_BUCKET/logs/" || \
            echo "WARNING: Failed to sync logs"
    else
        echo "No logs directory found"
    fi

    # Sync any top-level checkpoints
    if [[ -d "checkpoints" ]]; then
        gsutil -m rsync -r checkpoints/ "gs://$GCS_BUCKET/checkpoints/" && \
            echo "Checkpoints synced to gs://$GCS_BUCKET/checkpoints/" || \
            echo "WARNING: Failed to sync checkpoints"
    fi
}

# Function to get current instance ID
get_instance_id() {
    # Try to find instance ID from Lambda API by matching our IP
    # Note: Lambda Labs doesn't have AWS-style metadata endpoint, so we use external services
    MY_IP=""

    # Try ifconfig.me first (most reliable)
    MY_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)

    # Validate it looks like an IP (not HTML error page)
    if [[ ! "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Try ipinfo.io as fallback
        MY_IP=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null)
    fi

    # Final validation
    if [[ ! "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo ""
        return 1
    fi

    INSTANCE_ID=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        "$API_BASE/instances" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for inst in data.get('data', []):
        if inst.get('ip') == '$MY_IP':
            print(inst['id'])
            break
except:
    pass
" 2>/dev/null)

    echo "$INSTANCE_ID"
}

# Function to terminate this instance
terminate_self() {
    echo ""
    echo "=================================================="
    echo "Terminating instance..."
    echo "=================================================="

    INSTANCE_ID=$(get_instance_id)

    if [[ -z "$INSTANCE_ID" ]]; then
        echo "ERROR: Could not determine instance ID"
        echo "Instance will not be terminated automatically"
        return 1
    fi

    echo "Instance ID: $INSTANCE_ID"

    RESPONSE=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        -H "Content-Type: application/json" \
        -X POST "$API_BASE/instance-operations/terminate" \
        -d "{\"instance_ids\": [\"$INSTANCE_ID\"]}")

    echo "Termination response: $RESPONSE"
}

# Run training
echo "Starting training..."
echo "Command: python -u scripts/train.py ${TRAIN_ARGS[*]}"
echo ""

# Use unbuffered output for real-time logging
python -u scripts/train.py "${TRAIN_ARGS[@]}"
TRAIN_EXIT_CODE=$?

echo ""
echo "=================================================="
echo "Training finished with exit code: $TRAIN_EXIT_CODE"
echo "=================================================="

# Always sync logs (even on failure)
sync_logs

# Handle exit code
if [[ $TRAIN_EXIT_CODE -eq 0 ]]; then
    echo ""
    echo "Training completed successfully!"

    if [[ "$AUTO_TERMINATE" == "true" ]]; then
        echo "Waiting 30 seconds before termination (Ctrl+C to cancel)..."
        sleep 30
        terminate_self
    else
        echo "Auto-terminate disabled. Instance will remain running."
    fi
else
    echo ""
    echo "Training FAILED with exit code $TRAIN_EXIT_CODE"
    echo "Instance will remain running for debugging."
    echo ""
    echo "To terminate manually: make lambda-terminate"
    exit $TRAIN_EXIT_CODE
fi
