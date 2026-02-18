#!/bin/bash

#set -x
#set -v
set +x

# ==========================================================
# Function: set_nice_and_oom
#
# Purpose:
#   Configure CPU, OOM, and I/O priority for ANY systemd service.
#
# Priority Explanation:
#
#   NICE VALUE (CPU Priority)
#     Range: -20 (highest priority) to 19 (lowest priority)
#     -20  = Maximum CPU priority
#      0   = Default priority
#     19   = Lowest priority
#
#   OOMScoreAdjust (Out-Of-Memory Protection)
#     Range: -1000 (never kill) to 1000 (kill first)
#     -1000 = Fully protected from OOM killer
#      0    = Default
#     1000  = First to be killed under memory pressure
#
#   IOSchedulingClass (Disk I/O Priority Class)
#     1 = Realtime (absolute highest, use carefully)
#     2 = Best-effort (default class)
#     3 = Idle (lowest priority)
#
#   IOSchedulingPriority (Inside Class)
#     0 = Highest priority within the class
#     7 = Lowest priority within the class
#
# Example:
#   set_nice_and_oom ssh -20 -1000 2 0
#   → Highest CPU priority
#   → Fully protected from OOM killer
#   → Best-effort I/O class
#   → Highest priority within best-effort
#
# ==========================================================

set_nice_and_oom() {

  SERVICE_NAME="$1"
  NICE_VALUE="${2:--20}"
  OOM_VALUE="${3:--1000}"
  IONICE_CLASS="${4:-2}"
  IONICE_PRIO="${5:-0}"

  if [ -z "$SERVICE_NAME" ]; then
    echo "❌ ERROR: No service name provided."
    echo "Usage: set_nice_and_oom <service_name> [nice_value] [oom_score_adj_value] [io_class] [io_priority]"
    return 1
  fi

  echo "=================================================="
  echo "🔧 CONFIGURING SERVICE PRIORITY"
  echo "Service Name        : ${SERVICE_NAME}"
  echo "CPU Nice Level      : ${NICE_VALUE}"
  echo "OOMScoreAdjust      : ${OOM_VALUE}"
  echo "IO Scheduling Class : ${IONICE_CLASS}"
  echo "IO Scheduling Prio  : ${IONICE_PRIO}"
  echo "=================================================="

  echo "📁 Creating override directory..."
  sudo mkdir -p /etc/systemd/system/${SERVICE_NAME}.service.d

  echo "📝 Writing override configuration..."
  sudo tee /etc/systemd/system/${SERVICE_NAME}.service.d/override.conf > /dev/null <<EOF
[Service]
Nice=${NICE_VALUE}
OOMScoreAdjust=${OOM_VALUE}
IOSchedulingClass=${IONICE_CLASS}
IOSchedulingPriority=${IONICE_PRIO}
EOF

  echo "🔄 Reloading systemd daemon..."
  sudo systemctl daemon-reload

  echo "🚀 Restarting service ${SERVICE_NAME}..."
  sudo systemctl restart "${SERVICE_NAME}"

  # ---------------- SAFE PID DETECTION ----------------
  echo "🔍 Fetching MainPID from systemd..."
  PID=$(systemctl show -p MainPID --value "${SERVICE_NAME}")

  if [ -z "$PID" ] || [ "$PID" -eq 0 ]; then
    echo "❌ ERROR: Could not determine active PID for ${SERVICE_NAME}"
    echo "ℹ️ Checking service status:"
    sudo systemctl status "${SERVICE_NAME}" --no-pager
    return 1
  fi
  # ----------------------------------------------------

  echo "✅ Service is running with PID: $PID"

  echo "=================================================="
  echo "📊 VERIFICATION RESULTS"
  echo "--------------------------------------------------"
  ps -o pid,ni,cls,rtprio,comm -p "$PID"
  echo "OOM Score Adjust:"
  cat /proc/$PID/oom_score_adj
  echo "=================================================="

  echo "🎯 Priority configuration applied successfully."
}

# ==========================================================
# SAMPLE USAGE EXAMPLES
# ==========================================================

# Example 1: Hardened emergency SSH access
# Maximum CPU priority + Full OOM protection + High disk priority

set_nice_and_oom ssh -20 -1000 2 0
set_nice_and_oom sshd -20 -1000 2 0

# Example 2: High priority but not fully OOM immune
# set_nice_and_oom nginx -10 -500 2 0

# Example 3: Low priority background service
# set_nice_and_oom backup-service 10 500 3 7
