#!/bin/bash

# ==================================================
# Xiotz L2 – OpenSearch Index Prefix Inventory
# With Size Aggregation + Totals (GB Only)
# ==================================================

# ================================
# Source Xiotz Environment Files
# ================================
source /etc/xiotz/variables/variables.txt
source /etc/xiotz/variables/credentials.txt

OPENSEARCH_URL="https://127.0.0.1:$dbPort"

echo
echo "🗂️  ========================================"
echo "📊  Xiotz Index Prefix Inventory (GB Only)"
echo "⏱️  Generated: $(date)"
echo "🗂️  ========================================"
echo
echo "🔌 Connecting to OpenSearch at $OPENSEARCH_URL ..."
echo "🔐 Authenticating as: $coreAdminUser"
echo "📥 Fetching index list with sizes..."
echo

RAW_OUTPUT=$(curl -s -u "$coreAdminUser:$coreAdminPass" \
  "$OPENSEARCH_URL/_cat/indices?h=index,store.size" \
  --insecure)

REPORT_AND_TOTALS=$(echo "$RAW_OUTPUT" | awk '
function to_bytes(v) {
  if (v ~ /kb$/) return substr(v,1,length(v)-2) * 1024
  if (v ~ /mb$/) return substr(v,1,length(v)-2) * 1024 * 1024
  if (v ~ /gb$/) return substr(v,1,length(v)-2) * 1024 * 1024 * 1024
  if (v ~ /b$/)  return substr(v,1,length(v)-1)
  return 0
}

NF >= 2 {
  name = $1
  size = to_bytes($2)

  # Strip rolling date suffixes only
  sub(/-[0-9]{4}\.[0-9]{2}.*/, "", name)

  count[name]++
  total[name] += size

  grand_count++
  grand_total += size
}

END {
  for (n in count) {
    gb = total[n] / (1024*1024*1024)
    printf "📁  %-50s → %3d indices → %.2f GB\n", n"*", count[n], gb
  }

  printf "__TOTALS__|%d|%.2f\n", grand_count, grand_total / (1024*1024*1024)
}')

# ================================
# Separate Totals from Report
# ================================
TOTAL_LINE=$(echo "$REPORT_AND_TOTALS" | grep '^__TOTALS__')
CLEAN_REPORT=$(echo "$REPORT_AND_TOTALS" | grep -v '^__TOTALS__')

TOTAL_INDEX_COUNT=$(echo "$TOTAL_LINE" | cut -d'|' -f2)
TOTAL_SIZE_GB=$(echo "$TOTAL_LINE" | cut -d'|' -f3)

# ================================
# Sort Report (by index count desc)
# ================================
SORTED_REPORT=$(echo "$CLEAN_REPORT" | sort -k4 -nr)

# ================================
# Output
# ================================
echo
echo "📦 Index Prefix Summary:"
echo "----------------------------------------"
echo "$SORTED_REPORT"
echo "----------------------------------------"
echo "🔢 Total Indices : $TOTAL_INDEX_COUNT"
echo "💾 Total Size    : $TOTAL_SIZE_GB GB"
echo "----------------------------------------"
echo "✅ Report completed successfully."
echo

#!/bin/bash

FILE="/etc/xiotz/scripts/health-check.sh"
EXPECTED="250"

VALUE=$(grep -E '^elasticIndicesLimit=' "$FILE" \
        | cut -d= -f2 | tr -d '"')

if [[ "$VALUE" == "$EXPECTED" ]]; then
  echo "✅ index update successful"
else
  echo "❌ fail (found: ${VALUE:-not set})"
fi
