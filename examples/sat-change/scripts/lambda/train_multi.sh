#!/bin/bash
# Train multiple experiments sequentially with auto-sync and termination
#
# Usage:
#   ./scripts/lambda/train_multi.sh                          # Default: dino_sat then baseline_unet
#   ./scripts/lambda/train_multi.sh exp1 exp2 exp3           # Custom experiments
#   ./scripts/lambda/train_multi.sh --no-terminate exp1 exp2 # Keep instance running
#
# After all experiments:
#   - Logs/checkpoints are synced to GCS after EACH experiment
#   - On all success: instance terminates (unless --no-terminate)
#   - On any failure: stops and keeps instance for debugging

set -e

# Project directory
PROJECT_DIR="${PROJECT_DIR:-$HOME/sat-change}"

# Load .env file if it exists
if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
fi

# Configuration
LAMBDA_API_KEY="${LAMBDA_API_KEY:?ERROR: LAMBDA_API_KEY not set}"
GCS_BUCKET="${GCS_BUCKET:-satchange-data}"
API_BASE="https://cloud.lambdalabs.com/api/v1"

# Parse flags and experiments
AUTO_TERMINATE=true
EXPERIMENTS=()

for arg in "$@"; do
    case $arg in
        --no-terminate)
            AUTO_TERMINATE=false
            ;;
        *)
            EXPERIMENTS+=("$arg")
            ;;
    esac
done

# Default experiments if none specified
if [[ ${#EXPERIMENTS[@]} -eq 0 ]]; then
    EXPERIMENTS=("dino_sat" "baseline_unet")
fi

echo "=================================================="
echo "SatChange Multi-Experiment Training"
echo "=================================================="
echo "GCS Bucket: gs://$GCS_BUCKET"
echo "Auto-terminate on success: $AUTO_TERMINATE"
echo "Experiments to run: ${EXPERIMENTS[*]}"
echo "Total experiments: ${#EXPERIMENTS[@]}"
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
    echo "Syncing logs to GCS..."
    if [[ -d "logs" ]]; then
        gsutil -m rsync -r logs/ "gs://$GCS_BUCKET/logs/" && \
            echo "Logs synced to gs://$GCS_BUCKET/logs/" || \
            echo "WARNING: Failed to sync logs"
    fi
    if [[ -d "checkpoints" ]]; then
        gsutil -m rsync -r checkpoints/ "gs://$GCS_BUCKET/checkpoints/" && \
            echo "Checkpoints synced" || \
            echo "WARNING: Failed to sync checkpoints"
    fi
}

# Function to get current instance ID
get_instance_id() {
    MY_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)
    if [[ ! "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        MY_IP=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null)
    fi
    if [[ ! "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo ""
        return 1
    fi

    curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
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
" 2>/dev/null
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
        return 1
    fi

    echo "Instance ID: $INSTANCE_ID"
    curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        -H "Content-Type: application/json" \
        -X POST "$API_BASE/instance-operations/terminate" \
        -d "{\"instance_ids\": [\"$INSTANCE_ID\"]}"
    echo ""
}

# Track results
FAILED_EXPERIMENTS=()
SUCCESSFUL_EXPERIMENTS=()

# Run each experiment
for i in "${!EXPERIMENTS[@]}"; do
    EXP="${EXPERIMENTS[$i]}"
    EXP_NUM=$((i + 1))

    echo ""
    echo "=================================================="
    echo "[$EXP_NUM/${#EXPERIMENTS[@]}] Starting experiment: $EXP"
    echo "=================================================="
    echo ""

    # Run training
    if python -u scripts/train.py "experiment=$EXP"; then
        echo ""
        echo "[$EXP_NUM/${#EXPERIMENTS[@]}] Experiment $EXP completed successfully!"
        SUCCESSFUL_EXPERIMENTS+=("$EXP")

        # Sync after each successful experiment
        sync_logs
    else
        EXIT_CODE=$?
        echo ""
        echo "[$EXP_NUM/${#EXPERIMENTS[@]}] Experiment $EXP FAILED with exit code $EXIT_CODE"
        FAILED_EXPERIMENTS+=("$EXP")

        # Sync logs even on failure
        sync_logs

        # Stop on first failure
        echo ""
        echo "=================================================="
        echo "STOPPING: Experiment failed"
        echo "=================================================="
        echo "Successful: ${SUCCESSFUL_EXPERIMENTS[*]:-none}"
        echo "Failed: ${FAILED_EXPERIMENTS[*]}"
        echo "Remaining: ${EXPERIMENTS[*]:$((i+1))}"
        echo ""
        echo "Instance will remain running for debugging."
        echo "To terminate manually: make lambda-terminate"
        exit $EXIT_CODE
    fi
done

# All experiments completed successfully
echo ""
echo "=================================================="
echo "ALL EXPERIMENTS COMPLETED SUCCESSFULLY!"
echo "=================================================="
echo "Completed: ${SUCCESSFUL_EXPERIMENTS[*]}"
echo ""

if [[ "$AUTO_TERMINATE" == "true" ]]; then
    echo "Waiting 30 seconds before termination (Ctrl+C to cancel)..."
    sleep 30
    terminate_self
else
    echo "Auto-terminate disabled. Instance will remain running."
fi
