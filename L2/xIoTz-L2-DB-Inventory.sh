#!/bin/bash

# ================================
# Source Xiotz Environment Files
# ================================
source /etc/xiotz/variables/variables.txt
source /etc/xiotz/variables/credentials.txt

echo -e "\n"

# ================================
# Header
# ================================
echo "🗂️  ========================================"
echo "📊  Xiotz Index Prefix Inventory (With Size)"
echo "⏱️  Generated: $(date)"
echo "🗂️  ========================================\n"

echo "🔌 Connecting to OpenSearch at https://127.0.0.1:$dbPort ..."
echo "🔐 Authenticating as: $coreAdminUser"
echo "📥 Fetching index list with sizes..."
sleep 1

# ================================
# Fetch + Aggregate
# ================================
INDEX_PREFIX_REPORT=$(curl -s -u "$coreAdminUser:$coreAdminPass" \
  "https://127.0.0.1:$dbPort/_cat/indices?h=index,store.size&bytes=gb" \
  --insecure | \
  sed 's/-[0-9].*$//' | \
  awk '
  {
    prefix=$1
    size=$2
    count[prefix]++
    total_size[prefix]+=size
  }
  END {
    for (p in count) {
      printf "📁  %-20s → %3d indices → %.2f GB\n", p"*", count[p], total_size[p]
    }
  }' | sort -t'→' -k2 -nr
)

# ================================
# Display on Screen
# ================================
echo -e "\n📦 Index Prefix Summary:"
echo "----------------------------------------"
echo "$INDEX_PREFIX_REPORT"
echo "----------------------------------------"
echo "✅ Report completed successfully."
echo -e "\n"
