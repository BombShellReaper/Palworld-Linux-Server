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

This enables secure remote access to your server.

    sudo apt install openssh-server -y

**Install Steamcmd**

    sudo apt install steamcmd -y

**Install UFW (Uncomplicated Firewall)**

    sudo apt install ufw -y
--------------------------------------------------------------------------------
# Step 3: Configure UFW (Uncomplicated Firewall)

Allow all incoming connections to the game port (adjust 8211 if you use a custom port):

    sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server Port"

> [!TIP]
> For added security, change "any" to a specific IP address or range.

Allow all incoming connections to the query port:

    sudo ufw allow from any proto udp to any port 27015 comment "Palworld Query Port"

> [!TIP]
> For added security, change "any" to a specific IP address or range.

**Allow SSH Connections Through UFW** (Optional)

    sudo ufw allow from any to any port 22 comment "SSH"

> [!TIP]
> For added security, change "any" to a specific IP address or range.

> [!Important]
> Do **not** open the REST API port (default 8212) to the internet. The stop script and update checker in this guide talk to the API over `127.0.0.1` only - there is no reason for it to ever be reachable from outside the box, and exposing it would let anyone who finds the port attempt to authenticate against your AdminPassword directly.

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

Stop the server with Ctrl + C once you see it finish loading. This first run creates `PalWorldSettings.ini` and the default save data - you'll edit that file in the next step, then hand the server off to the automated scripts in Step 7 onward rather than starting it manually again.

--------------------------------------------------------------------------------
# Step 6: Configure the Server

**Edit PalWorldSettings.ini**

    nano /home/your_username/pw_server/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

**Add the following to PalworldSettings.ini**

    [/Script/Pal.PalGameWorldSettings]
    OptionSettings=(Difficulty=None,RandomizerType=None,RandomizerSeed="",bIsRandomizerPalLevelRandom=False,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=1.000000,PalCaptureRate=1.000000,PalSpawnNumRate=1.000000,PalDamageRateAttack=1.000000,PalDamageRateDefense=1.000000,PlayerDamageRateAttack=1.000000,PlayerDamageRateDefense=1.000000,PlayerStomachDecreaceRate=1.000000,PlayerStaminaDecreaceRate=1.000000,PlayerAutoHPRegeneRate=1.000000,PlayerAutoHpRegeneRateInSleep=1.000000,PalStomachDecreaceRate=1.000000,PalStaminaDecreaceRate=1.000000,PalAutoHPRegeneRate=1.000000,PalAutoHpRegeneRateInSleep=1.000000,BuildObjectHpRate=1.000000,BuildObjectDamageRate=1.000000,BuildObjectDeteriorationDamageRate=1.000000,CollectionDropRate=1.000000,CollectionObjectHpRate=1.000000,CollectionObjectRespawnSpeedRate=1.000000,EnemyDropItemRate=1.000000,DeathPenalty=All,bEnablePlayerToPlayerDamage=False,bEnableFriendlyFire=False,bEnableInvaderEnemy=True,bActiveUNKO=False,bEnableAimAssistPad=True,bEnableAimAssistKeyboard=False,DropItemMaxNum=3000,DropItemMaxNum_UNKO=100,BaseCampMaxNum=128,BaseCampWorkerMaxNum=15,DropItemAliveMaxHours=1.000000,bAutoResetGuildNoOnlinePlayers=False,AutoResetGuildTimeNoOnlinePlayers=72.000000,GuildPlayerMaxNum=20,BaseCampMaxNumInGuild=4,PalEggDefaultHatchingTime=72.000000,WorkSpeedRate=1.000000,AutoSaveSpan=30.000000,bIsMultiplay=False,bIsPvP=False,bHardcore=False,bPalLost=False,bCharacterRecreateInHardcore=False,bCanPickupOtherGuildDeathPenaltyDrop=False,bEnableNonLoginPenalty=True,bEnableFastTravel=True,bEnableFastTravelOnlyBaseCamp=False,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bEnableDefenseOtherGuildPlayer=False,bInvisibleOtherGuildBaseCampAreaFX=False,bBuildAreaLimit=False,ItemWeightRate=1.000000,CoopPlayerMaxNum=4,ServerPlayerMaxNum=32,ServerName="Default Palworld Server",ServerDescription="",AdminPassword="",ServerPassword="",bAllowClientMod=True,PublicPort=8211,PublicIP="",RCONEnabled=False,RCONPort=25575,Region="",bUseAuth=True,BanListURL="https://b.palworldgame.com/api/banlist.txt",RESTAPIEnabled=False,RESTAPIPort=8212,bShowPlayerList=False,ChatPostLimitPerMinute=30,CrossplayPlatforms=(Steam,Xbox,PS5,Mac),bIsUseBackupSaveData=True,LogFormatType=Text,bIsShowJoinLeftMessage=True,SupplyDropSpan=180,EnablePredatorBossPal=True,MaxBuildingLimitNum=0,ServerReplicatePawnCullDistance=15000.000000,bAllowGlobalPalboxExport=True,bAllowGlobalPalboxImport=False,EquipmentDurabilityDamageRate=1.000000,ItemContainerForceMarkDirtyInterval=1.000000,ItemCorruptionMultiplier=1.000000,DenyTechnologyList=,GuildRejoinCooldownMinutes=0,BlockRespawnTime=5.000000,RespawnPenaltyDurationThreshold=0.000000,RespawnPenaltyTimeScale=2.000000,bDisplayPvPItemNumOnWorldMap_BaseCamp=False,bDisplayPvPItemNumOnWorldMap_Player=False,AdditionalDropItemWhenPlayerKillingInPvPMode="PlayerDropItem",AdditionalDropItemNumWhenPlayerKillingInPvPMode=1,bAdditionalDropItemWhenPlayerKillingInPvPMode=False,bAllowEnhanceStat_Health=True,bAllowEnhanceStat_Attack=True,bAllowEnhanceStat_Stamina=True,bAllowEnhanceStat_Weight=True,bAllowEnhanceStat_WorkSpeed=True)

> [!TIP]
> Edit the following settings as needed:

ServerName=""

ServerDescription="" (optional)

AdminPassword="" (optional, but **required** if you want RESTAPIEnabled below to actually work - the API uses this as its Basic Auth password)

ServerPassword="" (optional)

PublicIP=""

> [!Important]
> **Set these two explicitly if you plan to use the stop script / update checker in Step 8 and Step 9:**
>
>     RESTAPIEnabled=True
>     RESTAPIPort=8212
>
> The graceful stop script in this guide talks to the server over this REST API (`announce`, `save`, `shutdown`). If it's left at the default `RESTAPIEnabled=False`, the stop script's API calls will fail silently and it will fall back to a hard `SIGINT`/`SIGKILL` on the process instead of a clean shutdown.

> [!Important]
> The file should have two lines and if you use nano it should look something like this.

![image](https://github.com/user-attachments/assets/3efb9777-25d3-49ec-8846-e56372c564f0)

> [!TIP]
> You can also find the PalWorldSettings.ini settings at the following location. Replace *your_username* with the actual username.

    nano /home/your_username/Steam/steamapps/common/PalServer/DefaultPalWorldSettings.ini

**Verify the API is actually reachable before moving on**

Start the server once more, then from another terminal:

    curl -s -u admin:YOUR_ADMIN_PASSWORD http://127.0.0.1:8212/v1/api/info

You should get back a JSON blob with your server name and version. If you get a connection refused, double check `RESTAPIEnabled`/`RESTAPIPort` are set and that you've restarted the server since editing the file.

--------------------------------------------------------------------------------
# Step 7: Create the Start Script

Return to the user's home directory

    cd

Create a directory for your scripts:

    mkdir .scripts

Change to the new directory:

    cd .scripts

Create the start script:

    nano start_server.sh

Copy and edit the following script - update `INSTANCE_NAME`, `SERVER_PORT`, `DIRPATH`, `BACKUP_DIR`, and `LOG_DIR` to match your setup:

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

The server's REST API (enabled in Step 6) is the correct way to shut it down gracefully - it lets you warn players before the server actually goes down and triggers a proper world save, instead of just killing the process.

    nano stop_server.sh

Copy and edit the following - update `API_PASS` to match the `AdminPassword` you set in `PalWorldSettings.ini`, and update paths to match your setup:

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
    except Exception as e:
        print(f'API error on /{endpoint}: {e}')
    "
    }

    {
        find "$LOG_DIR" -name "palserver_stop_*.log" -type f -mtime +30 -exec rm -f {} \;
        log "Stop log rotation check complete."

        if /usr/bin/screen -list | grep -q "\.${INSTANCE_NAME}[[:space:]]"; then
            log "Active ${INSTANCE_NAME} session discovered. Initializing graceful countdown..."

            send_api_cmd "announce" '{"message": "Server shutting down in 5 minutes! Please prepare."}'
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

This periodically checks Steam for a new server version, and if one is found, gracefully stops the server (Step 8), lets systemd (Step 10) bring it back up with the new version, and falls back to starting it manually if systemd doesn't.

    nano update_checker.sh

Copy and edit the following, updating paths and `WEBHOOK_URL` (optional, for Discord alerts) to match your setup:

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
    StartLimitIntervalSec=60
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
> A few things in this unit differ from what you may see in other guides, each for a specific reason:
>
> - **`Type=forking` + `PIDFile=`** (not `Type=simple`): the script launches the real game inside a detached `screen` session and exits itself, so systemd needs to track the actual game PID written to `PIDFile`, not the script's own process.
> - **`ExecStop=` points at `stop_server.sh`**: this is what makes `systemctl stop`/`systemctl restart` trigger the graceful REST API shutdown from Step 8, instead of systemd just sending a raw kill signal to the process group.
> - **`Restart=always`, not `Restart=on-failure`**: `on-failure` does *not* count a clean `SIGINT`-terminated exit as a failure, which is exactly how the stop script's fallback (and Ctrl+C in general) terminates the process. Under `on-failure`, a perfectly normal graceful stop will never trigger systemd's own auto-restart - only `always` restarts regardless of how the process exited.
> - **`RestartSec=60`, `TimeoutStartSec=600`**: sized to give `start_server.sh`'s full backup+update+launch+PID-verify sequence real room to complete before systemd gives up. Treat these as a starting point - once you've watched a real run's timing in your own logs, tighten them to match.
> - **`StartLimitIntervalSec=60` / `StartLimitBurst=3`**: caps systemd to 3 restart attempts in any 60-second window before it gives up and marks the unit `failed`, instead of retrying forever. This is a safety net, not something you should expect to hit during normal operation - a single update cycle only ever counts as one restart.

**Enable and Start the Service**

    sudo systemctl daemon-reload
    sudo systemctl enable PalWorld.service
    sudo systemctl start PalWorld.service

**Confirm it actually started cleanly**

    sudo systemctl status PalWorld.service
    cat /home/your_username/.run/palserver.pid

--------------------------------------------------------------------------------
# Step 11: Create the Host-Level Maintenance Script (Optional)

Steps 7-10 handle the *game* lifecycle - keeping Palworld itself updated. This step handles the *host*: applying OS security patches and rebooting on a schedule, while cleanly stopping and restarting the game around it.

This script needs **root**, since it runs `apt-get` and `reboot` - it does not go in your game user's `.scripts` directory or crontab. Log in as your sudo user for this step.

    sudo nano /usr/local/sbin/palworld_maintenance.sh

Copy and edit the following - update `SERVICE_NAME` and `WEBHOOK_URL` (optional, for Discord alerts) to match your setup:

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
> `apt-get upgrade -s | grep "^Inst"` (a dry-run simulation, checking for lines it would install) is used here deliberately instead of `apt list --upgradable`. `apt-get` has no `list` subcommand at all - that combination silently fails and always reports "no updates," even when real updates are pending. This was caught by comparing the script's output against a manual `apt update` on a live server and finding a mismatch - worth doing that same sanity check yourself after your first run.

**Schedule it via root's crontab** (not your game user's):

    sudo crontab -e

Add a line for whatever time you want maintenance to run (5 AM daily shown below):

    0 5 * * * flock -n /tmp/palworld_maintenance.lock /usr/local/sbin/palworld_maintenance.sh

> [!TIP]
> `flock` here prevents two overlapping runs if a previous maintenance cycle is still finishing (e.g. a slow reboot) when the next scheduled run would otherwise fire.

--------------------------------------------------------------------------------
# Step 12: Hardening (Optional)

Login with the sudo user and edit the sshd_config file

    sudo nano /etc/ssh/sshd_config

Locate the following lines and uncomment them, making the specified edits:

 **#LoginGraceTime 2m**

    LoginGraceTime 1m

 **#PermitRootLogin prohibit-password**

    PermitRootLogin no

 **#MaxSessions 10**

    MaxSessions 4

Reload systemctl & restart sshd.service

    sudo systemctl daemon-reload
    sudo systemctl restart ssh.service

**Example:**

![image](https://github.com/user-attachments/assets/f12f25af-807d-4981-9e53-ebe2ab3d2688)

These are some steps you can take to enhance the security of your SSH service.

# Change Who Can Use the Switch User (su) Command

Make a new group for the su command. Replace "*group_name*" with your desired name for the new group.

    sudo groupadd group_name

> **Example:** *sudo groupadd restrictedsu*

**Edit who can use the *su* command**

Edit the *su* config

    sudo nano /etc/pam.d/su

Edit the following line to restrict su. Replace "*group_name*" with the one you made earlier.

    auth       required   pam_wheel.so group=group_name

> **Example:** *auth       required   pam_wheel.so group=restrictedsu*

**Example:**

![image](https://github.com/user-attachments/assets/3d3c941b-aadd-4bdb-b736-e2fb4c7b5c8b)

> [!TIP]
> If you want to trigger `start_server.sh`/`stop_server.sh` remotely (e.g. from a control panel or automation tool) without giving that system a general-purpose shell, consider a forced-command SSH key restricted to exactly one script (`command="/home/your_username/.scripts/start_server.sh",restrict ssh-ed25519 ...` in `authorized_keys`) instead of a normal login key. This limits what a leaked key could ever be used for, even in the worst case.

**Conclusion**

You have successfully set up a hardened Palworld server with automated backups, graceful updates, and a systemd service that correctly tracks the real game process. For further customization, refer to the game's official documentation.

**References**
- https://developer.valvesoftware.com/wiki/SteamCMD#Linux
- https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
- https://tech.palworldgame.com/settings-and-operation/rest-api/
- https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
- https://tech.palworldgame.com/settings-and-operation/configuration/
