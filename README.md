![Build Status](https://img.shields.io/badge/Dedicated_Server-Linux-green)
![Palworld](https://img.shields.io/badge/Palworld-8A2BE2)
![Steam](https://img.shields.io/badge/Steam-8A2BE2)
# Palworld Linux Server Setup Guide

**Overview**

This is a step-by-step guide on how to set up and run a Ubuntu Palworld server, including a hardened backup/update/start pipeline, a REST API-based graceful stop, an automated update checker, and a systemd unit that correctly tracks the real game process.

**Prerequisites**

- Ubuntu server (20.04 or higher recommended)
- Basic knowledge of terminal commands
- A user with sudo privileges

> [!Caution]
> Directory structures may differ based on your specific setup. Paths below assume the server user is `steam` and the install directory is `/home/steam/pw_server` - adjust to match your own setup.

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

Allow all incoming connections to the game port (adjust 8211 if you use a custom port):

    sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server Port"
    sudo ufw allow from any proto udp to any port 27015 comment "Palworld Query Port"
    sudo ufw allow from any to any port 22 comment "SSH"

> [!TIP]
> For added security, change "any" to a specific IP address or range on any of the rules above.

> [!Important]
> Do not open the REST API port (8212) to the internet - it's only ever accessed over `127.0.0.1`.

Set the default rule to deny incoming traffic (Optional)

    sudo ufw default deny incoming

**Enable UFW** (UFW will enable on reboot)

    sudo ufw enable

Check the UFW status after enabling it:

    sudo ufw status

--------------------------------------------------------------------------------
# Step 4: Create a Non Sudo User

Replace "*your_username*" with the desired username.

    sudo adduser your_username

> [!NOTE]
> This will prompt you through the setup

**Reboot the system**

    sudo reboot

-------------------------------------------------------------------------------
# Step 5: Install Palworld Server

**Log in to your server with the new user account through cmd, PowerShell, PuTTY, etc. Use your preferred terminal emulator.**

**Install Palworld Server Files**

    steamcmd +force_install_dir /home/your_username/pw_server +login anonymous +app_update 2394010 validate +quit

**Navigate to the Server Directory**

    cd pw_server

**Start the server once, manually, to generate its config files**

    ./PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS

Stop the server with Ctrl + C once you see it finish loading. This generates `Pal/Saved/Config/LinuxServer/`, `DefaultPalWorldSettings.ini`, and default save data.

--------------------------------------------------------------------------------
# Step 6: Configure the Server

This guide copies PocketPair's own `DefaultPalWorldSettings.ini` as the config baseline instead of a static hand-maintained block - the same workflow their [official docs](https://docs.palworldgame.com/settings-and-operation/configuration/) recommend, and one that stays current as PocketPair adds new options in future patches.

> [!Important]
> Do this with the server **stopped** - it holds config in memory and overwrites the file on exit, silently discarding edits made while running.

**Copy the default config as your active baseline** (`DefaultPalWorldSettings.ini` lives at the install root, not under `Pal/Saved/Config/` like the active file):

    cp /home/your_username/pw_server/DefaultPalWorldSettings.ini \
       /home/your_username/pw_server/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

> [!Caution]
> Editing `DefaultPalWorldSettings.ini` directly has no effect - always edit the copy. Re-running this `cp` on a live server overwrites every custom setting since; `start_server.sh`'s backups (Step 7) already include `Config/` if you need to restore.

**Set the values this guide's automation depends on:**

    CONFIG="/home/your_username/pw_server/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini"
    sed_escape() { printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g'; }
    SERVER_NAME_ESCAPED=$(sed_escape "Your Server Name")
    ADMIN_PASSWORD_ESCAPED=$(sed_escape "your_admin_password")

    sed -i "s/ServerName=\"[^\"]*\"/ServerName=\"$SERVER_NAME_ESCAPED\"/" "$CONFIG"
    sed -i "s/AdminPassword=\"[^\"]*\"/AdminPassword=\"$ADMIN_PASSWORD_ESCAPED\"/" "$CONFIG"
    sed -i 's/RESTAPIEnabled=False/RESTAPIEnabled=True/' "$CONFIG"

> [!Important]
> `AdminPassword` and `RESTAPIEnabled=True` are required for the stop script/update checker. Left at defaults, the graceful shutdown fails silently and falls back to `SIGKILL`.

Everything else - `ExpRate`, `DeathPenalty`, `ServerPlayerMaxNum`, etc. - stays at PocketPair's current defaults, ready to tune the same way.

**Verify the API is reachable:**

    curl -s -u admin:YOUR_ADMIN_PASSWORD http://127.0.0.1:8212/v1/api/info

Should return a JSON blob with server name/version.

--------------------------------------------------------------------------------
# Step 7: Create the Start Script

    cd
    mkdir .scripts
    cd .scripts
    nano start_server.sh

Update `INSTANCE_NAME`, `SERVER_PORT`, `DIRPATH`, `BACKUP_DIR`, and `LOG_DIR` to match your setup:

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

Make the script executable:

    chmod u+x start_server.sh

--------------------------------------------------------------------------------
# Step 8: Create the Stop Script

    nano stop_server.sh

Update `API_PASS` to match `AdminPassword`:

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
    import urllib.error
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
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            print('API_AUTH_FAILED')
        else:
            print(f'API error on /{endpoint}: HTTP {e.code}')
    except (urllib.error.URLError, ConnectionRefusedError, TimeoutError) as e:
        # Covers RESTAPIEnabled=False or the API not running at all - not
        # just a wrong password. Same fast-fail signal so the bash side
        # doesn't have to distinguish the two.
        print('API_AUTH_FAILED')
    except Exception as e:
        print(f'API error on /{endpoint}: {e}')
    "
    }

    {
        find "$LOG_DIR" -name "palserver_stop_*.log" -type f -mtime +30 -exec rm -f {} \;
        log "Stop log rotation check complete."

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Active ${INSTANCE_NAME} session discovered. Initializing graceful countdown..."

            # Verify auth actually succeeds before committing to the full
            # countdown - if API_PASS is wrong, every subsequent call would
            # silently fail anyway, so there's no point waiting.
            FIRST_API_RESULT=$(send_api_cmd "announce" '{"message": "Server shutting down in 5 minutes! Please prepare."}')
            if echo "$FIRST_API_RESULT" | grep -q "API_AUTH_FAILED"; then
                log "CRITICAL: REST API unreachable or authentication failed (check RESTAPIEnabled/API_PASS). Skipping the API entirely and going straight to signal-based termination."
            else
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
            fi

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

Make it executable:

    chmod u+x stop_server.sh

> [!TIP]
> Confirm the countdown timing actually fits your comfort level before relying on it - the full sequence above (5 min → 3 min → 60s → 30s → save → shutdown) takes about 5 minutes from the first warning to the shutdown command being sent.

--------------------------------------------------------------------------------
# Step 9: Create an Automated Update Checker (Optional)

Checks Steam for updates, gracefully stops the server, and lets systemd bring it back up (with a manual-start fallback if it doesn't).

    nano update_checker.sh

    #!/bin/bash

    set -o pipefail

    GAME_NAME="Palworld"
    STEAM_APP_ID="2394010"
    SERVER_DIR="/home/your_username/pw_server"
    STEAMCMD="/usr/games/steamcmd"
    STOP_SCRIPT="/home/your_username/.scripts/stop_server.sh"
    START_SCRIPT="/home/your_username/.scripts/start_server.sh"
    SCREEN_NAME="Palworld"
    RESTART_POLL_MAX_WAIT=180
    TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
    LOG_DIR="/home/your_username/logs"
    LOG_FILE="palserver_update_$TIMESTAMP.log"
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
        find "$LOG_DIR" -name "palserver_update_*.log" -type f -mtime +3 -exec rm -f {} \;
        log "$(date '+%Y-%m-%d %H:%M:%S') - Update-checker log rotation check complete."

        # Read the true installed version from disk (not just a tracking file)
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

Make it executable, then add it to your crontab to run on a schedule (every 30 minutes below):

    chmod u+x update_checker.sh
    crontab -e

Add this line:

    */30 * * * * flock -n /home/your_username/.flock/update_checker.lock /home/your_username/.scripts/update_checker.sh

--------------------------------------------------------------------------------
# Step 10: Create a Systemd Service

    sudo nano /etc/systemd/system/PalWorld.service

**Add the following configuration** - replace `your_username` throughout:

    [Unit]
    Description=Your Palworld Server Instance
    After=network.target network-online.target
    Wants=network-online.target
    StartLimitIntervalSec=1200
    StartLimitBurst=3

    [Service]
    Type=forking
    User=your_username
    WorkingDirectory=/home/your_username
    ExecStart=/home/your_username/.scripts/start_server.sh
    ExecStop=/home/your_username/.scripts/stop_server.sh
    PIDFile=/home/your_username/.run/palserver.pid
    KillMode=control-group
    SendSIGKILL=no
    TimeoutStartSec=600
    TimeoutStopSec=420
    RemainAfterExit=no
    Restart=always
    RestartSec=60
    StandardOutput=null
    StandardError=null

    [Install]
    WantedBy=multi-user.target

> [!Note]
> `Type=forking` + `PIDFile=`, not `Type=simple` - the script launches the game inside a detached `screen` session and exits itself, so systemd tracks the PID written to `PIDFile`.

> [!Note]
> `ExecStop=` points at `stop_server.sh` - this is what makes `systemctl stop` trigger the graceful REST API shutdown, not a raw kill signal.

> [!Important]
> `Restart=always`, not `on-failure` - `on-failure` doesn't count a `SIGINT`-terminated exit (the stop script's own method) as a failure, so it can silently skip auto-restart.

> [!Note]
> `RestartSec=60`/`TimeoutStartSec=600` are starting points - tighten once you've measured real timing from your own logs.

> [!Note]
> `StartLimitIntervalSec=1200`/`StartLimitBurst=3` caps retries to 3 per 20 minutes before marking the unit `failed`. The window must exceed `TimeoutStartSec`, or the safety net never triggers.

**Enable and Start the Service**

    sudo systemctl daemon-reload
    sudo systemctl enable PalWorld.service
    sudo systemctl start PalWorld.service
    sudo systemctl status PalWorld.service
    cat /home/your_username/.run/palserver.pid

--------------------------------------------------------------------------------
# Step 11: Create the Host-Level Maintenance Script (Optional)

Handles OS patching and reboot. Needs root - not your game user's `.scripts`/crontab.

    sudo nano /usr/local/sbin/palworld_maintenance.sh

    #!/bin/bash

    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # --- Configuration ---
    LOGFILE="/var/log/palworld_system_maintenance.log"
    SERVICE_NAME="PalWorld.service"
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

    # Redirect standard output and error to both console and this run's logfile
    exec > >(tee -a "$LOGFILE") 2>&1

    echo "=============================================================================="
    echo "$(date +'%Y-%m-%d %H:%M:%S') --- Starting Palworld Maintenance Sequence ---"

    # --- 1. GRACEFULLY STOP THE PALWORLD SERVER (VIA SYSTEMD, WHICH RUNS stop_server.sh) ---
    # The systemd unit's ExecStop= (Step 10) points at stop_server.sh, which
    # handles the countdown, the REST API save/shutdown, and the SIGINT/
    # SIGKILL fallback. Calling systemctl stop here means that logic lives in
    # exactly one place instead of being duplicated across scripts.
    send_discord_message "Maintenance Started: Stopping the Palworld server via systemd..."
    echo "$(date +'%Y-%m-%d %H:%M:%S') Stopping $SERVICE_NAME (delegates to stop_server.sh for graceful shutdown)..."
    if systemctl stop "$SERVICE_NAME"; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') $SERVICE_NAME stopped successfully."
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') WARNING: systemctl stop reported a non-zero exit for $SERVICE_NAME. Continuing anyway — check 'systemctl status $SERVICE_NAME' and stop_server.sh's own log if this is unexpected."
    fi

    # --- 2. CHECK AND APPLY SYSTEM UPDATES ---
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

    # --- 3. REBOOT THE MACHINE ---
    send_discord_message "Maintenance Complete: Rebooting server host. Palworld will auto-update and start on launch."
    echo "$(date +'%Y-%m-%d %H:%M:%S') Maintenance finished. Flushing storage buffers and executing system reboot."
    echo "=============================================================================="

    sync
    sleep 10
    reboot

Make it executable:

    sudo chmod +x /usr/local/sbin/palworld_maintenance.sh

> [!Note]
> `apt-get upgrade -s | grep "^Inst"` is used instead of `apt-get list --upgradable` - the latter isn't a valid `apt-get` subcommand and silently reports no updates even when patches are pending.

**Schedule via root's crontab** (not your game user's):

    sudo crontab -e

Add (5 AM daily shown):

    0 5 * * * flock -n /tmp/palworld_maintenance.lock /usr/local/sbin/palworld_maintenance.sh

--------------------------------------------------------------------------------
# Step 12: Hardening (Optional)

    sudo nano /etc/ssh/sshd_config

Set:

    LoginGraceTime 1m
    PermitRootLogin no
    MaxSessions 4

    sudo systemctl daemon-reload
    sudo systemctl restart ssh.service

**Restrict `su`:**

    sudo groupadd restrictedsu
    sudo nano /etc/pam.d/su

Add:

    auth       required   pam_wheel.so group=restrictedsu

> [!TIP]
> For remote triggers (control panels, automation), use a forced-command SSH key restricted to one script instead of a normal login key: `command="/home/your_username/.scripts/start_server.sh",restrict ssh-ed25519 ...` in `authorized_keys`.

## Lock Down the Operational Scripts

`start_server.sh`, `stop_server.sh`, and `update_checker.sh` are owned by the same user the game process runs as by default - if that process is ever compromised, it could overwrite its own automation.

    sudo chown root:your_username /home/your_username/.scripts
    sudo chmod 750 /home/your_username/.scripts
    sudo chown root:your_username /home/your_username/.scripts/*.sh
    sudo chmod 750 /home/your_username/.scripts/*.sh

> [!Important]
> Lock down both the **directory** and the **files** - directory write access alone lets an attacker delete and recreate a script.

> [!Caution]
> This prevents tampering, not credential exposure - `your_username` (same account the game runs as) can still read `API_PASS` in plaintext via group access.

## Sandbox the systemd Service

Add under `[Service]` in Step 10's unit:

    Environment="SCREENDIR=/home/your_username/.screen"
    ExecStartPre=/bin/mkdir -p /home/your_username/.screen
    ExecStartPre=/bin/chmod 700 /home/your_username/.screen
    NoNewPrivileges=true
    PrivateTmp=true
    ProtectSystem=strict
    ProtectHome=read-only
    ReadWritePaths=/home/your_username/pw_server
    ReadWritePaths=/home/your_username/.run
    ReadWritePaths=/home/your_username/.flock
    ReadWritePaths=/home/your_username/.screen
    ReadWritePaths=/home/your_username/logs
    ReadWritePaths=/home/your_username/backups
    ReadWritePaths=/home/your_username/.local/share/Steam

> [!Note]
> `ExecStartPre=` runs inside the same sandbox as `ExecStart=`, so it can already write to `.screen` via the `ReadWritePaths` entry above - no separate manual `mkdir` step needed, and the directory gets recreated automatically if it's ever deleted.

> [!Caution]
> Every path the service writes to must be listed, or the write fails silently. `screen`'s socket directory is the most likely thing to break if the `SCREENDIR` override above is skipped - its default location isn't in this sandbox at all.

**Test before trusting this in production:**

    sudo systemctl daemon-reload
    sudo systemctl restart PalWorld.service
    tail -f /home/your_username/logs/palserver_*.log
    sudo systemd-analyze security PalWorld.service

> [!Note]
> `StandardOutput=null` means `journalctl` shows nothing - use the log file above instead.

--------------------------------------------------------------------------------

**References**
- https://developer.valvesoftware.com/wiki/SteamCMD#Linux
- https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
- https://tech.palworldgame.com/settings-and-operation/rest-api/
- https://tech.palworldgame.com/settings-and-operation/configuration/
