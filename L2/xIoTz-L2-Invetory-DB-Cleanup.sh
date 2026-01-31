#!/bin/bash

# ==================================================
# Xiotz L2 – Interactive OpenSearch Index Cleanup
# Pattern: inventory-*-2025
# ==================================================

set -euo pipefail

# ================================
# Load Xiotz Variables
# ================================
source /etc/xiotz/variables/variables.txt
source /etc/xiotz/variables/credentials.txt

# ================================
# Validate Required Variables
# ================================
REQUIRED_VARS=(dbPort coreAdminUser coreAdminPass)

for var in "${REQUIRED_VARS[@]}"; do
  [[ -z "${!var:-}" ]] && {
    echo "❌ Missing required variable: $var"
    exit 1
  }
done

OPENSEARCH_URL="https://127.0.0.1:${dbPort}"
INDEX_PATTERN="inventory-*-2025*"

echo
echo "🗑️  ========================================"
echo "   Xiotz Interactive Index Deletion"
echo "🎯 Target Pattern: $INDEX_PATTERN"
echo "🗑️  ========================================"
echo
echo "🔌 OpenSearch: $OPENSEARCH_URL"
echo "🔐 User      : $coreAdminUser"
echo

# ================================
# List Matching Indexes
# ================================
INDEX_LIST=$(curl -s -u "$coreAdminUser:$coreAdminPass" \
  --insecure \
  "$OPENSEARCH_URL/_cat/indices/$INDEX_PATTERN?h=index")

if [[ -z "$INDEX_LIST" ]]; then
  echo "✅ No indexes found matching pattern: $INDEX_PATTERN"
  exit 0
fi

echo "📋 The following indexes will be DELETED:"
echo "----------------------------------------"
echo "$INDEX_LIST"
echo "----------------------------------------"
echo

# ================================
# Confirmation Prompt
# ================================
read -p "❗ Type 'delete' to permanently remove these indexes: " CONFIRM

if [[ "$CONFIRM" != "delete" ]]; then
  echo "❌ Confirmation failed. No indexes were deleted."
  exit 0
fi

# ================================
# Delete Indexes
# ================================
echo
echo "🧨 Deleting indexes..."
curl -s -X DELETE \
  -u "$coreAdminUser:$coreAdminPass" \
  --insecure \
  "$OPENSEARCH_URL/$INDEX_PATTERN"

echo
echo "✅ Index deletion completed successfully."
echo
