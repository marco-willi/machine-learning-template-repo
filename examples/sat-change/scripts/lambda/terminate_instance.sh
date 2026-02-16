#!/bin/bash
# Terminate Lambda Labs instance

set -e

LAMBDA_API_KEY="${LAMBDA_API_KEY:?ERROR: LAMBDA_API_KEY not set}"
INSTANCE_ID="${1:-${LAMBDA_INSTANCE_ID:-}}"

API_BASE="https://cloud.lambdalabs.com/api/v1"

if [[ -z "$INSTANCE_ID" ]]; then
    # Try to get from temp file
    if [[ -f /tmp/lambda_instance_id ]]; then
        INSTANCE_ID=$(cat /tmp/lambda_instance_id)
    fi
fi

if [[ -z "$INSTANCE_ID" ]]; then
    echo "Listing running instances..."
    curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        "$API_BASE/instances" | python3 -c "
import sys, json
data = json.load(sys.stdin)
instances = data.get('data', [])
if not instances:
    print('No running instances found')
else:
    for inst in instances:
        print(f\"{inst['id']} - {inst['instance_type']['name']} - {inst['status']} - {inst.get('ip', 'no-ip')}\")
"
    echo ""
    read -rp "Enter instance ID to terminate: " INSTANCE_ID
fi

if [[ -z "$INSTANCE_ID" ]]; then
    echo "No instance ID provided"
    exit 1
fi

echo "Terminating instance: $INSTANCE_ID"
read -rp "Are you sure? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

RESPONSE=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    -H "Content-Type: application/json" \
    -X POST "$API_BASE/instance-operations/terminate" \
    -d "{\"instance_ids\": [\"$INSTANCE_ID\"]}")

echo "Response: $RESPONSE"

# Clean up temp files
rm -f /tmp/lambda_instance_id /tmp/lambda_instance_ip

echo "Instance terminated"
