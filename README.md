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

**Install screen (Session Manager)**

    sudo apt install screen -y

**Install OpenSSH Sever**

This will make is so that you can copy the commands into the terminal

    sudo apt install openssh-server -y

**Install Steamcmd**

    sudo apt install steamcmd -y

**Install UFW (Firewall)**

    sudo apt install ufw -y

# Step 3: Configure UFW (Uncomplicated Firewall)

This rule allows all incoming connections to port 8211 on the host machine

    sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server Port"

**Note:** To make this more secure you can change the "any" in "from any" to an IP address or to a range of address.

This rule allows all incoming connections to port 27015 on the host machine

    sudo ufw allow from any proto udp to any port 27015 comment "Palworld Query Port"

**Note:** To make this more secure you can change the "any" in "from any" to an IP address or to a range of address.

**Allow SSH connections through the UFW** (Optional)

    sudo ufw allow from any to any port 22 comment "SSH"

**Note:** To make this more secure you can change the "any" in "from any" to an IP address to a range of address.

Use the default rule to **deny** incoming traffic **(Optional)**

    sudo ufw default deny incoming

**Enable UFW** (UFW will enable on reboot)

    sudo ufw enable
    
--------------------------------------------------------------------------------
# Step 4: Create a non sudo User

Replace your_username with the username you want to create.

    sudo adduser your_user

**Note:** This will prompt you through the setup

**Reboot the system**

    sudo reboot

-------------------------------------------------------------------------------
# Step 5: Install Palworld Server

**Login to your server with the new user account through cmd, powershell, putty, etc. Use what ever terminal emulator you like**

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

**Note:** You can also find the PalWorldSettings.ini settings at the following location.

    nano /home/steam/.steam/steamapps/common/PalServer/DefaultPalWorldSettings.ini

# Step 7: Create a Startup Script (Optional)

Make a directory while logged in as the user you created

    mkdir scripts

Make a script called palworld.sh

    nano palworld.sh

Copy this and edit the locations for the logging and directory path

    #!/bin/bash

    #set -x     # Uncomment to enable debug output. This will show you each command as it’s executed, which can help identify where it fails

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

# Step 8: Create a Systemd Service (Optional)

Switch to your sudo user that you used in the beggining. Make sure to your_username to the user.

    su your_username

**Create the service file**

    sudo nano /etc/systemd/system/PalWorld.service

Add the following configuration

    [Unit]
    Description=Your Application Description
    After=network.target

    [Service]
    Type=simple
    User=youruser         # Example test
    WorkingDirectory=/path/to/your/app       # Example /home/test
    ExecStart=/path/to/your/executable/startup/script      # Example /script/palworld.sh
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

**Conclusion**

You have successfully set up your Palworld server! For further customization, refer to the game’s official documentation.


**References**
- https://developer.valvesoftware.com/wiki/SteamCMD#Linux
- https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
- https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
- https://tech.palworldgame.com/settings-and-operation/configuration/
