#!/bin/bash

# ==============================================================================
#              PALWORLD GRACEFUL SHUTDOWN & SAVE ENGINE
# ==============================================================================
# AUTHOR: BombShellReaper
# REPO: https://github.com/BombShellReaper/Palworld-Linux-Server
# ==============================================================================

# --- CONFIGURATION ---
RCON_IP="127.0.0.1"
RCON_PORT="25575"
RCON_PASS="YOUR_ADMIN_PASSWORD_HERE"  

# Log management configuration
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOG_DIR="/home/your_username/logs"
LOGFILE="$LOG_DIR/palserver_stop_$TIMESTAMP.log"

mkdir -p "$LOG_DIR"
touch "$LOGFILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Isolated Network Python RCON execution matrix
send_rcon() {
    local command_text="$1"
    python3 -c "
import socket, struct
def run_cmd(ip, port, password, cmd):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect((ip, int(port)))
        s.sendall(struct.pack('<3i', 10 + len(password), 1, 3) + password.encode('utf-8') + b'\x00\x00')
        s.recv(4096)
        s.sendall(struct.pack('<3i', 10 + len(cmd), 2, 2) + cmd.encode('utf-8') + b'\x00\x00')
        res = s.recv(4096)
        s.close()
        return res
    except Exception as e:
        print(f'RCON Error: {e}')
run_cmd('$RCON_IP', '$RCON_PORT', '$RCON_PASS', '$command_text')
"
}

# --- EXECUTIVE SEQUENCE BLOCK ---
{
    if /usr/bin/screen -list | grep -q "Palworld"; then
        log "Active Palworld session discovered. Initializing graceful countdown..."

        send_rcon "Broadcast Server shutting down in 5 minutes! Please prepare."
        sleep 120

        send_rcon "Broadcast Server shutting down in 3 minutes! Find a safe spot."
        sleep 120

        send_rcon "Broadcast Server shutting down in 60 seconds! Please log out."
        sleep 30

        send_rcon "Broadcast Server shutting down in 30 seconds!"
        sleep 20

        send_rcon "Broadcast Saving world state..."
        send_rcon "Save"
        sleep 5

        send_rcon "Shutdown 1 Server is stopping for_maintenance"
        sleep 5

        if /usr/bin/screen -list | grep -q "Palworld"; then
            log "Screen hung during file flush. Hard closing background layer..."
            /usr/bin/screen -S Palworld -X quit
        fi
        log "Palworld engine instance safely terminated."
    else
        log "No active server screen found. Lifecycle step skipped."
    fi
} 2>&1 | tee -a "$LOGFILE"
