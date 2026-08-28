![Build Status](https://img.shields.io/badge/Dedicated_Server-Linux-green)
![Palworld](https://img.shields.io/badge/Palworld-8A2BE2)
![Steam](https://img.shields.io/badge/Steam-8A2BE2)
# Palworld Linux Server Setup Guide

Step-by-step guide to set up a Ubuntu Palworld server with automated backups, updates, graceful shutdown, and a systemd unit that tracks the real game process.

**Prerequisites**

- Ubuntu server (20.04+)
- A user with sudo privileges

> [!Caution]
> Paths below assume user `steam` and install directory `/home/steam/pw_server` - adjust to match your setup.

--------------------------------------------------------------------------------
# Step 1: Update and Upgrade Your System

    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y

--------------------------------------------------------------------------------
# Step 2: Install Required Dependencies

    sudo add-apt-repository multiverse -y
    sudo dpkg --add-architecture i386
    sudo apt update
    sudo apt install screen openssh-server steamcmd ufw -y

--------------------------------------------------------------------------------
# Step 3: Configure UFW

    sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server Port"
    sudo ufw allow from any proto udp to any port 27015 comment "Palworld Query Port"
    sudo ufw allow from any to any port 22 comment "SSH"
    sudo ufw default deny incoming
    sudo ufw enable
    sudo ufw status

> [!Important]
> Do not open the REST API port (8212) to the internet - it's only ever accessed over `127.0.0.1`.

--------------------------------------------------------------------------------
# Step 4: Create a Non Sudo User

    sudo adduser your_username
    sudo reboot

--------------------------------------------------------------------------------
# Step 5: Install Palworld Server

    steamcmd +force_install_dir /home/your_username/pw_server +login anonymous +app_update 2394010 validate +quit
    cd pw_server
    ./PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS

Stop with `Ctrl+C` once loaded. This generates `Pal/Saved/Config/LinuxServer/`, `DefaultPalWorldSettings.ini`, and default save data.

--------------------------------------------------------------------------------
# Step 6: Configure the Server

> [!Important]
> Do this with the server **stopped** - it holds config in memory and overwrites the file on exit.

**Copy the default config as your baseline:**

    cp /home/your_username/pw_server/DefaultPalWorldSettings.ini \
       /home/your_username/pw_server/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

> [!Caution]
> Editing `DefaultPalWorldSettings.ini` directly does nothing - always edit the copy. Re-running this `cp` on a live server overwrites your custom settings; your `start_server.sh` backups (Step 7) already include `Config/` if you need to restore.

**Set the required values:**

    CONFIG="/home/your_username/pw_server/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini"
    sed_escape() { printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g'; }
    SERVER_NAME_ESCAPED=$(sed_escape "Your Server Name")
    ADMIN_PASSWORD_ESCAPED=$(sed_escape "your_admin_password")

    sed -i "s/ServerName=\"[^\"]*\"/ServerName=\"$SERVER_NAME_ESCAPED\"/" "$CONFIG"
    sed -i "s/AdminPassword=\"[^\"]*\"/AdminPassword=\"$ADMIN_PASSWORD_ESCAPED\"/" "$CONFIG"
    sed -i 's/RESTAPIEnabled=False/RESTAPIEnabled=True/' "$CONFIG"

> [!Important]
> `AdminPassword` and `RESTAPIEnabled=True` are required for the stop script/update checker to work. Without them, graceful shutdown fails silently and falls back to `SIGKILL`.

**Verify the API works:**

    curl -s -u admin:YOUR_ADMIN_PASSWORD http://127.0.0.1:8212/v1/api/info

Should return a JSON blob with server name/version.

--------------------------------------------------------------------------------
# Step 7: Create the Start Script

    cd
    mkdir .scripts
    cd .scripts
    nano start_server.sh

Update `INSTANCE_NAME`, `SERVER_PORT`, `DIRPATH`, `BACKUP_DIR`, `LOG_DIR` to match your setup:

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

    PID_DIR="/home/your_username/.run"
    PID_FILE="$PID_DIR/palserver.pid"
    GAME_PROCESS_NAME="PalServer-Linux-Shipping"

    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$PID_DIR"

    LOCK_DIR="/home/your_username/.flock"
    LOCK_FILE="$LOCK_DIR/start_server.lock"
    mkdir -p "$LOCK_DIR"

    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Another instance already running. Exiting cleanly."
        exit 0
    fi

    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    }

    {
        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "'${INSTANCE_NAME}' is already running. Nothing to do."
            exit 0
        fi

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

        find "$BACKUP_DIR" -name "palserver_backup_*.tar.gz" -type f -mtime +30 -exec rm -f {} \;
        find "$LOG_DIR" -name "palserver_*.log" -type f -mtime +30 -exec rm -f {} \;

        log "Updating Palworld Server..."
        if /usr/games/steamcmd +force_install_dir "$DIRPATH" +login "$STEAMUSERNAME" +app_update 2394010 validate +quit; then
            log "Update completed successfully."
        else
            log "Critical Error: SteamCMD update failed. Aborting."
            exit 1
        fi

        log "Starting Palworld server inside Screen session on port $SERVER_PORT..."
        /usr/bin/screen -dmS "$INSTANCE_NAME" "$DIRPATH/PalServer.sh" -port="$SERVER_PORT" -publicport="$SERVER_PORT" -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -PublicLobby

        sleep 5

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Screen session is alive. Verifying the actual game process next..."
        else
            log "Critical Error: Failed to start Palworld screen session."
            exit 1
        fi

        log "Waiting for $GAME_PROCESS_NAME to confirm the server actually started..."
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
            log "Critical Error: $GAME_PROCESS_NAME never appeared after ${PID_WAIT_MAX}s."
            exit 1
        fi
    } 2>&1 | tee -a "$LOGFILE"

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

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Active ${INSTANCE_NAME} session discovered. Initializing graceful countdown..."

            FIRST_API_RESULT=$(send_api_cmd "announce" '{"message": "Server shutting down in 5 minutes! Please prepare."}')
            if echo "$FIRST_API_RESULT" | grep -q "API_AUTH_FAILED"; then
                log "CRITICAL: REST API unreachable or authentication failed (check RESTAPIEnabled/AdminPassword). Going straight to signal-based termination."
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

            SHUTDOWN_WAIT_MAX=45
            SHUTDOWN_WAIT_COUNT=0
            while pgrep -f "$GAME_PROCESS_NAME" > /dev/null && [ $SHUTDOWN_WAIT_COUNT -lt $SHUTDOWN_WAIT_MAX ]; do
                sleep 1
                ((SHUTDOWN_WAIT_COUNT++))
            done

            SERVER_PID=$(pgrep -f "$GAME_PROCESS_NAME")
            if [ -n "$SERVER_PID" ]; then
                log "Process still alive after API shutdown (${SHUTDOWN_WAIT_COUNT}s). Sending SIGINT to PID $SERVER_PID..."
                kill -SIGINT "$SERVER_PID"
                sleep 15
                if kill -0 "$SERVER_PID" 2>/dev/null; then
                    log "Still running after SIGINT. Force killing as last resort."
                    kill -9 "$SERVER_PID"
                else
                    log "Process exited cleanly after SIGINT fallback."
                fi
            else
                log "Process exited cleanly after API shutdown (${SHUTDOWN_WAIT_COUNT}s)."
            fi

            if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
                /usr/bin/screen -S "$INSTANCE_NAME" -X quit
            fi

            [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
            log "Palworld engine instance safely terminated."
        else
            log "No active server screen found. Lifecycle step skipped."
        fi
    } 2>&1 | tee -a "$LOGFILE"

    chmod u+x stop_server.sh

--------------------------------------------------------------------------------
# Step 9: Create an Automated Update Checker (Optional)

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
        find "$LOG_DIR" -name "palserver_update_*.log" -type f -mtime +3 -exec rm -f {} \;

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

            POLL_COUNT=0
            while ! screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]" && [ $POLL_COUNT -lt $RESTART_POLL_MAX_WAIT ]; do
                sleep 2
                ((POLL_COUNT++))
            done

            if screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
                log "$(date +'%Y-%m-%d %H:%M:%S') Systemd auto-restart succeeded — server back online after $((POLL_COUNT*2))s."
            else
                log "$(date +'%Y-%m-%d %H:%M:%S') WARNING: No screen session detected. Falling back to manual start..."
                send_discord_message "Maintenance Failed: Systemd auto-restart did not bring $GAME_NAME back — falling back to manual start."
                bash "$START_SCRIPT"
                sleep 5
                if screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
                    log "$(date +'%Y-%m-%d %H:%M:%S') Manual fallback start succeeded."
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

    chmod u+x update_checker.sh
    crontab -e

Add:

    */30 * * * * flock -n /home/your_username/.flock/update_checker.lock /home/your_username/.scripts/update_checker.sh

--------------------------------------------------------------------------------
# Step 10: Create a Systemd Service

    sudo nano /etc/systemd/system/PalWorld.service

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

> [!Important]
> - Use `Restart=always`, not `on-failure` - `on-failure` doesn't treat a `SIGINT`-terminated exit (the stop script's fallback) as a failure, so it can silently skip auto-restart.
> - `StandardOutput=null`/`StandardError=null` means `journalctl` shows nothing - use the log files instead.
> - `TimeoutStartSec`/`TimeoutStopSec`/`RestartSec` are starting points - tighten once you've measured real timing from your own logs.

    sudo systemctl daemon-reload
    sudo systemctl enable PalWorld.service
    sudo systemctl start PalWorld.service
    sudo systemctl status PalWorld.service
    cat /home/your_username/.run/palserver.pid

--------------------------------------------------------------------------------
# Step 11: Create the Host-Level Maintenance Script (Optional)

Handles OS patching and daily reboot. Needs root.

    sudo nano /usr/local/sbin/palworld_maintenance.sh

    #!/bin/bash

    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

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

    exec > >(tee -a "$LOGFILE") 2>&1

    echo "=============================================================================="
    echo "$(date +'%Y-%m-%d %H:%M:%S') --- Starting Palworld Maintenance Sequence ---"

    send_discord_message "Maintenance Started: Stopping the Palworld server via systemd..."
    if systemctl stop "$SERVICE_NAME"; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') $SERVICE_NAME stopped successfully."
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') WARNING: systemctl stop reported a non-zero exit for $SERVICE_NAME."
    fi

    apt-get update > /dev/null

    if apt-get upgrade -s 2>/dev/null | grep -q "^Inst"; then
        send_discord_message "Updates Found. Applying system patches..."
        DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" -y full-upgrade
        apt-get autoremove -y
        echo "$(date +'%Y-%m-%d %H:%M:%S') OS updates applied successfully."
    else
        send_discord_message "No updates found. System is clean."
        echo "$(date +'%Y-%m-%d %H:%M:%S') No OS updates found."
    fi

    send_discord_message "Maintenance Complete: Rebooting server host."
    sync
    sleep 10
    reboot

> [!Note]
> `apt-get upgrade -s | grep "^Inst"` is used instead of `apt-get list --upgradable` - the latter isn't a valid `apt-get` subcommand and silently reports no updates.

    sudo chmod +x /usr/local/sbin/palworld_maintenance.sh
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
> For remote triggers (control panels, automation), use a forced-command SSH key restricted to one script (`command="/home/your_username/.scripts/start_server.sh",restrict ssh-ed25519 ...`) instead of a normal login key.

**Lock down the scripts:**

    sudo chown root:your_username /home/your_username/.scripts
    sudo chmod 750 /home/your_username/.scripts
    sudo chown root:your_username /home/your_username/.scripts/*.sh
    sudo chmod 750 /home/your_username/.scripts/*.sh

> [!Caution]
> This prevents tampering, not credential exposure - `your_username` (same account the game runs as) can still read `API_PASS` in plaintext via group access.

**Sandbox the systemd service** - add under `[Service]` in Step 10's unit:

    Environment="SCREENDIR=/home/your_username/.screen"
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

    mkdir -p /home/your_username/.screen
    chmod 700 /home/your_username/.screen

> [!Caution]
> Every path the service writes to must be listed, or the write fails silently. `screen`'s socket directory is the most likely thing to break if the `SCREENDIR` override above is skipped.

**Test before trusting this in production:**

    sudo systemctl daemon-reload
    sudo systemctl restart PalWorld.service
    tail -f /home/your_username/logs/palserver_*.log
    sudo systemd-analyze security PalWorld.service

--------------------------------------------------------------------------------

**References**
- https://developer.valvesoftware.com/wiki/SteamCMD#Linux
- https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
- https://tech.palworldgame.com/settings-and-operation/rest-api/
- https://tech.palworldgame.com/settings-and-operation/configuration/
