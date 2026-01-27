#!/bin/bash

ask_proceed() {
  echo
  echo "👉 Press ENTER or 'y' to proceed | type 'skip' to skip | type 'no' to stop (auto-continue in 5s):"

  # Read with 5s timeout
  read -rt 5 ans

  # If timeout (no input)
  if [ $? -ne 0 ]; then
    echo "⏳ Timeout reached. Proceeding automatically..."
    return 0
  fi

  case "$ans" in
    ""|y|Y )
      return 0
      ;;
    skip|SKIP )
      return 1
      ;;
    no|NO )
      echo "🛑 Stopped by user."
      exit 0
      ;;
    * )
      echo "⚠️ Invalid input. Waiting again..."
      ask_proceed
      ;;
  esac
}

echo "============================================================"
echo "🛠️  XIOTZ Full Maintenance & Update Script Started"
echo "============================================================"

run_cmd() {
  local cmd="$1"
  echo
  echo "🔹 COMMAND: $cmd"

  if ask_proceed; then
    echo "🚀 Running..."
    eval "$cmd"
    echo "✅ Completed"
    echo "⏱ Sleeping 5 seconds..."
    sleep 5
  else
    echo "⏭ Skipped"
  fi
}

run_cmd "xiotz -xiotzSnapshot"
run_cmd "xiotz -xiotzAllFix"

run_cmd "xiotz -enableNewAlerts"
run_cmd "xiotz -updateCron"
run_cmd "xiotz -updateSlack"

run_cmd "xiotz -updateAlert"
run_cmd "xiotz -updateAlertRules"
run_cmd "xiotz -updateReport"

run_cmd "xiotz -updateDASH-AI"
run_cmd "xiotz -updateUI"
run_cmd "xiotz -updateLFM"
run_cmd "xiotz -updateILM"
run_cmd "xiotz -updateLFM"
run_cmd "xiotz -updateILM"
run_cmd "xiotz -updateLFM"
run_cmd "xiotz -enableAI"
run_cmd "xiotz -updateUI"
run_cmd "xiotz -updateCron"
run_cmd "xiotz -license"
run_cmd "xiotz -renew"
run_cmd "xiotz -updateCompliance"
run_cmd "xiotz -devUIRebranding"

run_cmd "xiotz -status"
run_cmd "xiotz -health"
run_cmd "xiotz -clusterHealth"
run_cmd "xiotz -services"
run_cmd "xiotz -cleanupStorage"
run_cmd "xiotz -cleanupIndices"

echo
echo "============================================================"
echo "🎉 All done!"
echo "============================================================"
