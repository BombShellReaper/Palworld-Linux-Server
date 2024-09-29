#!/bin/bash

# Log file
LOGFILE="/path/to/your/logfile.txt"  # Update with your log file path

# Function to log messages with date/time
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Update PalWorld using steamcmd
{
    log "Updating PalWorld..."
    if /usr/games/steamcmd +force_install_dir "/path/to/your/game" +login anonymous +app_update 2394010 validate +quit; then  # Update with path to your game
        log "Update completed."
    else
        log "Update failed."
        exit 1
    fi

    # Start the PalWorld server
    log "Starting PalWorld server..."
    if /usr/bin/screen -dmS PalWorld "/path/to/your/game/PalServer.sh" -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -PublicLobby; then  # Update with path to your game
        log "PalWorld server started successfully."
    else
        log "Failed to start PalWorld server."
        exit 1
    fi
} 2>&1 | tee -a "$LOGFILE"

