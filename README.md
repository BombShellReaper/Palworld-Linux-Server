# Palworld Linux Server Setup Guide

**Overview**

This is a step-by-step guide on how to set up and run a Ubuntu Palworld server.

**Prerequisites**

- Ubuntu server (20.04 or higher recommended)
- Basic knowledge of terminal commands
- A user with sudo privileges

**Disclaimer**

Directory structures may differ based on your specific setup.

# Step 1: Update and Upgrade Your System

    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y

# Step 2: Install Required Dependencies

    sudo add-apt-repository multiverse -y
    sudo dpkg --add-architecture i386
    sudo apt update

**Install Screen (Session Manager)**

    sudo apt install screen -y

**Install OpenSSH Sever**

This enables secure remote access to your server.

    sudo apt install openssh-server -y

**Install Steamcmd**

    sudo apt install steamcmd -y

**Install UFW (Uncomplicated Firewall)**

    sudo apt install ufw -y

# Step 3: Configure UFW (Uncomplicated Firewall)

Allow all incoming connections to port 8211:

    sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server Port"

**Note:** For added security, change "any" to a specific IP address or range.

Allow all incoming connections to port 27015:

    sudo ufw allow from any proto udp to any port 27015 comment "Palworld Query Port"

**Note:** For added security, change "any" to a specific IP address or range.

**Allow SSH Connections Through UFW** (Optional)

    sudo ufw allow from any to any port 22 comment "SSH"

**Note:** For added security, change "any" to a specific IP address or range.

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

**Note:** This will prompt you through the setup

**Reboot the system**

    sudo reboot

-------------------------------------------------------------------------------
# Step 5: Install Palworld Server

**Log in to your server with the new user account through cmd, PowerShell, PuTTY, etc. Use your preferred terminal emulator.**

**Install Palworld Server Files**

    steamcmd +login anonymous +app_update 2394010 validate +quit

**Navigate to the Server Directory**

    cd Steam/steamapps/common/PalServer

**Start the server**

    ./PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS

Stop the server with Ctrl + C.

# Step 6: Configure the Server

**Edit PalWorldSettings.ini**

    nano Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

**Add the following to PalworldSettings.ini**

    [/Script/Pal.PalGameWorldSettings]
    OptionSettings=(Difficulty=None,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=1.000000,PalCaptureRate=1.000000,PalSpawnNumRate=1.000000,PalDamageRateAttack=1.000000,PalDamageRateDefense=1.000000,PlayerDamageRateAttack=1.000000,PlayerDamageRateDefense=1.000000,PlayerStomachDecreaceRate=1.000000,PlayerStaminaDecreaceRate=1.000000,PlayerAutoHPRegeneRate=1.000000,PlayerAutoHpRegeneRateInSleep=1.000000,PalStomachDecreaceRate=1.000000,PalStaminaDecreaceRate=1.000000,PalAutoHPRegeneRate=1.000000,PalAutoHpRegeneRateInSleep=1.000000,BuildObjectDamageRate=1.000000,BuildObjectDeteriorationDamageRate=1.000000,CollectionDropRate=1.000000,CollectionObjectHpRate=1.000000,CollectionObjectRespawnSpeedRate=1.000000,EnemyDropItemRate=1.000000,DeathPenalty=All,bEnablePlayerToPlayerDamage=False,bEnableFriendlyFire=False,bEnableInvaderEnemy=True,bActiveUNKO=False,bEnableAimAssistPad=True,bEnableAimAssistKeyboard=False,DropItemMaxNum=3000,DropItemMaxNum_UNKO=100,BaseCampMaxNum=128,BaseCampWorkerMaxNum=15,DropItemAliveMaxHours=1.000000,bAutoResetGuildNoOnlinePlayers=False,AutoResetGuildTimeNoOnlinePlayers=72.000000,GuildPlayerMaxNum=20,BaseCampMaxNumInGuild=4,PalEggDefaultHatchingTime=72.000000,WorkSpeedRate=1.000000,AutoSaveSpan=30.000000,bIsMultiplay=False,bIsPvP=False,bCanPickupOtherGuildDeathPenaltyDrop=False,bEnableNonLoginPenalty=True,bEnableFastTravel=True,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bEnableDefenseOtherGuildPlayer=False,bInvisibleOtherGuildBaseCampAreaFX=False,CoopPlayerMaxNum=4,ServerPlayerMaxNum=32,ServerName="Default Palworld Server",ServerDescription="",AdminPassword="",ServerPassword="",PublicPort=8211,PublicIP="",RCONEnabled=False,RCONPort=25575,Region="",bUseAuth=True,BanListURL="https://api.palworldgame.com/api/banlist.txt",RESTAPIEnabled=False,RESTAPIPort=8212,bShowPlayerList=False,AllowConnectPlatform=Steam,bIsUseBackupSaveData=True,LogFormatType=Text,SupplyDropSpan=180)

**Notice:** Edit the following settings as needed:

ServerName=""

ServerDescription="" (optional)

AdminPassword="" (optional)

ServerPassword="" (optional)

PublicIP=""

**Notice:** The file should have two lines and if you use nano it should look something like this.

![image](https://github.com/user-attachments/assets/3efb9777-25d3-49ec-8846-e56372c564f0)

**Note:** You can also find the PalWorldSettings.ini settings at the following location. Replace *your_username* with the actual username.

    nano /home/your_username/Steam/steamapps/common/PalServer/DefaultPalWorldSettings.ini

# Step 7: Create a Startup Script (Optional)

Return to the users home directory

    cd

Create a directory to place you scripts. Change the "*name*" with the desired username:

    mkdir name

Change to the new directory. Change the "*name*" with the one you just created:

    cd name

Create a script called palworld.sh:

    nano palworld.sh

Copy and edit the following script:

    #!/bin/bash

    #set -x     # Uncomment to enable debug output. This will show you each command as it’s executed, which can help identify where it fails

    # Log file
    LOGFILE="/path/to/your/logfile.txt"  # Update with your log file path
    DIRPATH="/path/to/your/server" # Update with the directory containing PalServer.sh

    # Create the log directory if it doesn't exist
    LOGDIR=$(dirname "$LOGFILE")
    mkdir -p "$LOGDIR"

    # Create the log file if it doesn't exist
    touch "$LOGFILE"

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

Make the script executable by the user:

    chmod u+x palworld.sh

# Step 8: Create a Systemd Service (Optional)

Switch to your sudo user that you used at the beginning. Replace "*your_username*" with the actual username.

    su your_username

**Create the service file:**

    sudo nano /etc/systemd/system/PalWorld.service

**Add the following configuration:**

    [Unit]
    Description=Your Application Description
    After=network.target

    [Service]
    Type=simple
    User=youruser         # Replace with your username
    ExecStart=/path/to/your/executable/startup/script.sh      # Replace with your full script path
    RemainAfterExit=yes
    Restart=on-failure
    RestartSec=5
    StandardOutput=append:/var/log/yourapp.log
    StandardError=append:/var/log/yourapp.log

    [Install]
    WantedBy=multi-user.target

**Enable and Start the Service**

    sudo systemctl daemon-reload
    sudo systemctl enable PalWorld.service
    sudo systemctl start PalWorld.service

# Step 9: Hardening (Optional)

Login with the sudo sure and edit the sshd_config file

    sudo nano /etc/ssh/sshd_config

Fine the following lines and uncomment them with these edits

 **#LoginGraceTime 2m**

    LoginGraceTime 1m

 **#PermitRootLogin prohibit-password**

    PermitRootLogin no

 **#MaxSessions 10**

    Max Sessions 4

Reload systemctl & restart sshd.services

    sudo systemctl daemon-reload
    sudo systemctl restart sshd.service

**Example:**

![image](https://github.com/user-attachments/assets/f12f25af-807d-4981-9e53-ebe2ab3d2688)

These are some of the measures you can take harden your ssh service.

# Change Who Can Use The Switch User (su) Command

Make a new group for the su command. Replace "*group_name*" with your desired name for the new group.

    sudo groupadd group_name

**Example:** sudo groupadd restrictedsu

**Edit who can use the *su* command**

Edit the *su* config

    sudo nano /etc/pam.d/su

Edit the following line to restrict su. Replace "*group_name*" with the one you made ealier.

    auth       required   pam_wheel.so group=group_name

**Example:** auth       required   pam_wheel.so group=restrictedsu

**Example:** 

![image](https://github.com/user-attachments/assets/3d3c941b-aadd-4bdb-b736-e2fb4c7b5c8b)


**Conclusion**

You have successfully set up your Palworld server! For further customization, refer to the game’s official documentation.


**References**
- https://developer.valvesoftware.com/wiki/SteamCMD#Linux
- https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
- https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
- https://tech.palworldgame.com/settings-and-operation/configuration/
