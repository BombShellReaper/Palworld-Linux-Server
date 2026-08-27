#!/bin/bash
set -o pipefail

INSTANCE_NAME="Palworld"
GAME_PROCESS_NAME="PalServer-Linux-Shipping"

API_IP="127.0.0.1"
API_PORT="8212"
API_USER="admin"
API_PASS="YOUR_ADMIN_PASSWORD"

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOG_DIR="/home/your_username/logs"
LOGFILE="$LOG_DIR/palserver_stop_$TIMESTAMP.log"

PID_DIR="/home/your_username/.run"
PID_FILE="$PID_DIR/palserver.pid"

mkdir -p "$LOG_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Native Python REST API sender. Uses a heredoc for the JSON body so
# messages containing an apostrophe don't break the embedded Python
# string literal.
send_api_cmd() {
    local endpoint="$1"
    local json_body="$2"
    python3 -c "
import urllib.request
import base64

ip = '$API_IP'
port = '$API_PORT'
user = '$API_USER'
password = '$API_PASS'
endpoint = '$endpoint'
body_str = \"\"\"$json_body\"\"\"

url = f'http://{ip}:{port}/v1/api/{endpoint}'
req = urllib.request.Request(url, method='POST')
req.add_header('Content-Type', 'application/json')

auth_str = f'{user}:{password}'
auth_encoded = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
req.add_header('Authorization', f'Basic {auth_encoded}')

try:
    data = body_str.encode('utf-8') if body_str else None
    with urllib.request.urlopen(req, data=data, timeout=5) as response:
        print(response.read().decode('utf-8'))
except Exception as e:
    print(f'API error on /{endpoint}: {e}')
"
}

{
    find "$LOG_DIR" -name "palserver_stop_*.log" -type f -mtime +30 -exec rm -f {} \;
    log "Stop log rotation check complete."

    if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
        log "Active ${INSTANCE_NAME} session discovered. Initializing graceful countdown..."

        send_api_cmd "announce" '{"message": "Server shutting down in 5 minutes! Please prepare."}'
        sleep 120
        send_api_cmd "announce" '{"message": "Server shutting down in 3 minutes! Find a safe spot."}'
        sleep 120
        send_api_cmd "announce" '{"message": "Server shutting down in 60 seconds! Please log out."}'
        sleep 30
        send_api_cmd "announce" '{"message": "Server shutting down in 30 seconds!"}'
        sleep 20
        send_api_cmd "announce" '{"message": "Saving world state..."}'

        log "Triggering world save via API..."
        send_api_cmd "save" ""
        sleep 10

        log "Sending shutdown signal to Palworld core engine..."
        send_api_cmd "shutdown" '{"waittime": 1, "message": "Server_is_stopping_for_maintenance"}'

        # --- VERIFY THE ACTUAL PROCESS EXITS ---
        # The API accepting the shutdown call doesn't guarantee the
        # process actually terminates - poll for it directly.
        SHUTDOWN_WAIT_MAX=45
        SHUTDOWN_WAIT_COUNT=0
        while pgrep -f "$GAME_PROCESS_NAME" > /dev/null && [ $SHUTDOWN_WAIT_COUNT -lt $SHUTDOWN_WAIT_MAX ]; do
            sleep 1
            ((SHUTDOWN_WAIT_COUNT++))
        done

        SERVER_PID=$(pgrep -f "$GAME_PROCESS_NAME")
        if [ -n "$SERVER_PID" ]; then
            log "Process still alive after API shutdown attempt (${SHUTDOWN_WAIT_COUNT}s). Sending SIGINT to PID $SERVER_PID..."
            kill -SIGINT "$SERVER_PID"
            sleep 15
            if kill -0 "$SERVER_PID" 2>/dev/null; then
                log "Still running after SIGINT. Force killing as last resort (possible data loss)."
                kill -9 "$SERVER_PID"
            else
                log "Process exited cleanly after SIGINT fallback."
            fi
        else
            log "Process exited cleanly after API shutdown (${SHUTDOWN_WAIT_COUNT}s)."
        fi

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Screen session still present. Force closing."
            /usr/bin/screen -S "$INSTANCE_NAME" -X quit
        fi

        if [ -f "$PID_FILE" ]; then
            rm -f "$PID_FILE"
            log "Removed stale PID file."
        fi

        log "Palworld engine instance safely terminated."
    else
        log "No active server screen found. Lifecycle step skipped."
    fi
} 2>&1 | tee -a "$LOGFILE"
