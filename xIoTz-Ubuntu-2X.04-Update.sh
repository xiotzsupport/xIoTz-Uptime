#!/bin/bash
# xIoTz-Ubuntu-2X.04-Update.sh
# Ubuntu 22.04 / 24.04 - Periodic patching check + logging + cron (every 6 hours)

set -euo pipefail
set -x

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
SEP_ICON="➖"
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

# Log to console + file
exec > >(tee -a "$LOGFILE") 2>&1

echo
echo "$LINE"
echo "${PATCH_ICON} xIoTz Ubuntu Update Script"
echo "$LINE"
echo
echo "${RUN_ICON} Run Time : $(date)"
echo "${HOST_ICON} Host     : $(hostname)"
echo "${OS_ICON} OS       : $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "${FOLDER_ICON} Folder   : $DIR"
echo "${LOG_ICON} Log File : $LOGFILE"
echo "${FILE_ICON} Script   : $SELF_PATH"
echo
echo "$LINE"
echo

ok=1

# ----------------------------
# [1] Check 20auto-upgrades
# ----------------------------
echo
echo "${CHECK_ICON} [1] Checking ${FILE_ICON} $AUTO ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

if [[ -f "$AUTO" ]]; then
  upd=$(grep -oP 'APT::Periodic::Update-Package-Lists\s*"\K[0-9]+' "$AUTO" 2>/dev/null || echo 0)
  uug=$(grep -oP 'APT::Periodic::Unattended-Upgrade\s*"\K[0-9]+' "$AUTO" 2>/dev/null || echo 0)

  if [[ "$upd" == "1" && "$uug" == "1" ]]; then
    echo "${OK_ICON} OK: Periodic updates enabled"
    echo "${INFO_ICON} Values: Update-Package-Lists=$upd | Unattended-Upgrade=$uug"
  else
    echo "${BAD_ICON} NOT OK: Periodic updates NOT enabled"
    echo "${INFO_ICON} Values: Update-Package-Lists=$upd | Unattended-Upgrade=$uug"
    ok=0
  fi
else
  echo "${BAD_ICON} NOT OK: Missing file: $AUTO"
  ok=0
fi

echo
echo "$LINE"
echo

# ----------------------------
# [2] Check 50unattended-upgrades
# ----------------------------
echo
echo "${CHECK_ICON} [2] Checking ${FILE_ICON} $CONF for security origin ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

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
echo "$LINE"
echo

# ----------------------------
# [3] Check systemd timers
# ----------------------------
echo
echo "${TIMER_ICON} [3] Checking systemd apt timers ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

timers=$(systemctl list-timers --all 2>/dev/null | grep -E 'apt-daily\.timer|apt-daily-upgrade\.timer' || true)
if [[ -n "$timers" ]]; then
  echo "${OK_ICON} OK: apt timers found"
  echo "${INFO_ICON} Timers output:"
  echo "$timers"
else
  echo "${BAD_ICON} NOT OK: apt timers not found"
  ok=0
fi

echo
echo "$LINE"
echo

# ----------------------------
# [4] Check unattended-upgrades service
# ----------------------------
echo
echo "${CHECK_ICON} [4] Checking unattended-upgrades service ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

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
echo "$LINE"
echo

# ----------------------------
# [5] Show unattended-upgrades log tail
# ----------------------------
echo
echo "${FILE_ICON} [5] Last unattended-upgrades log lines ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

if [[ -f /var/log/unattended-upgrades/unattended-upgrades.log ]]; then
  echo "${INFO_ICON} Showing last 25 lines from: /var/log/unattended-upgrades/unattended-upgrades.log"
  tail -n 25 /var/log/unattended-upgrades/unattended-upgrades.log
else
  echo "${WARN_ICON} WARN: /var/log/unattended-upgrades/unattended-upgrades.log not found yet"
fi

echo
echo "$LINE"
echo

# ----------------------------
# [6] Run upgrade (safe noninteractive)
# ----------------------------
echo
echo "${RUN_ICON} [6] Running patching (apt-get update/upgrade) ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

export DEBIAN_FRONTEND=noninteractive

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

echo
echo "${OK_ICON} OK: Patch commands completed"
echo
echo "$LINE"
echo

# ----------------------------
# [7] Install cron (every 6 hours) - no duplicate
# ----------------------------
echo
echo "${CRON_ICON} [7] Installing cron job (every 6 hours) ..."
echo "${SEP_ICON} ----------------------------------------------"
echo

CRON_LINE="0 */6 * * * $SELF_PATH >> $DIR/xIoTz-Update-\$(date +\\%d-\\%m-\\%y).log 2>&1"

if crontab -l 2>/dev/null | grep -Fqx "$CRON_LINE"; then
  echo "${INFO_ICON} Cron already exists ${OK_ICON}"
else
  ( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -
  echo "${OK_ICON} OK: Cron installed"
fi

echo
echo "${INFO_ICON} Cron entry:"
echo "${CRON_ICON} $CRON_LINE"
echo

echo "$LINE"
echo

# ----------------------------
# Final result
# ----------------------------
echo
if [[ "$ok" -eq 1 ]]; then
  echo "${DONE_ICON} RESULT: ${OK_ICON} WORKING (config checks passed)"
else
  echo "🚨 RESULT: ${BAD_ICON} NOT WORKING (one or more checks failed)"
fi

echo
echo "${LOG_ICON} Log saved to: $LOGFILE"
echo "$LINE"
echo

set +x
