#!/bin/bash
# Lambda Labs Instance Setup Script for SatChange Training
# Launches an instance via the Lambda Labs API

set -e

# Configuration (from environment or defaults)
LAMBDA_API_KEY="${LAMBDA_API_KEY:?ERROR: LAMBDA_API_KEY not set}"
LAMBDA_INSTANCE_TYPE="${LAMBDA_INSTANCE_TYPE:-gpu_1x_a10}"
LAMBDA_REGION="${LAMBDA_REGION:-us-west-1}"
LAMBDA_SSH_KEY_NAME="${LAMBDA_SSH_KEY_NAME:-}"

API_BASE="https://cloud.lambdalabs.com/api/v1"

echo "=================================================="
echo "Lambda Labs Instance Setup"
echo "=================================================="
echo "Instance type: $LAMBDA_INSTANCE_TYPE"
echo "Region: $LAMBDA_REGION"
echo "=================================================="

# Check for existing running instances
echo ""
echo "Checking for existing instances..."
EXISTING=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    "$API_BASE/instances" | python3 -c "
import sys, json
data = json.load(sys.stdin)
instances = data.get('data', [])
for inst in instances:
    print(f\"{inst['id']} {inst['instance_type']['name']} {inst['status']} {inst.get('ip', 'no-ip')}\")
" 2>/dev/null || echo "")

if [[ -n "$EXISTING" ]]; then
    echo "Existing instances:"
    echo "$EXISTING"
    echo ""
    read -rp "Continue creating a new instance? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Exiting."
        exit 0
    fi
fi

# List available instance types and regions
echo ""
echo "Checking availability for $LAMBDA_INSTANCE_TYPE..."
AVAILABILITY=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    "$API_BASE/instance-types" | python3 -c "
import sys, json
data = json.load(sys.stdin)
instance_type = '$LAMBDA_INSTANCE_TYPE'
for name, info in data.get('data', {}).items():
    if name == instance_type:
        regions = info.get('regions_with_capacity_available', [])
        if regions:
            print(' '.join([r['name'] for r in regions]))
        else:
            print('NONE')
        break
" 2>/dev/null || echo "ERROR")

if [[ "$AVAILABILITY" == "NONE" || "$AVAILABILITY" == "ERROR" || -z "$AVAILABILITY" ]]; then
    echo "ERROR: $LAMBDA_INSTANCE_TYPE not available in any region"
    echo ""
    echo "Available instance types:"
    curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        "$API_BASE/instance-types" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for name, info in data.get('data', {}).items():
    regions = info.get('regions_with_capacity_available', [])
    if regions:
        region_names = ', '.join([r['name'] for r in regions])
        price = info.get('instance_type', {}).get('price_cents_per_hour', 0) / 100
        print(f'  {name}: \${price:.2f}/hr - available in: {region_names}')
" 2>/dev/null
    exit 1
fi

echo "Available in regions: $AVAILABILITY"

# Use first available region if requested region not available
pattern=" $LAMBDA_REGION "
if [[ ! " $AVAILABILITY " =~ $pattern ]]; then
    LAMBDA_REGION=$(echo "$AVAILABILITY" | awk '{print $1}')
    echo "Requested region not available, using: $LAMBDA_REGION"
fi

# Get SSH key name if not set
if [[ -z "$LAMBDA_SSH_KEY_NAME" ]]; then
    echo ""
    echo "Available SSH keys:"
    curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        "$API_BASE/ssh-keys" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for key in data.get('data', []):
    print(f\"  {key['name']}\")
" 2>/dev/null
    echo ""
    read -rp "Enter SSH key name to use: " LAMBDA_SSH_KEY_NAME
fi

if [[ -z "$LAMBDA_SSH_KEY_NAME" ]]; then
    echo "ERROR: SSH key name required"
    echo "Add one at: https://cloud.lambdalabs.com/ssh-keys"
    exit 1
fi

# Launch instance
echo ""
echo "Launching $LAMBDA_INSTANCE_TYPE in $LAMBDA_REGION..."

LAUNCH_RESPONSE=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    -H "Content-Type: application/json" \
    -X POST "$API_BASE/instance-operations/launch" \
    -d "{
        \"instance_type_name\": \"$LAMBDA_INSTANCE_TYPE\",
        \"region_name\": \"$LAMBDA_REGION\",
        \"ssh_key_names\": [\"$LAMBDA_SSH_KEY_NAME\"],
        \"name\": \"satchange-train\"
    }")

# Parse response
INSTANCE_ID=$(echo "$LAUNCH_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ids = data.get('data', {}).get('instance_ids', [])
if ids:
    print(ids[0])
elif 'error' in data:
    print('ERROR: ' + data['error'].get('message', 'Unknown error'))
" 2>/dev/null)

if [[ "$INSTANCE_ID" == ERROR* ]]; then
    echo "$INSTANCE_ID"
    exit 1
fi

if [[ -z "$INSTANCE_ID" ]]; then
    echo "ERROR: Failed to launch instance"
    echo "Response: $LAUNCH_RESPONSE"
    exit 1
fi

echo "Instance launched: $INSTANCE_ID"

# Wait for instance to be ready
echo ""
echo "Waiting for instance to be ready..."
for i in {1..60}; do
    STATUS_RESPONSE=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
        "$API_BASE/instances/$INSTANCE_ID")

    STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inst = data.get('data', {})
print(inst.get('status', 'unknown'))
" 2>/dev/null)

    IP=$(echo "$STATUS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inst = data.get('data', {})
print(inst.get('ip', ''))
" 2>/dev/null)

    echo "  Status: $STATUS (attempt $i/60)"

    if [[ "$STATUS" == "active" && -n "$IP" ]]; then
        break
    fi

    sleep 10
done

if [[ "$STATUS" != "active" || -z "$IP" ]]; then
    echo "ERROR: Instance did not become ready in time"
    exit 1
fi

echo ""
echo "=================================================="
echo "Instance Ready!"
echo "=================================================="
echo "Instance ID: $INSTANCE_ID"
echo "IP Address: $IP"
echo "SSH Command: ssh ubuntu@$IP"
echo "=================================================="
echo ""
echo "Save these for later:"
echo "  export LAMBDA_INSTANCE_ID=$INSTANCE_ID"
echo "  export LAMBDA_INSTANCE_IP=$IP"
echo ""
echo "Next steps:"
echo "  1. SSH in: ssh ubuntu@$IP"
echo "  2. Run setup: make lambda-setup-remote"
echo ""

# Save instance info to file
echo "$INSTANCE_ID" > /tmp/lambda_instance_id
echo "$IP" > /tmp/lambda_instance_ip
