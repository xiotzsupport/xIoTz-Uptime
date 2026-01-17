#!/bin/bash
# xIoTz-Ubuntu-2X.04-Update.sh
# Ubuntu 22.04 / 24.04 - Periodic patching check + patching + cron + logging

set -euo pipefail

# ----------------------------
# Must run as root
# ----------------------------
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
LINE="============================================================"

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
# Ensure folder exists
# ----------------------------
mkdir -p "$DIR"
chmod 755 "$DIR"

# ----------------------------
# Log to console + file (IMPORTANT)
# ----------------------------
exec > >(tee -a "$LOGFILE") 2>&1

# ----------------------------
# L1 Friendly Header
# ----------------------------
echo
echo "$LINE"
echo "${PATCH_ICON} xIoTz Ubuntu Update & Patch Script"
echo "$LINE"
echo
echo "${RUN_ICON} Run Time            : $(date)"
echo "${HOST_ICON} Host                : $(hostname)"
echo "${OS_ICON} OS                  : $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "${FILE_ICON} Script Location     : $SELF_PATH"
echo "${FOLDER_ICON} Log Folder          : $DIR"
echo "${LOG_ICON} Today Log File       : $LOGFILE"
echo
echo "${CRON_ICON} Schedule            : Every 6 hours (4 times/day)"
echo "${TIMER_ICON} Expected Run Times  : 00:00 , 06:00 , 12:00 , 18:00"
echo
echo "${INFO_ICON} What this script does:"
echo "${INFO_ICON}  1) Checks unattended-upgrades config"
echo "${INFO_ICON}  2) Runs apt update + upgrade + cleanup"
echo "${INFO_ICON}  3) Installs cron (no duplicates)"
echo
echo "${INFO_ICON} For L1 Support:"
echo "${INFO_ICON}  - To view logs: tail -n 200 $LOGFILE"
echo "${INFO_ICON}  - To verify cron: sudo crontab -l"
echo "${INFO_ICON}  - To run manually: sudo $SELF_PATH"
echo
echo "$LINE"
echo

# Turn on debug AFTER header (so header is clean)
set -x

ok=1

# ----------------------------
# [1] Check 20auto-upgrades
# ----------------------------
echo
echo "${CHECK_ICON} [1] Checking ${FILE_ICON} $AUTO ..."
echo "$LINE"
echo

if [[ -f "$AUTO" ]]; then
  upd=$(grep -oP 'APT::Periodic::Update-Package-Lists\s*"\K[0-9]+' "$AUTO" 2>/dev/null || echo 0)
  uug=$(grep -oP 'APT::Periodic::Unattended-Upgrade\s*"\K[0-9]+' "$AUTO" 2>/dev/null || echo 0)

  if [[ "$upd" == "1" && "$uug" == "1" ]]; then
    echo "${OK_ICON} Periodic updates are ENABLED"
    echo "${INFO_ICON} Update-Package-Lists=$upd | Unattended-Upgrade=$uug"
  else
    echo "${BAD_ICON} Periodic updates are NOT enabled correctly"
    echo "${INFO_ICON} Update-Package-Lists=$upd | Unattended-Upgrade=$uug"
    ok=0
  fi
else
  echo "${BAD_ICON} Missing file: $AUTO"
  ok=0
fi

# ----------------------------
# [2] Check 50unattended-upgrades
# ----------------------------
echo
echo "${CHECK_ICON} [2] Checking ${FILE_ICON} $CONF for security origin ..."
echo "$LINE"
echo

if [[ -f "$CONF" ]]; then
  codename=$(. /etc/os-release; echo "$VERSION_CODENAME")
  echo "${INFO_ICON} Detected Ubuntu codename: $codename"

  if grep -Eq "${codename}-security" "$CONF"; then
    echo "${OK_ICON} Security origin found: ${codename}-security"
  else
    echo "${BAD_ICON} Security origin NOT found: ${codename}-security"
    ok=0
  fi
else
  echo "${BAD_ICON} Missing file: $CONF"
  ok=0
fi

# ----------------------------
# [3] Check systemd timers
# ----------------------------
echo
echo "${TIMER_ICON} [3] Checking apt timers ..."
echo "$LINE"
echo

timers=$(systemctl list-timers --all 2>/dev/null | grep -E 'apt-daily\.timer|apt-daily-upgrade\.timer' || true)
if [[ -n "$timers" ]]; then
  echo "${OK_ICON} apt timers are present"
  echo "${INFO_ICON} Timers:"
  echo "$timers"
else
  echo "${WARN_ICON} apt timers not found (cron will still run this script)"
fi

# ----------------------------
# [4] Run patching
# ----------------------------
echo
echo "${RUN_ICON} [4] Starting patching process now..."
echo "${INFO_ICON} This will run: apt-get update + upgrade + autoremove + autoclean"
echo "$LINE"
echo

export DEBIAN_FRONTEND=noninteractive

if command -v flock >/dev/null 2>&1; then
  echo "${INFO_ICON} Using flock (wait up to 600s) to avoid apt lock conflicts"
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
echo "${OK_ICON} Patching completed successfully"
echo

# ----------------------------
# [5] Install cron (every 6 hours) - no duplicate
# ----------------------------
echo
echo "${CRON_ICON} [5] Ensuring cron job exists (every 6 hours)..."
echo "$LINE"
echo

CRON_LINE="0 */6 * * * $SELF_PATH >> $DIR/xIoTz-Update-\$(date +\\%d-\\%m-\\%y).log 2>&1"

if crontab -l 2>/dev/null | grep -Fqx "$CRON_LINE"; then
  echo "${OK_ICON} Cron already exists (no duplicate added)"
else
  ( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -
  echo "${OK_ICON} Cron installed successfully"
fi

echo
echo "${INFO_ICON} Cron Entry:"
echo "${CRON_ICON} $CRON_LINE"
echo

# ----------------------------
# Final Result
# ----------------------------
echo "$LINE"
if [[ "$ok" -eq 1 ]]; then
  echo "${DONE_ICON} FINAL RESULT: ${OK_ICON} WORKING"
else
  echo "🚨 FINAL RESULT: ${BAD_ICON} NOT WORKING (check config items above)"
fi
echo "${LOG_ICON} Log File: $LOGFILE"
echo "$LINE"
echo

set +x
