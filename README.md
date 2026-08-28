![Build Status](https://img.shields.io/badge/Dedicated_Server-Linux-green)
![ConanExiles](https://img.shields.io/badge/Conan_Exiles-8A2BE2)
![Steam](https://img.shields.io/badge/Steam-8A2BE2)
# Conan Exiles Linux Server Setup Guide

**Overview**

This is a step-by-step guide on how to set up and run a Ubuntu Conan Exiles dedicated server, including a hardened backup/update/start pipeline, an RCON-based graceful stop, Steam Workshop mod syncing, an automated update checker, and a systemd unit that correctly tracks the real game process.

**Prerequisites**

- Ubuntu server (20.04 or higher recommended)
- Basic knowledge of terminal commands
- A user with sudo privileges

> [!Caution]
> Directory structures may differ based on your specific setup. Paths below assume the server user is `conan` and the install directory is `/home/conan/conan_server` - adjust to match your own setup.

--------------------------------------------------------------------------------
# Step 1: Update and Upgrade Your System

    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y

--------------------------------------------------------------------------------
# Step 2: Install Required Dependencies

    sudo add-apt-repository multiverse -y
    sudo dpkg --add-architecture i386
    sudo apt update

**Install Screen (Session Manager)**

    sudo apt install screen -y

**Install OpenSSH Server**

    sudo apt install openssh-server -y

**Install Steamcmd**

    sudo apt install steamcmd -y

**Install UFW (Uncomplicated Firewall)**

    sudo apt install ufw -y

--------------------------------------------------------------------------------
# Step 3: Configure UFW (Uncomplicated Firewall)

Allow incoming connections to the game port (adjust 7777 if you use a custom port):

    sudo ufw allow from any proto udp to any port 7777 comment "Conan Exiles Server Port"

Allow the query port (used for the server browser):

    sudo ufw allow from any proto udp to any port 27015 comment "Conan Exiles Query Port"

**Allow SSH Connections Through UFW** (Optional)

    sudo ufw allow from any to any port 22 comment "SSH"

> [!Important]
> Do **not** open the RCON port (default 25575) to the internet. The stop script and update checker in this guide only ever connect to RCON over `127.0.0.1` - there is no reason for it to be reachable from outside the box, and exposing it would let anyone who finds the port attempt to authenticate against your RCON password directly.

Set the default rule to deny incoming traffic (Optional)

    sudo ufw default deny incoming

**Enable UFW**

    sudo ufw enable
    sudo ufw status

--------------------------------------------------------------------------------
# Step 4: Create a Non Sudo User

    sudo adduser your_username
    sudo reboot

--------------------------------------------------------------------------------
# Step 5: Install Conan Exiles Server

Log in as your new user, then:

    steamcmd +force_install_dir /home/your_username/conan_server +login anonymous +app_update 443030 validate +quit

--------------------------------------------------------------------------------
# Step 6: Enable RCON and Verify It Works

Unlike some games, Conan Exiles doesn't have a settings file toggle for RCON - it's enabled directly via launch flags, which are already included in the start script in Step 7:

    -RconEnabled=1 -RconPassword="your_rcon_password" -RconPort=25575

> [!Important]
> **Conan Exiles' actual supported RCON commands are not fully or reliably documented anywhere official.** Third-party hosting guides list commands that may not exist on your build - two of them (`save`, `quit`) turned out not to exist at all when tested directly against a real running server in the course of building this guide, despite appearing in multiple "reference" scripts online. **Verify your own server's real command set before trusting any script that uses RCON**, including this one:

Start the server once manually to confirm it boots (`./ConanSandboxServer.sh -log -RconEnabled=1 -RconPassword=your_rcon_password -RconPort=25575`), then from another terminal, ask the server itself what it actually supports:

```bash
python3 -c "
import socket, struct
def run_cmd(ip, port, password, cmd):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect((ip, int(port)))
    s.sendall(struct.pack('<3i', 10 + len(password), 1, 3) + password.encode('utf-8') + b'\x00\x00')
    s.recv(4096)
    s.sendall(struct.pack('<3i', 10 + len(cmd), 2, 2) + cmd.encode('utf-8') + b'\x00\x00')
    res = s.recv(8192)
    s.close()
    print(res)
run_cmd('127.0.0.1', '25575', 'your_rcon_password', 'help')
"
```

This should return a byte string listing every command your build actually supports. On the build this guide was validated against, the real graceful-shutdown command turned out to be `shutdown` (not `quit`, and there is no separate `save` command - `shutdown` handles flushing world data as part of its own sequence). **Confirm what your own server returns before relying on the stop script in Step 8**, and adjust the commands it sends if your build's list differs.

--------------------------------------------------------------------------------
# Step 7: Create the Start Script

    cd
    mkdir -p .scripts/Start_Server .scripts/Stop_Server .scripts/Update_Checker .logs/Start_Server .logs/Stop_Server .logs/Update_Checker
    cd .scripts
    nano start_server.sh

Copy and edit the following - update `DIRPATH`, `ADMIN_PASSWORD`, `RCON_PASSWORD`, and `WORKSHOP_IDS` (your own Steam Workshop mod IDs, or remove Step 2.5 entirely if you don't run mods) to match your setup:

    #!/bin/bash
    set -o pipefail

    #set -x     # Uncomment to enable debug output.

    INSTANCE_NAME="Conan"
    SERVER_PORT="7777"
    DIRPATH="/home/your_username/conan_server"
    STEAMUSERNAME="anonymous"
    BACKUP_DIR="/home/your_username/.backups"
    TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
    LOG_DIR="/home/your_username/.logs/Start_Server"
    LOGFILE="$LOG_DIR/conanserver_$TIMESTAMP.log"
    PID_DIR="/home/your_username/.run"
    PID_FILE="$PID_DIR/conanserver.pid"
    GAME_PROCESS_NAME="ConanSandboxServer-Linux-Shipping"
    ADMIN_PASSWORD="your_admin_password"
    RCON_PASSWORD="your_rcon_password"

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
        log "Initiating pre-update Conan Exiles backup (Saves)..."
        if [ -d "$DIRPATH/ConanSandbox/Saved" ]; then
            tar -czf "$BACKUP_DIR/conanserver_backup_$TIMESTAMP.tar.gz" \
                -C "$DIRPATH/ConanSandbox" Saved/
            if [ $? -eq 0 ]; then
                log "Backup successfully created: conanserver_backup_$TIMESTAMP.tar.gz"
            else
                log "Warning: Backup compression encountered errors."
            fi
        else
            log "Warning: Mandatory Conan Exiles data directory not found. Skipping backup step."
        fi

        find "$BACKUP_DIR" -name "conanserver_backup_*.tar.gz" -type f -mtime +30 -exec rm -f {} \;
        log "Backup rotation check complete (30-day cutoff)."
        find "$LOG_DIR" -name "conanserver_*.log" -type f -mtime +30 -exec rm -f {} \;
        log "Log rotation check complete."

        # --- STEP 2: GAME ENGINE SOFTWARE UPDATE ---
        log "Updating Conan Exiles Server..."
        if /usr/games/steamcmd +force_install_dir "$DIRPATH" +login "$STEAMUSERNAME" +app_update 443030 validate +quit; then
            log "Update completed successfully."
        else
            log "Critical Error: SteamCMD core game update failed. Aborting lifecycle to prevent mismatched version errors."
            exit 1
        fi

        # --- STEP 2.5: STEAM WORKSHOP MOD SYNC (remove this block if you run no mods) ---
        log "Initiating Steam Workshop Mod sync sequence..."

        WORKSHOP_IDS=(
            # Add your own Workshop item IDs here, one per line
        )

        if [ ${#WORKSHOP_IDS[@]} -gt 0 ]; then
            DOWNLOAD_CMD="/usr/games/steamcmd +force_install_dir /home/your_username/downloads +login anonymous"
            for id in "${WORKSHOP_IDS[@]}"; do
                DOWNLOAD_CMD+=" +workshop_download_item 440900 $id"
            done
            DOWNLOAD_CMD+=" +quit"

            if eval "$DOWNLOAD_CMD"; then
                log "Workshop mods pulled from Steam successfully. Transferring files..."
                SRC="/home/your_username/downloads/steamapps/workshop/content/440900"
                DEST="$DIRPATH/ConanSandbox/Mods"
                mkdir -p "$DEST"

                # Remove old .pak files from a previous run, but keep modlist.txt intact.
                find "$DEST" -maxdepth 1 -type f -name "*.pak" -delete

                # Copy each mod in, keeping its original numeric Workshop ID as the filename -
                # this must match how they're listed (by numeric ID) in modlist.txt.
                for id in "${WORKSHOP_IDS[@]}"; do
                    if [ -d "$SRC/$id" ]; then
                        cp "$SRC/$id"/*.pak "$DEST/$id.pak"
                    else
                        log "Warning: Workshop item $id was not found in the download cache; skipping."
                    fi
                done

                log "All mod items successfully synced to active game directory."
                rm -rf "$SRC"/*
                log "Download cache cleared safely."
            else
                log "Warning: SteamCMD mod updates failed. Running server with current .pak items."
            fi
        else
            log "No Workshop IDs configured - skipping mod sync."
        fi

        # --- STEP 3: START APPLICATION WINDOW ---
        log "Starting Conan Exiles server inside Screen session on port $SERVER_PORT..."
        /usr/bin/screen -dmS "$INSTANCE_NAME" "$DIRPATH/ConanSandboxServer.sh" -log -MaxPlayers=40 -AdminPassword="$ADMIN_PASSWORD" -RconEnabled=1 -RconPassword="$RCON_PASSWORD" -RconPort=25575 -RconMaxKarma=60 -port="$SERVER_PORT" -queryport=27015 -multihome=0.0.0.0 -USEALLAVAILABLECORES -workers=4 -NoAsyncloadingStartup

        sleep 60

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Screen session is alive. Verifying the actual game process next..."
        else
            log "Critical Error: Failed to start Conan Exiles screen session."
            exit 1
        fi

        # --- STEP 3.5: CAPTURE THE ACTUAL GAME PROCESS PID ---
        # A live screen session doesn't guarantee the game itself came up (a
        # broken mod can crash it on load while the wrapper session stays
        # open). This confirms the real binary is running and records its
        # PID for systemd to track.
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
            log "Conan Exiles server started successfully in background (PID $GAME_PID)."
        else
            log "Critical Error: Screen session is up, but $GAME_PROCESS_NAME never appeared after ${PID_WAIT_MAX}s."
            log "This usually means the server crashed on load (often a broken/incompatible mod). Check the game log."
            exit 1
        fi
    } 2>&1 | tee -a "$LOGFILE"

Make it executable:

    chmod u+x start_server.sh

--------------------------------------------------------------------------------
# Step 8: Create the Stop Script

    nano stop_server.sh

Copy and edit the following - update `RCON_PASS` and paths to match your setup, and confirm `shutdown` is actually the correct command per your own Step 6 test:

    #!/bin/bash
    set -o pipefail

    INSTANCE_NAME="Conan"
    GAME_PROCESS_NAME="ConanSandboxServer-Linux-Shipping"

    RCON_IP="127.0.0.1"
    RCON_PORT="25575"
    RCON_PASS="your_rcon_password"

    TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
    LOG_DIR="/home/your_username/.logs/Stop_Server"
    LOGFILE="$LOG_DIR/conanserver_stop_$TIMESTAMP.log"

    PID_DIR="/home/your_username/.run"
    PID_FILE="$PID_DIR/conanserver.pid"

    mkdir -p "$LOG_DIR"

    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    }

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
            auth_resp = s.recv(4096)
            # Source RCON protocol: the auth response's Request ID field
            # (bytes 4:8) is -1 on failed authentication. Without this
            # check, a wrong password never raises an exception - it just
            # silently proceeds to send the command over an unauthenticated
            # connection, and every command from then on is a no-op.
            auth_id = struct.unpack('<i', auth_resp[4:8])[0]
            if auth_id == -1:
                print('RCON_AUTH_FAILED')
                s.close()
                return
            s.sendall(struct.pack('<3i', 10 + len(cmd), 2, 2) + cmd.encode('utf-8') + b'\x00\x00')
            res = s.recv(4096)
            s.close()
            return res
        except Exception as e:
            print(f'RCON Error: {e}')
    run_cmd('$RCON_IP', '$RCON_PORT', '$RCON_PASS', '$command_text')
    "
    }

    {
        find "$LOG_DIR" -name "conanserver_stop_*.log" -type f -mtime +30 -exec rm -f {} \;
        log "Stop log rotation check complete."

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Active ${INSTANCE_NAME} session discovered. Initializing graceful countdown..."

            # Verify auth actually succeeds before committing to the full
            # 5-minute countdown - if RCON_PASS is wrong, every subsequent
            # call would silently no-op anyway, so there's no point waiting.
            FIRST_RCON_RESULT=$(send_rcon "broadcast Server shutting down in 5 minutes! Please prepare.")
            if echo "$FIRST_RCON_RESULT" | grep -q "RCON_AUTH_FAILED"; then
                log "CRITICAL: RCON authentication failed (check RCON_PASS). Skipping RCON entirely and going straight to signal-based termination."
            else
                sleep 120
                send_rcon "broadcast Server shutting down in 3 minutes! Find a safe spot."
                sleep 120
                send_rcon "broadcast Server shutting down in 60 seconds! Please log out."
                sleep 30
                send_rcon "broadcast Server shutting down in 30 seconds!"
                sleep 20

                log "Sending RCON shutdown command..."
                send_rcon "shutdown"
            fi

            # --- VERIFY THE ACTUAL PROCESS EXITS ---
            # RCON accepting the command doesn't guarantee the process
            # actually terminates - poll for it directly, and don't assume
            # it happens instantly. On the build this guide was tested
            # against, "shutdown" genuinely works but is not immediate.
            SHUTDOWN_WAIT_MAX=45
            SHUTDOWN_WAIT_COUNT=0
            while pgrep -f "$GAME_PROCESS_NAME" > /dev/null && [ $SHUTDOWN_WAIT_COUNT -lt $SHUTDOWN_WAIT_MAX ]; do
                sleep 1
                ((SHUTDOWN_WAIT_COUNT++))
            done

            SERVER_PID=$(pgrep -f "$GAME_PROCESS_NAME")
            if [ -n "$SERVER_PID" ]; then
                log "Process still alive after RCON shutdown attempt (${SHUTDOWN_WAIT_COUNT}s). Sending SIGINT to PID $SERVER_PID..."
                kill -SIGINT "$SERVER_PID"
                sleep 15
                if kill -0 "$SERVER_PID" 2>/dev/null; then
                    log "Still running after SIGINT. Force killing as last resort (possible data loss)."
                    kill -9 "$SERVER_PID"
                else
                    log "Process exited cleanly after SIGINT fallback."
                fi
            else
                log "Process exited cleanly after RCON shutdown (${SHUTDOWN_WAIT_COUNT}s)."
            fi

            if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
                log "Screen session still present. Force closing."
                /usr/bin/screen -S "$INSTANCE_NAME" -X quit
            fi

            if [ -f "$PID_FILE" ]; then
                rm -f "$PID_FILE"
                log "Removed stale PID file."
            fi

            log "Conan Exiles engine instance safely terminated."
        else
            log "No active server screen found. Lifecycle step skipped."
        fi
    } 2>&1 | tee -a "$LOGFILE"

Make it executable:

    chmod u+x stop_server.sh

--------------------------------------------------------------------------------
# Step 9: Create an Automated Update Checker (Optional)

    nano update_checker.sh

Copy and edit the following, updating paths and `WEBHOOK_URL` (optional) to match your setup:

    #!/bin/bash

    set -o pipefail

    GAME_NAME="Conan Exiles"
    STEAM_APP_ID="443030"
    SERVER_DIR="/home/your_username/conan_server"
    STEAMCMD="/usr/games/steamcmd"
    STOP_SCRIPT="/home/your_username/.scripts/stop_server.sh"
    START_SCRIPT="/home/your_username/.scripts/start_server.sh"
    SCREEN_NAME="Conan"
    RESTART_POLL_MAX_WAIT=180
    TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
    LOG_DIR="/home/your_username/.logs/Update_Checker"
    LOG_FILE="conanserver_update_$TIMESTAMP.log"
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
        find "$LOG_DIR" -name "conanserver_update_*.log" -type f -mtime +3 -exec rm -f {} \;
        log "$(date '+%Y-%m-%d %H:%M:%S') - Update-checker log rotation check complete."

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

Make it executable, then schedule it (every 30 minutes below):

    chmod u+x update_checker.sh
    crontab -e

Add:

    */30 * * * * flock -n /home/your_username/.flock/update_checker.lock /home/your_username/.scripts/update_checker.sh

--------------------------------------------------------------------------------
# Step 10: Create a Systemd Service

    sudo nano /etc/systemd/system/ConanExiles.service

**Add the following configuration** - replace `your_username` throughout:

    [Unit]
    Description=Your Conan Exiles Dedicated Server
    After=network.target network-online.target
    Wants=network-online.target
    StartLimitIntervalSec=600
    StartLimitBurst=2

    [Service]
    Type=forking
    User=your_username
    WorkingDirectory=/home/your_username
    ExecStart=/home/your_username/.scripts/start_server.sh
    ExecStop=/home/your_username/.scripts/stop_server.sh
    PIDFile=/home/your_username/.run/conanserver.pid
    KillMode=control-group
    SendSIGKILL=no
    TimeoutStartSec=300
    TimeoutStopSec=420
    Restart=always
    RestartSec=60

    [Install]
    WantedBy=multi-user.target

> [!Important]
> **`Restart=always`, not `Restart=on-failure`, matters more here than it might look.** This was found via a real, reproduced incident: `on-failure` does **not** treat a clean `SIGINT`-terminated exit as a failure - which is exactly how this stop script's SIGINT fallback (used whenever `shutdown` doesn't finish inside its wait window) terminates the process. Under `on-failure`, a completely normal graceful stop can silently fail to trigger systemd's own auto-restart, with only the update checker's own manual-start fallback catching it - producing a "Maintenance Failed" alert for something that wasn't actually a failure. `Restart=always` removes this dependency on *which signal* killed the process entirely.
>
> **`RestartSec=60`, `TimeoutStartSec=300`, `TimeoutStopSec=420`** were sized from real measured runtimes on a production server (not estimated): a typical start (backup + update + mod sync + launch + PID verify) completed in ~100-120 seconds, and a full graceful stop (5-minute countdown + shutdown + fallback) completed in ~300-330 seconds. These numbers give real margin above both without being wastefully large - tighten or loosen them based on your own measured logs once you've run a few real cycles.
>
> **`StartLimitIntervalSec=600` / `StartLimitBurst=2`** caps systemd to 2 restart attempts in any 10-minute window before giving up and marking the unit `failed`, rather than retrying forever if something is genuinely broken. A single update cycle only ever counts as one restart, so this shouldn't fire during normal operation.

**Enable and Start the Service**

    sudo systemctl daemon-reload
    sudo systemctl enable ConanExiles.service
    sudo systemctl start ConanExiles.service
    sudo systemctl status ConanExiles.service
    cat /home/your_username/.run/conanserver.pid

--------------------------------------------------------------------------------
# Step 11: Create the Host-Level Maintenance Script (Optional)

Steps 7-10 handle the *game* lifecycle. This step handles the *host*: applying OS security patches and rebooting on a schedule, while cleanly stopping and restarting the game around it. This needs **root**, so log in as your sudo user for this step.

    sudo nano /usr/local/sbin/conan_maintenance.sh

Copy and edit the following - update `SERVICE_NAME` and `WEBHOOK_URL` (optional) to match your setup:

    #!/bin/bash

    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    LOGFILE="/var/log/conan_system_maintenance.log"
    SERVICE_NAME="ConanExiles.service"
    WEBHOOK_URL=""
    IMAGE_URL=""

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
        fi

        if [[ "$message" == *"Maintenance Started"* ]]; then
            json_payload=$(cat <<EOF
    {
        "embeds": [{
            "title": "$emoji $message",
            "color": 16711680,
            "image": { "url": "$IMAGE_URL" },
            "footer": { "text": "System Maintenance Automation" }
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
            "footer": { "text": "System Maintenance Automation" }
        }]
    }
    EOF
    )
        fi

        if [[ -n "$WEBHOOK_URL" ]]; then
            curl -s -H "Content-Type: application/json" -X POST -d "$json_payload" "$WEBHOOK_URL" > /dev/null 2>&1
        fi
    }

    exec > >(tee -a "$LOGFILE") 2>&1

    echo "=============================================================================="
    echo "$(date +'%Y-%m-%d %H:%M:%S') --- Starting Conan Exiles Maintenance Sequence ---"

    # The systemd unit's ExecStop= points at stop_server.sh, which handles the
    # RCON countdown/shutdown and the SIGINT/SIGKILL fallback. Calling
    # systemctl stop here means that logic lives in exactly one place instead
    # of being duplicated across scripts.
    send_discord_message "Maintenance Started: Stopping the Conan Exiles server via systemd..."
    echo "$(date +'%Y-%m-%d %H:%M:%S') Stopping $SERVICE_NAME (delegates to stop_server.sh for graceful shutdown)..."
    if systemctl stop "$SERVICE_NAME"; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') $SERVICE_NAME stopped successfully."
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') WARNING: systemctl stop reported a non-zero exit for $SERVICE_NAME. Continuing anyway — check 'systemctl status $SERVICE_NAME' and stop_server.sh's own log if this is unexpected."
    fi

    echo "$(date +'%Y-%m-%d %H:%M:%S') Checking for OS updates..."
    apt-get update > /dev/null

    if apt-get upgrade -s 2>/dev/null | grep -q "^Inst"; then
        send_discord_message "Updates Found. Applying system patches..."
        echo "$(date +'%Y-%m-%d %H:%M:%S') Applying system upgrades..."
        DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" -y full-upgrade
        apt-get autoremove -y
        echo "$(date +'%Y-%m-%d %H:%M:%S') OS updates applied successfully."
    else
        send_discord_message "No updates found. System is clean."
        echo "$(date +'%Y-%m-%d %H:%M:%S') No OS updates found."
    fi

    send_discord_message "Maintenance Complete: Rebooting server host. Conan Exiles will auto-update and start on launch."
    echo "$(date +'%Y-%m-%d %H:%M:%S') Maintenance finished. Flushing storage buffers and executing system reboot."
    echo "=============================================================================="

    sync
    sleep 10
    reboot

Make it executable:

    sudo chmod +x /usr/local/sbin/conan_maintenance.sh

> [!Note]
> `apt-get upgrade -s | grep "^Inst"` (a dry-run simulation) is used deliberately instead of `apt-get list --upgradable` - `apt-get` has no `list` subcommand at all, and that combination silently fails and always reports "no updates," even when real updates are pending. This exact bug was caught by comparing the script's output against a manual `apt update` on a live server and finding a mismatch - worth doing that same sanity check yourself after your first run.

**Schedule it via root's crontab** (not your game user's):

    sudo crontab -e

Add (5 AM daily shown):

    0 5 * * * flock -n /tmp/conan_maintenance.lock /usr/local/sbin/conan_maintenance.sh

--------------------------------------------------------------------------------
# Step 12: Hardening (Optional)

Login with the sudo user and edit the sshd_config file

    sudo nano /etc/ssh/sshd_config

Locate and edit:

    LoginGraceTime 1m
    PermitRootLogin no
    MaxSessions 4

Reload and restart

    sudo systemctl daemon-reload
    sudo systemctl restart ssh.service

**Change Who Can Use the Switch User (su) Command**

    sudo groupadd restrictedsu
    sudo nano /etc/pam.d/su

Add the line:

    auth       required   pam_wheel.so group=restrictedsu

> [!TIP]
> If you want to trigger `start_server.sh`/`stop_server.sh` remotely (e.g. from a control panel or automation tool) without giving that system a general-purpose shell, consider a forced-command SSH key restricted to exactly one script (`command="/home/your_username/.scripts/start_server.sh",restrict ssh-ed25519 ...` in `authorized_keys`) instead of a normal login key. This limits what a leaked key could ever be used for, even in the worst case.

## Lock Down the Operational Scripts

By default, `start_server.sh`, `stop_server.sh`, and `update_checker.sh` are owned by the same user the game process itself runs as. If the running Conan binary or a malicious mod is ever compromised, that account's write access means an attacker could overwrite these scripts - the next time systemd or cron triggers them, your own automation would run the attacker's payload.

    sudo chown root:your_username /home/your_username/.scripts
    sudo chmod 750 /home/your_username/.scripts
    sudo chown root:your_username /home/your_username/.scripts/*.sh
    sudo chmod 750 /home/your_username/.scripts/*.sh

> [!Important]
> Lock down both the **directory** and the **files**. Locking only the files isn't enough - if the directory itself is still writable, an attacker can delete and recreate a script even without write access to its contents.

> [!Caution]
> **This protects against tampering, not against credential exposure.** `750` still gives `your_username` group read access - the same account can `cat stop_server.sh` and read `RCON_PASS` in plaintext, since the game process itself needs that same credential to authenticate over RCON. This is somewhat structurally unavoidable in this design: the account running the game inherently must be able to read what it authenticates with. If a compromised game process reading its own RCON password (rather than modifying scripts) is a threat you specifically care about, that needs a different privilege model entirely - e.g. a helper process with access `your_username` lacks - which is real added complexity most homelab setups don't need. This step solves one problem, not both.

## Sandbox the systemd Service

Add the following under `[Service]` in `/etc/systemd/system/ConanExiles.service` (Step 10):

    Environment="SCREENDIR=/home/your_username/.screen"
    NoNewPrivileges=true
    PrivateTmp=true
    ProtectSystem=strict
    ProtectHome=read-only
    ReadWritePaths=/home/your_username/conan_server
    ReadWritePaths=/home/your_username/.run
    ReadWritePaths=/home/your_username/.flock
    ReadWritePaths=/home/your_username/.screen
    ReadWritePaths=/home/your_username/.logs
    ReadWritePaths=/home/your_username/.backups
    ReadWritePaths=/home/your_username/downloads
    ReadWritePaths=/home/your_username/.local/share/Steam

Create the directory and make sure any manual/interactive `screen` sessions use the same location, or `screen -list` won't see sessions started under the unit and vice versa:

    mkdir -p /home/your_username/.screen
    chmod 700 /home/your_username/.screen
    export SCREENDIR=/home/your_username/.screen   # add this to your shell profile too

> [!Caution]
> `ProtectSystem=strict` and `ProtectHome=read-only` make essentially the entire filesystem read-only to this service by default - every path it needs to write to must be listed explicitly, or the write fails silently and something breaks (most likely the SteamCMD update, the Workshop mod download/sync step, or the backup/log/PID-file writes). `/home/your_username/downloads` above is where Workshop mods are staged before being copied into `Mods/` - easy to forget since it's only used mid-script. **`screen`'s own socket directory is the single most likely thing to break on first deploy** if left unaddressed: its default location (often `/run/screen`, distro-dependent) isn't included in this sandbox at all, and `screen -dmS` failing to create its socket fails silently. Pinning `SCREENDIR` explicitly, as done above, removes the guesswork. If you installed SteamCMD differently, confirm its actual cache path too.

**Test before trusting this in production** - reload, restart, and watch a full update-and-mod-sync cycle complete successfully before considering this done:

    sudo systemctl daemon-reload
    sudo systemctl restart ConanExiles.service
    sudo journalctl -u ConanExiles.service -f
    sudo systemd-analyze security ConanExiles.service

--------------------------------------------------------------------------------

**Conclusion**

You have successfully set up a hardened Conan Exiles server with automated backups, Workshop mod syncing, graceful RCON-based updates, and a systemd service that correctly tracks the real game process.

**References**
- https://developer.valvesoftware.com/wiki/SteamCMD#Linux
- https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
