#!/bin/bash
# Get IP of the first running Lambda Labs instance
# Useful for auto-discovery without setting LAMBDA_INSTANCE_IP manually

set -e

LAMBDA_API_KEY="${LAMBDA_API_KEY:?ERROR: LAMBDA_API_KEY not set}"
API_BASE="https://cloud.lambdalabs.com/api/v1"

# Get first running instance IP
IP=$(curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    "$API_BASE/instances" | python3 -c "
import sys, json
data = json.load(sys.stdin)
instances = data.get('data', [])
for inst in instances:
    if inst['status'] == 'active' and inst.get('ip'):
        print(inst['ip'])
        break
" 2>/dev/null)

if [[ -z "$IP" ]]; then
    echo "ERROR: No active instance found" >&2
    exit 1
fi

# Save to temp file for other commands to use
echo "$IP" > /tmp/lambda_instance_ip

echo "$IP"
