#!/bin/bash

#set -x # Uncomment to enable debug output. This will show you each command as it’s executed, which can help identify where it fails

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
    if /usr/games/steamcmd +force_install_dir "$DIRPATH" +login anonymous +app_update 2394010 validate +quit; then  # Update with the app ID
        log "Update completed."
    else
        log "Update failed."
        # Continue to start the server regardless of update result
    fi

    # Start the PalWorld server
    log "Starting PalWorld server..."
    if /usr/bin/screen -dmS PalWorld "$DIRPATH/PalServer.sh" -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -PublicLobby 2>> "$LOGFILE"; then
        log "PalWorld server started successfully."
    else
        log "Failed to start PalWorld server."
        exit 1  # Exit if the server fails to start
    fi
} 2>&1 | tee -a "$LOGFILE"
