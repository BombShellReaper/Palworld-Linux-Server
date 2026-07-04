#!/bin/bash

# ==============================================================================
#                 PALWORLD HOST OS DEPLOYMENT & MAINTENANCE ENGINE
# ==============================================================================
# AUTHOR: BombShellReaper
# REPO: https://github.com/BombShellReaper/Palworld-Linux-Server
# ==============================================================================

# --- CONFIGURATION (EDIT AS NEEDED) ---
LOGFILE="/var/log/palserver_system_maintenance.log"
WEBHOOK_URL="https://discord.com" # <-- Sanitized generic placeholder

# Ensure log targets exist cleanly
touch "$LOGFILE"

send_discord_message() {
    local message="$1"
    local image_url="https://your-image-url.com" # <-- Sanitized generic placeholder

    # Conditional checking rules to inject an image array cleanly into the JSON block
    if [[ "$message" == *"Maintenance Started"* ]]; then
        local image_json="\"image\": { \"url\": \"$image_url\" }"
        local comma_break=","
    else
        local image_json=""
        local comma_break=""
    fi

    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -H "Content-Type: application/json" -X POST -d "{
            \"embeds\": [{
                \"title\": \"🛠️ $message\",
                \"color\": 16711680${comma_break}
                ${image_json}${comma_break}
                \"footer\": { \"text\": \"Palworld Host System Maintenance Automation\" }
            }]
        }" "$WEBHOOK_URL" > /dev/null 2>&1
    fi
}

# --- 1. INITIALIZE WEBHOOK & LOG ---
echo "$(date +'%Y-%m-%d %H:%M:%S') --- STARTING ROOT SYSTEM MAINTENANCE ---" | tee -a "$LOGFILE"
send_discord_message "Maintenance Started: Checking for OS updates on Palworld host."

# --- 2. CHECK AND APPLY LINUX UBUNTU OS UPDATES ---
echo "Checking for Ubuntu system updates..." | tee -a "$LOGFILE"
apt-get update > /dev/null
UPGRADES=$(apt list --upgradable 2>/dev/null | grep -v "Listing...")

if [ -n "$UPGRADES" ]; then
    send_discord_message "✅ **Updates Found.** Applying system patches..."
    echo "Applying upgrades..." | tee -a "$LOGFILE"
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" -y full-upgrade >> "$LOGFILE" 2>&1
    apt-get autoremove -y >> "$LOGFILE" 2>&1
    echo "Updates applied successfully." | tee -a "$LOGFILE"
else
    send_discord_message "ℹ️ No updates found. Core OS is clean."
    echo "No updates found." | tee -a "$LOGFILE"
fi

# --- 3. EXECUTE HARDWARE REBOOT ---
send_discord_message "🔄 **Maintenance Complete:** Rebooting server. Game servers will auto-restart."
echo "Maintenance finished. Rebooting system." | tee -a "$LOGFILE"
sleep 2
reboot
