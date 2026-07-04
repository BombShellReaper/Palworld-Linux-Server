#!/bin/bash

# ==============================================================================
#                 PALWORLD SYSTEM DEPLOYMENT & AUTOMATION ENGINE
# ==============================================================================
# AUTHOR: BombShellReaper
# REPO: https://github.com
# ==============================================================================

# --- CONFIGURATION (EDIT AS NEEDED) ---
INSTANCE_NAME="Palworld"
SERVER_PORT="8211" # Change to 8321 if running a secondary instance
DIRPATH="/home/your_username/pw_server"
LOG_DIR="/home/your_username/logs"
BACKUP_DIR="/home/your_username/backups"

# --- SYSTEM TIMESTAMPS ---
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOGFILE="$LOG_DIR/palserver_${TIMESTAMP}.log"

# Establish target directory paths if missing
mkdir -p "$LOG_DIR" "$BACKUP_DIR"
touch "$LOGFILE"

# Standardized logging helper function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# --- EXECUTIVE EXECUTION SEQUENCE ---
{
    log "========================================================================"
    log "Initiating Global Startup Lifecycle Loop for [${INSTANCE_NAME}]..."
    log "========================================================================"

    # --- ACTION 1: DUAL-SCOPE COMPRESSED BACKUPS ---
    log "Compiling real-time database state (Saves and Configurations)..."
    if tar -czf "$BACKUP_DIR/palserver_backup_${TIMESTAMP}.tar.gz" -C "$DIRPATH/Pal" Saved 2>> "$LOGFILE"; then
        log "Game database compressed archive successfully committed to storage."
    else
        log "WARNING: Database backup routine encountered a file-system conflict."
    fi

    # --- ACTION 2: ENFORCE 30-DAY BACKUP & LOG ROTATION ---
    log "Enforcing strict 30-day storage optimization policies..."
    find "$BACKUP_DIR" -name "palserver_backup_*.tar.gz" -type f -mtime +30 -exec rm -f {} \;
    find "$LOG_DIR" -name "palserver_*.log" -type f -mtime +30 -exec rm -f {} \;
    find "$LOG_DIR" -name "palserver_stop_*.log" -type f -mtime +30 -exec rm -f {} \;
    log "Storage pruning checks complete. Disk footprint fully optimized."

    # --- ACTION 3: DUPLICATE SCREEN PROTECTION CHECK ---
    if /usr/bin/screen -list | grep -q "${INSTANCE_NAME}"; then
        log "CRITICAL: A standalone background instance named [${INSTANCE_NAME}] is already online."
        log "Terminating duplicate initialization sequence to protect ports."
        exit 1
    fi

    # --- ACTION 4: AUTOMATED STEAMCMD 1.0 PATCH SYNC ---
    log "Synchronizing server binaries via SteamCMD App ID: 2394010..."
    if /usr/games/steamcmd +force_install_dir "$DIRPATH" +login anonymous +app_update 2394010 validate +quit >> "$LOGFILE" 2>&1; then
        log "SteamCMD binary synchronization complete. System fully validated."
    else
        log "ERROR: SteamCMD encounter an upstream connection dropout. Proceeding with launch..."
    fi

    # --- ACTION 5: INJECT BACKGROUND SCREEN CORE ENGINE ---
    log "Launching PalServer engine inside dedicated Screen background terminal..."
    # Configured with explicit -publicport multi-home capability and -rcon networking flags
    if /usr/bin/screen -dmS "${INSTANCE_NAME}" "$DIRPATH/PalServer.sh" -port="$SERVER_PORT" -publicport="$SERVER_PORT" -EpicApp=PalServer -rcon -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS 2>> "$LOGFILE"; then
        log "Palworld dedicated instance successfully stabilized in background screen matrix."
    else
        log "CRITICAL: Background terminal layer failed to forge."
        exit 1
    fi

    log "========================================================================"
    log "System Ignition Complete. Monitoring handover active."
    log "========================================================================"
} 2>&1 | tee -a "$LOGFILE"
