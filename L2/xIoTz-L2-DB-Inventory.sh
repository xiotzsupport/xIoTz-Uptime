#!/bin/bash

source /etc/xiotz/variables/variables.txt
source /etc/xiotz/variables/credentials.txt

echo -e "\n"

echo "🗂️  ========================================"
echo "📊  Xiotz Index Prefix Inventory (With Size)"
echo "⏱️  Generated: $(date)"
echo "🗂️  ========================================\n"

echo "🔌 Connecting to OpenSearch at https://127.0.0.1:$dbPort ..."
echo "🔐 Authenticating as: $coreAdminUser"
echo "📥 Fetching index list with sizes..."
sleep 1

INDEX_PREFIX_REPORT=$(curl -s -u "$coreAdminUser:$coreAdminPass" \
  "https://127.0.0.1:$dbPort/_cat/indices?h=index,store.size&bytes=b" \
  --insecure | \
  sed 's/-[0-9].*$//' | \
  awk '
  {
    prefix=$1
    size_bytes=$2 + 0   # force numeric
    count[prefix]++
    total_bytes[prefix]+=size_bytes
  }
  END {
    for (p in count) {
      gb = total_bytes[p] / (1024*1024*1024)
      printf "%d|📁  %-45s → %3d indices → %.2f GB\n", count[p], p"*", count[p], gb
    }
  }' | sort -t'|' -k1 -nr | cut -d'|' -f2-
)

echo -e "\n📦 Index Prefix Summary:"
echo "----------------------------------------"
echo "$INDEX_PREFIX_REPORT"
echo "----------------------------------------"
echo "✅ Report completed successfully."
echo -e "\n"
