#!/bin/bash

# You will need to run this with sudo
# This script completes steps 1, 2, & 7
# Disclaimer: Script created with assistance from ChatGPT.

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/palworld_setup.log
}

# Error handling function
error_exit() {
    log "Error on line $1: $2"
    exit 1
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Step 1: Update and Upgrade Your System
log "Starting system update, upgrade, and cleanup..."
apt update && apt full-upgrade -y && apt autoremove -y 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to update and upgrade the system."
log "System update, upgrade, and cleanup completed."

# Step 2: Install Required Dependencies
log "Installing required dependencies..."

# Check and add multiverse repository if not already added
if ! grep -q "multiverse" /etc/apt/sources.list; then
    add-apt-repository multiverse -y 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to add multiverse repository."
fi

# Check and add i386 architecture
if ! dpkg --print-foreign-architectures | grep -q "i386"; then
    dpkg --add-architecture i386 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to add i386 architecture."
fi

apt update 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to update package list after adding repository."
apt install screen steamcmd -y 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to install screen and steamcmd."

# Check installation
if ! command -v screen &> /dev/null || ! command -v steamcmd &> /dev/null; then
    error_exit $LINENO "screen or steamcmd installation failed."
fi

log "Required dependencies installed."

# Step 3: Create a Systemd Service
log "Creating systemd service..."
cat <<EOF > /etc/systemd/system/PalWorld.service
[Unit]
Description=PalWorld Server
After=network.target

[Service]
Type=forking
WorkingDirectory=/home/steam/.steam/steamapps/common/PalServer
ExecStart=/usr/bin/screen -dmS PalWorld /home/steam/.steam/steamapps/common/PalServer/./PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -PublicLobby
RemainAfterExit=yes
Restart=on-failure
RestartSec=5
User=steam
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to reload systemd daemon."
systemctl enable PalWorld.service 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to enable PalWorld service."
systemctl start PalWorld.service 2>>/var/log/palworld_setup.log || error_exit $LINENO "Failed to start PalWorld service."
log "Systemd service created and started."

log "Palworld server setup completed successfully."
