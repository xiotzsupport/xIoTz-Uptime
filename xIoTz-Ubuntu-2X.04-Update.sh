#!/bin/bash
# xIoTz-Ubuntu-2X.04-Update.sh
# Ubuntu 22.04 / 24.04 - Periodic patching check + logging + cron (every 6 hours)

set -x
set -euo pipefail

# Must run as root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "❌ ERROR: This script must be run as root."
  echo "ℹ️  Run: sudo $0"
  exit 1
fi

# ----------------------------
# Icons / UI
# ----------------------------
OK_ICON="✅"
WARN_ICON="⚠️"
BAD_ICON="❌"
INFO_ICON="ℹ️"
CHECK_ICON="🔎"
TIMER_ICON="⏱️"
FILE_ICON="📄"
RUN_ICON="🚀"
FOLDER_ICON="📁"
CRON_ICON="🕒"
PATCH_ICON="🛡️"
HOST_ICON="🏠"
OS_ICON="💿"
LOG_ICON="📝"
DONE_ICON="🎉"
LINE="=============================================="

# ----------------------------
# Paths / Names
# ----------------------------
DIR="/opt/xIoTz"
DATE_STR="$(date +%d-%m-%y)"
LOGFILE="${DIR}/xIoTz-Update-${DATE_STR}.log"

AUTO="/etc/apt/apt.conf.d/20auto-upgrades"
CONF="/etc/apt/apt.conf.d/50unattended-upgrades"

SELF_PATH="$(readlink -f "$0")"
SELF_NAME="$(basename "$SELF_PATH")"

# ----------------------------
# Ensure folder exists + log
# ----------------------------
mkdir -p "$DIR"
chmod 755 "$DIR"

exec >>"$LOGFILE" 2>&1

echo "$LINE"
echo "${PATCH_ICON} xIoTz Ubuntu Update Script"
echo "$LINE"
echo "${RUN_ICON} Run Time: $(date)"
echo "${HOST_ICON} Host:     $(hostname)"
echo "${OS_ICON} OS:       $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "${FOLDER_ICON} Folder:   $DIR"
echo "${LOG_ICON} Log:      $LOGFILE"
echo "${FILE_ICON} Script:   $SELF_PATH"
echo "$LINE"
echo

ok=1

# ----------------------------
# [1] Check 20auto-upgrades
# ----------------------------
echo "${CHECK_ICON} [1] Checking ${FILE_ICON} $AUTO ..."
if [[ -f "$AUTO" ]]; then
  upd=$(grep -oP 'APT::Periodic::Update-Package-Lists\s*"\K[0-9]+' "$AUTO" 2>/dev/null || echo 0)
  uug=$(grep -oP 'APT::Periodic::Unattended-Upgrade\s*"\K[0-9]+' "$AUTO" 2>/dev/null || echo 0)

  if [[ "$upd" == "1" && "$uug" == "1" ]]; then
    echo "${OK_ICON} OK: Periodic updates enabled"
    echo "${INFO_ICON} Update-Package-Lists=$upd, Unattended-Upgrade=$uug"
  else
    echo "${BAD_ICON} NOT OK: Periodic updates NOT enabled"
    echo "${INFO_ICON} Current: Update-Package-Lists=$upd, Unattended-Upgrade=$uug"
    ok=0
  fi
else
  echo "${BAD_ICON} NOT OK: Missing file: $AUTO"
  ok=0
fi

echo

# ----------------------------
# [2] Check 50unattended-upgrades
# ----------------------------
echo "${CHECK_ICON} [2] Checking ${FILE_ICON} $CONF for security origin ..."
if [[ -f "$CONF" ]]; then
  codename=$(. /etc/os-release; echo "$VERSION_CODENAME")
  echo "${INFO_ICON} Detected codename: $codename"

  if grep -Eq "${codename}-security" "$CONF"; then
    echo "${OK_ICON} OK: Found ${codename}-security in unattended-upgrades config"
  else
    echo "${BAD_ICON} NOT OK: Missing ${codename}-security in $CONF"
    ok=0
  fi
else
  echo "${BAD_ICON} NOT OK: Missing file: $CONF"
  ok=0
fi

echo

# ----------------------------
# [3] Check systemd timers
# ----------------------------
echo "${TIMER_ICON} [3] Checking systemd apt timers ..."
timers=$(systemctl list-timers --all 2>/dev/null | grep -E 'apt-daily\.timer|apt-daily-upgrade\.timer' || true)
if [[ -n "$timers" ]]; then
  echo "${OK_ICON} OK: apt timers found:"
  echo "$timers"
else
  echo "${BAD_ICON} NOT OK: apt timers not found"
  ok=0
fi

echo

# ----------------------------
# [4] Check unattended-upgrades service
# ----------------------------
echo "${CHECK_ICON} [4] Checking unattended-upgrades service ..."
if systemctl is-enabled unattended-upgrades >/dev/null 2>&1; then
  echo "${OK_ICON} OK: unattended-upgrades service is enabled"
else
  echo "${WARN_ICON} WARN: unattended-upgrades service is NOT enabled"
fi

if systemctl is-active unattended-upgrades >/dev/null 2>&1; then
  echo "${OK_ICON} OK: unattended-upgrades service is active"
else
  echo "${INFO_ICON} INFO: unattended-upgrades not active right now (normal — runs on schedule)"
fi

echo

# ----------------------------
# [5] Show unattended-upgrades log tail
# ----------------------------
echo "${FILE_ICON} [5] Last unattended-upgrades log lines ..."
if [[ -f /var/log/unattended-upgrades/unattended-upgrades.log ]]; then
  tail -n 25 /var/log/unattended-upgrades/unattended-upgrades.log
else
  echo "${WARN_ICON} WARN: /var/log/unattended-upgrades/unattended-upgrades.log not found yet"
fi

echo
echo "$LINE"

# ----------------------------
# [6] Run upgrade (safe noninteractive)
# ----------------------------
echo "${RUN_ICON} [6] Running patching (apt-get update/upgrade) ..."
export DEBIAN_FRONTEND=noninteractive

# Wait for dpkg lock (up to 10 minutes)
if command -v flock >/dev/null 2>&1; then
  echo "${INFO_ICON} Using flock to avoid apt lock conflicts (wait up to 600s)"
  flock -w 600 /var/lib/dpkg/lock-frontend bash -c '
    apt-get update
    apt-get -y upgrade
    apt-get -y autoremove --purge
    apt-get -y autoclean
  '
else
  echo "${WARN_ICON} flock not found. Running apt normally (may fail if locked)."
  apt-get update
  apt-get -y upgrade
  apt-get -y autoremove --purge
  apt-get -y autoclean
fi

echo "${OK_ICON} OK: Patch commands completed"
echo "$LINE"
echo

# ----------------------------
# [7] Install cron (every 6 hours)
# ----------------------------
echo "${CRON_ICON} [7] Installing cron job (every 6 hours) ..."
CRON_LINE="0 */6 * * * $SELF_PATH >> $DIR/xIoTz-Update-\$(date +\\%d-\\%m-\\%y).log 2>&1"

( crontab -l 2>/dev/null | grep -vF "$SELF_PATH" ; echo "$CRON_LINE" ) | crontab -

echo "${OK_ICON} OK: Cron installed:"
echo "${INFO_ICON} $CRON_LINE"
echo

# ----------------------------
# Final result
# ----------------------------
if [[ "$ok" -eq 1 ]]; then
  echo "${DONE_ICON} RESULT: ${OK_ICON} WORKING (config checks passed)"
else
  echo "🚨 RESULT: ${BAD_ICON} NOT WORKING (one or more checks failed)"
fi

set +x

echo "$LINE"
echo "${INFO_ICON} Log saved to: $LOGFILE"
echo "$LINE"
