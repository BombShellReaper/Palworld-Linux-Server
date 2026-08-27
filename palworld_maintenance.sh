#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# --- Configuration ---
LOGFILE="/var/log/palworld_system_maintenance.log"
SERVICE_NAME="PalWorld.service"
WEBHOOK_URL=""
IMAGE_URL=""

send_discord_message() {
    local message="$1"
    local json_payload
    local emoji="🛠️"

    if [[ "$message" == *"No updates found"* ]]; then
        emoji="🛠️ ℹ️"
    elif [[ "$message" == *"Maintenance Complete"* ]]; then
        emoji="🛠️ 🔄"
    elif [[ "$message" == *"Updates Found"* ]]; then
        emoji="🛠️ ✅"
    fi

    if [[ "$message" == *"Maintenance Started"* ]]; then
        json_payload=$(cat <<EOF
{
    "embeds": [{
        "title": "$emoji $message",
        "color": 16711680,
        "image": { "url": "$IMAGE_URL" },
        "footer": { "text": "System Maintenance Automation" }
    }]
}
EOF
)
    else
        json_payload=$(cat <<EOF
{
    "embeds": [{
        "title": "$emoji $message",
        "color": 16711680,
        "footer": { "text": "System Maintenance Automation" }
    }]
}
EOF
)
    fi

    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -H "Content-Type: application/json" -X POST -d "$json_payload" "$WEBHOOK_URL" > /dev/null 2>&1
    fi
}

# Redirect standard output and error to both console and this run's logfile
exec > >(tee -a "$LOGFILE") 2>&1

echo "=============================================================================="
echo "$(date +'%Y-%m-%d %H:%M:%S') --- Starting Palworld Maintenance Sequence ---"

# --- 1. GRACEFULLY STOP THE PALWORLD SERVER (VIA SYSTEMD, WHICH RUNS stop_server.sh) ---
# The systemd unit's ExecStop= (Step 10) points at stop_server.sh, which
# handles the countdown, the REST API save/shutdown, and the SIGINT/
# SIGKILL fallback. Calling systemctl stop here means that logic lives in
# exactly one place instead of being duplicated across scripts.
send_discord_message "Maintenance Started: Stopping the Palworld server via systemd..."
echo "$(date +'%Y-%m-%d %H:%M:%S') Stopping $SERVICE_NAME (delegates to stop_server.sh for graceful shutdown)..."
if systemctl stop "$SERVICE_NAME"; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') $SERVICE_NAME stopped successfully."
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') WARNING: systemctl stop reported a non-zero exit for $SERVICE_NAME. Continuing anyway — check 'systemctl status $SERVICE_NAME' and stop_server.sh's own log if this is unexpected."
fi

# --- 2. CHECK AND APPLY SYSTEM UPDATES ---
echo "$(date +'%Y-%m-%d %H:%M:%S') Checking for OS updates..."
apt-get update > /dev/null

if apt-get upgrade -s 2>/dev/null | grep -q "^Inst"; then
    send_discord_message "Updates Found. Applying system patches..."
    echo "$(date +'%Y-%m-%d %H:%M:%S') Applying system upgrades..."
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" -y full-upgrade
    apt-get autoremove -y
    echo "$(date +'%Y-%m-%d %H:%M:%S') OS updates applied successfully."
else
    send_discord_message "No updates found. System is clean."
    echo "$(date +'%Y-%m-%d %H:%M:%S') No OS updates found."
fi

# --- 3. REBOOT THE MACHINE ---
send_discord_message "Maintenance Complete: Rebooting server host. Palworld will auto-update and start on launch."
echo "$(date +'%Y-%m-%d %H:%M:%S') Maintenance finished. Flushing storage buffers and executing system reboot."
echo "=============================================================================="

sync
sleep 10
reboot
