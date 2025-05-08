

#!/bin/bash

set -x
set -v

LOG_DIR="/var/log/xiotz"
LOG_FILE="${LOG_DIR}/health-monitor.log"
mkdir -p "$LOG_DIR"



  customerName=$(hostname)
  installationType="eCloud"
  tailscaleip=$(tailscale ip --4)
  publicip=$(curl -s https://ifconfig.me/)

  diskUsagePercent=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
  currentDiskUsage=$(df -h --output=used -BG / | awk 'NR==2 {print $1}' | tr -d 'G')
  totalDiskSpace=$(df -h --output=size -BG / | awk 'NR==2 {print $1}' | tr -d 'G')

  memoryUsagePercent=$(free | awk '/Mem:/ {printf("%.0f", $3/$2 * 100)}')
  usedMemory=$(free -m | awk '/Mem:/ {print $3}')
  totalMemory=$(free -m | awk '/Mem:/ {print $2}')

  if [ "$diskUsagePercent" -gt 75 ] || [ "$memoryUsagePercent" -gt 85 ]; then

  #WIll Drop Chache for Memeory cleanup
  sync && echo 3 | tee /proc/sys/vm/drop_caches
    
  echo "$(date) - Alert triggered: Disk ${diskUsagePercent}%, Memory ${memoryUsagePercent}%" >> "$LOG_FILE"

    slack_alert_json=$(cat <<EOF
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🚨 CRITICAL ALERT: High Resource Usage!",
        "emoji": true
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*👤 Customer:* ${customerName}\n*📦 Deployment Type:* ${installationType}"
      }
    },
    {
      "type": "divider"
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*💽 Storage Usage:* *${diskUsagePercent}%* (${currentDiskUsage}GB used / ${totalDiskSpace}GB total)"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*🧠 Memory Usage:* *${memoryUsagePercent}%* (${usedMemory}MB used / ${totalMemory}MB total)"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*🔒 Tailscale IP:* ${tailscaleip}\n*🌐 Public IP:* ${publicip}"
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "⏰ Alert triggered on $(date)"
        }
      ]
    }
  ]
}
EOF
)

    google_chat_alert_json=$(cat <<EOF
{
  "cards": [
    {
      "header": {
        "title": "🚨 CRITICAL ALERT: High Resource Usage!",
        "subtitle": "Customer - ${customerName}"
      },
      "sections": [
        {
          "widgets": [
            {
              "textParagraph": {
                "text": "*Deployment Type:* ${installationType}"
              }
            },
            {
              "textParagraph": {
                "text": "*Storage Usage:* ${diskUsagePercent}% (${currentDiskUsage}GB used / ${totalDiskSpace}GB total)"
              }
            },
            {
              "textParagraph": {
                "text": "*Memory Usage:* ${memoryUsagePercent}% (${usedMemory}MB used / ${totalMemory}MB total)"
              }
            },
            {
              "textParagraph": {
                "text": "*Tailscale IP:* ${tailscaleip}"
              }
            },
            {
              "textParagraph": {
                "text": "*Public IP:* ${publicip}"
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF
)

    curl -s -X POST -H 'Content-type: application/json' \
      --data "$slack_alert_json" \
      "https://hooks.slack.com/services/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" >> "$LOG_FILE" 2>&1

    curl -s -X POST -H 'Content-type: application/json' \
      --data "$google_chat_alert_json" \
      "https://chat.googleapis.com/v1/spaces/AAAAd_dOuQw/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=E9l7QwrxOU09tR5DWeGyNjzeZANquDvApziYCWJDnEA" >> "$LOG_FILE" 2>&1

    curl -s -X POST -H 'Content-type: application/json' \
      --data "$google_chat_alert_json" \
      "https://chat.googleapis.com/v1/spaces/AAAAhNQeYgA/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=FssTv7gY0pVTBmnUMZTwHwz4VW3toRhNMAoR0lzrYFE" >> "$LOG_FILE" 2>&1
  fi


