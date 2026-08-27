#!/bin/bash

set -o pipefail

GAME_NAME="Palworld"
STEAM_APP_ID="2394010"
SERVER_DIR="/home/your_username/pw_server"
STEAMCMD="/usr/games/steamcmd"
STOP_SCRIPT="/home/your_username/.scripts/stop_server.sh"
START_SCRIPT="/home/your_username/.scripts/start_server.sh"
SCREEN_NAME="Palworld"
RESTART_POLL_MAX_WAIT=180
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOG_DIR="/home/your_username/logs"
LOG_FILE="palserver_update_$TIMESTAMP.log"
WEBHOOK_URL=""
IMAGE_URL=""
DISCORD_FOOTER="Server Maintenance Automation"

VERSION_FILE="$SERVER_DIR/current_version.txt"
MANIFEST_FILE="$SERVER_DIR/steamapps/appmanifest_${STEAM_APP_ID}.acf"
FULL_LOG_PATH="$LOG_DIR/$LOG_FILE"

mkdir -p "$LOG_DIR"

log() {
    echo "$1"
}

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
    elif [[ "$message" == *"Maintenance Failed"* ]]; then
        emoji="🛠️ ❌"
    fi

    if [[ "$message" == *"Maintenance Started"* ]]; then
        json_payload=$(cat <<EOF
{
    "embeds": [{
        "title": "$emoji $message",
        "color": 16711680,
        "image": { "url": "$IMAGE_URL" },
        "footer": { "text": "$DISCORD_FOOTER" }
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
        "footer": { "text": "$DISCORD_FOOTER" }
    }]
}
EOF
)
    fi

    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -H "Content-Type: application/json" -X POST -d "$json_payload" "$WEBHOOK_URL" > /dev/null 2>&1
    fi
}

{
    # Adjust the mtime value below if this doesn't run every 30 minutes.
    find "$LOG_DIR" -name "palserver_update_*.log" -type f -mtime +3 -exec rm -f {} \;
    log "$(date '+%Y-%m-%d %H:%M:%S') - Update-checker log rotation check complete."

    # Read the true installed version from disk (not just a tracking file)
    if [ -f "$MANIFEST_FILE" ]; then
        REAL_INSTALLED_VERSION=$(grep '"buildid"' "$MANIFEST_FILE" | awk -F '"' '{print $4}' | tr -d '[:space:]')
    else
        log "$(date '+%Y-%m-%d %H:%M:%S') - CRITICAL ERROR: Steam manifest missing at $MANIFEST_FILE."
        exit 1
    fi

    if [ ! -f "$VERSION_FILE" ] || [ ! -s "$VERSION_FILE" ]; then
        echo "$REAL_INSTALLED_VERSION" > "$VERSION_FILE"
    fi

    LOCAL_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
    if [ "$LOCAL_VERSION" != "$REAL_INSTALLED_VERSION" ]; then
        echo "$REAL_INSTALLED_VERSION" > "$VERSION_FILE"
        LOCAL_VERSION="$REAL_INSTALLED_VERSION"
    fi

    LATEST_VERSION=$("$STEAMCMD" +login anonymous +app_info_update 1 +app_info_print "$STEAM_APP_ID" +quit | \
        awk '/"public"/ {flag=1; next} /}/ && flag {flag=0} flag' | \
        grep '"buildid"' | awk -F '"' '{print $4}' | tr -d '[:space:]')

    if [ $? -ne 0 ] || [ -z "$LATEST_VERSION" ]; then
        log "$(date '+%Y-%m-%d %H:%M:%S') - Error: SteamCMD API query failed. Skipping check."
        exit 1
    fi

    if [ "$LATEST_VERSION" -gt "$LOCAL_VERSION" ]; then
        send_discord_message "Maintenance Started: Updates Found on SteamCMD for $GAME_NAME. Initializing patching pipeline."
        log "$(date +'%Y-%m-%d %H:%M:%S') Executing established graceful shutdown script..."
        bash "$STOP_SCRIPT"

        echo "$LATEST_VERSION" > "$VERSION_FILE"
        log "$(date +'%Y-%m-%d %H:%M:%S') Version file updated to Build ID: $LATEST_VERSION."
        log "$(date +'%Y-%m-%d %H:%M:%S') Server process terminated. Waiting for systemd auto-restart to bring it back..."

        POLL_COUNT=0
        while ! screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]" && [ $POLL_COUNT -lt $RESTART_POLL_MAX_WAIT ]; do
            sleep 2
            ((POLL_COUNT++))
        done

        if screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
            log "$(date +'%Y-%m-%d %H:%M:%S') Systemd auto-restart succeeded — server back online after $((POLL_COUNT*2))s."
        else
            log "$(date +'%Y-%m-%d %H:%M:%S') WARNING: No screen session detected after $((RESTART_POLL_MAX_WAIT*2))s. Falling back to manual start..."
            send_discord_message "Maintenance Failed: Systemd auto-restart did not bring $GAME_NAME back — falling back to manual start."
            bash "$START_SCRIPT"
            sleep 5
            if screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
                log "$(date +'%Y-%m-%d %H:%M:%S') Manual fallback start succeeded — server is back online."
            else
                log "$(date +'%Y-%m-%d %H:%M:%S') CRITICAL ERROR: Manual fallback also failed. Server is likely DOWN."
                send_discord_message "Maintenance Failed: Manual fallback start also failed. Server is likely DOWN — manual intervention required."
                exit 1
            fi
        fi
    else
        log "$(date '+%Y-%m-%d %H:%M:%S') - $GAME_NAME engine fully optimized and up to date."
    fi
} 2>&1 | tee -a "$FULL_LOG_PATH"
