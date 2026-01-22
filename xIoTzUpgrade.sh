#!/bin/bash

ask_proceed() {
  echo
  read -rp "👉 Press ENTER to proceed | type 'skip' to skip | type 'no' to stop: " ans

  case "$ans" in
    "" ) return 0 ;;                 # ENTER = proceed
    skip|SKIP ) return 1 ;;          # skip this step
    no|NO ) echo "🛑 Stopped by user."; exit 0 ;;
    * ) echo "⚠️ Invalid input. Press ENTER / type skip / type no"
        ask_proceed ;;
  esac
}

echo "============================================================"
echo "🛠️  XIOTZ Full Update Script Started"
echo "============================================================"


echo "🔹 COMMAND: xiotz -scriptUpdater"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -scriptUpdater
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -scriptUpdater"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -scriptUpdater
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -updateRuleSeverity"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -updateRuleSeverity
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -updateAlert"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -updateAlert
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -updateAlertRules"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -updateAlertRules
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -updateReport"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -updateReport
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -cleanupStorage"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -cleanupStorage
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -updateDASH-AI"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -updateDASH-AI
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -updateAI"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -updateAI
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi



echo "🔹 COMMAND: xiotz -status"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -status
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -license"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -license
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: chattr -i -R /etc/xiotz/license/"
if ask_proceed; then
  echo "🚀 Running..."
  chattr -i -R /etc/xiotz/license/
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -renew"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -renew
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: xiotz -license"
if ask_proceed; then
  echo "🚀 Running..."
  xiotz -license
  echo "✅ Completed"
else
  echo "⏭ Skipped"
fi


echo "🔹 COMMAND: reboot"
echo "⚠️ WARNING: This will reboot the server!"
if ask_proceed; then
  echo "🔁 Rebooting now..."
  reboot
else
  echo "⏭ Skipped reboot"
fi


echo
echo "============================================================"
echo "🎉 All done!"
echo "============================================================"
