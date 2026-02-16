#!/bin/bash
# List Lambda Labs instances and available instance types

set -e

LAMBDA_API_KEY="${LAMBDA_API_KEY:?ERROR: LAMBDA_API_KEY not set}"
API_BASE="https://cloud.lambdalabs.com/api/v1"

echo "=================================================="
echo "Running Instances"
echo "=================================================="
curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    "$API_BASE/instances" | python3 -c "
import sys, json
data = json.load(sys.stdin)
instances = data.get('data', [])
if not instances:
    print('No running instances')
else:
    for inst in instances:
        name = inst.get('name', 'unnamed')
        itype = inst['instance_type']['name']
        status = inst['status']
        ip = inst.get('ip', 'no-ip')
        iid = inst['id']
        print(f'{name}: {itype} | {status} | {ip} | {iid}')
"

echo ""
echo "=================================================="
echo "Available Instance Types (with capacity)"
echo "=================================================="
curl -s -H "Authorization: Bearer $LAMBDA_API_KEY" \
    "$API_BASE/instance-types" | python3 -c "
import sys, json
data = json.load(sys.stdin)
available = []
unavailable = []
for name, info in data.get('data', {}).items():
    regions = info.get('regions_with_capacity_available', [])
    itype = info.get('instance_type', {})
    price = itype.get('price_cents_per_hour', 0) / 100
    specs = itype.get('specs', {})
    gpus = specs.get('gpus', 0)

    if regions:
        region_names = ', '.join([r['name'] for r in regions])
        available.append(f'  {name}: \${price:.2f}/hr ({gpus} GPU) - {region_names}')
    else:
        unavailable.append(f'  {name}: \${price:.2f}/hr ({gpus} GPU) - NO CAPACITY')

print('AVAILABLE:')
for a in sorted(available):
    print(a)
print()
print('UNAVAILABLE:')
for u in sorted(unavailable)[:10]:
    print(u)
if len(unavailable) > 10:
    print(f'  ... and {len(unavailable) - 10} more')
"
