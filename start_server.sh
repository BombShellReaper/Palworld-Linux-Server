#!/bin/bash
set -o pipefail

#set -x     # Uncomment to enable debug output.

INSTANCE_NAME="Palworld"
SERVER_PORT="8211"
DIRPATH="/home/your_username/pw_server"
STEAMUSERNAME="anonymous"
BACKUP_DIR="/home/your_username/backups"
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOG_DIR="/home/your_username/logs"
LOGFILE="$LOG_DIR/palserver_$TIMESTAMP.log"

# PID tracking (for real process verification / systemd integration)
PID_DIR="/home/your_username/.run"
PID_FILE="$PID_DIR/palserver.pid"
GAME_PROCESS_NAME="PalServer-Linux-Shipping"

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$PID_DIR"

# --- SELF-LOCK: prevent overlapping invocations from racing the duplicate check ---
# Without this, two near-simultaneous calls to this script (from systemd,
# a control panel, cron, or a manual run) could both pass the duplicate
# check below before either has actually launched anything, resulting in
# two real game processes running at once.
LOCK_DIR="/home/your_username/.flock"
LOCK_FILE="$LOCK_DIR/start_server.lock"
mkdir -p "$LOCK_DIR"

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Another instance of start_server.sh is already running (lock held). Exiting cleanly."
    exit 0
fi

# Everything below is piped through `tee -a "$LOGFILE"`, so a plain echo
# here already reaches both the console and the log file.
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

{
    # --- STEP 0: DUPLICATE SCREEN SESSION PROTECTION ---
    if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
        log "'${INSTANCE_NAME}' is already running in an active Screen session. Nothing to do."
        # Exit 0, not 1: with Type=forking + Restart=always in the systemd
        # unit, a non-zero exit here would be read as a failed start and
        # trigger an endless restart loop against a server that is
        # actually healthy.
        exit 0
    fi

    # --- STEP 1: BACKUP & LOG ROTATION ---
    log "Initiating pre-update Palworld backup (Saves and Configurations)..."
    if [ -d "$DIRPATH/Pal/Saved/SaveGames" ] && [ -d "$DIRPATH/Pal/Saved/Config" ]; then
        tar -czf "$BACKUP_DIR/palserver_backup_$TIMESTAMP.tar.gz" \
            -C "$DIRPATH/Pal/Saved" SaveGames/ Config/
        if [ $? -eq 0 ]; then
            log "Backup successfully created: palserver_backup_$TIMESTAMP.tar.gz"
        else
            log "Warning: Backup compression encountered errors."
        fi
    else
        log "Warning: Mandatory Palworld data directories not found. Skipping backup step."
    fi

    log "Enforcing 30-day backup retention rotation policy..."
    find "$BACKUP_DIR" -name "palserver_backup_*.tar.gz" -type f -mtime +30 -exec rm -f {} \;
    log "Backup rotation check complete."

    log "Enforcing 30-day individual log retention rotation policy..."
    find "$LOG_DIR" -name "palserver_*.log" -type f -mtime +30 -exec rm -f {} \;
    log "Log rotation check complete."

    # --- STEP 2: GAME ENGINE SOFTWARE UPDATE ---
    log "Updating Palworld Server..."
    if /usr/games/steamcmd +force_install_dir "$DIRPATH" +login "$STEAMUSERNAME" +app_update 2394010 validate +quit; then
        log "Update completed successfully."
    else
        log "Critical Error: SteamCMD core game update failed. Aborting lifecycle to prevent mismatched version errors."
        exit 1
    fi

    # --- STEP 3: START APPLICATION WINDOW ---
    log "Starting Palworld server inside Screen session on port $SERVER_PORT..."
    /usr/bin/screen -dmS "$INSTANCE_NAME" "$DIRPATH/PalServer.sh" -port="$SERVER_PORT" -publicport="$SERVER_PORT" -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -PublicLobby

    sleep 5

    if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
        log "Screen session is alive. Verifying the actual game process next..."
    else
        log "Critical Error: Failed to start Palworld screen session."
        exit 1
    fi

    # --- STEP 3.5: CAPTURE THE ACTUAL GAME PROCESS PID ---
    # A live screen session doesn't guarantee the game itself came up (a
    # failed update or bad config can crash it on load while the wrapper
    # session stays open). This confirms the real binary is running and
    # records its PID for systemd to track.
    log "Waiting for $GAME_PROCESS_NAME to appear so we can confirm the server actually started..."
    PID_WAIT_MAX=60
    PID_WAIT_COUNT=0
    GAME_PID=""

    while [ -z "$GAME_PID" ] && [ $PID_WAIT_COUNT -lt $PID_WAIT_MAX ]; do
        GAME_PID=$(pgrep -f "$GAME_PROCESS_NAME" | head -n1)
        if [ -z "$GAME_PID" ]; then
            sleep 1
            ((PID_WAIT_COUNT++))
        fi
    done

    if [ -n "$GAME_PID" ]; then
        echo "$GAME_PID" > "$PID_FILE"
        log "Palworld server started successfully in background (PID $GAME_PID)."
    else
        log "Critical Error: Screen session is up, but $GAME_PROCESS_NAME never appeared after ${PID_WAIT_MAX}s."
        log "Check the game log for the actual failure cause."
        exit 1
    fi
} 2>&1 | tee -a "$LOGFILE"
