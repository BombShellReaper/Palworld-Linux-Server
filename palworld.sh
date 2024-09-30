#!/bin/bash

# Log file
LOGFILE="/path/to/your/logfile.txt"  # Update with your log file path
DIRPATH="/path/to/your/server" # Update with the directory containing PalServer.sh

# Function to log messages with date/time
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Update PalWorld using steamcmd
{
    log "Updating PalWorld..."
    if /usr/games/steamcmd +force_install_dir "$DIRPATH" +login anonymous +app_update 2394010 validate +quit; then
        log "Update completed."
    else
        log "Update failed."
        exit 1
    fi

    # Start the PalWorld server
    log "Starting PalWorld server..."
    if /usr/bin/screen -dmS PalWorld "$DIRPATH/PalServer.sh" -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -PublicLobby; then  # Update with path to your script
        log "PalWorld server started successfully."
    else
        log "Failed to start PalWorld server."
        exit 1
    fi
} 2>&1 | tee -a "$LOGFILE"
