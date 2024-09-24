# Palworld server
This is the step-by-step on how to setup and run a Ubuntu Palworld server.
# Update-Upgrade-Clean_up
    sudo apt update
    sudo apt full-upgrade -y
    sudo apt autoremove -y
or

    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y

# Dependencies
    sudo add-apt-repository multiverse
    sudo dpkg --add-architecture i386; sudo apt update
# Install screen
    sudo apt install screen -Y
# Update
    sudo apt update
# Install Steamcmd
    sudo apt install steamcmd -y
# Install UFW (Firewall)
    sudo apt install ufw -y
# UFW allow server port & server Query Port
    sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server Port"
Note: **To make this more secure you can change the "any" in "from any" to an IP address or to a range of address**

    sudo ufw allow from any proto udp to any port 27015 comment "Palworld Query Port"

**Note:** To make this more secure you can change the "any" in "from any" to an IP address or to a range of address
# Allow SSH connections through the UFW (Optional)
    sudo ufw allow from any to any port 22 comment "SSH"

**Note:** To make this more secure you can change the "any" in "from any" to an IP address to a range of address
# Enable UFW (UFW will enable on reboot)
    sudo ufw enable
--------------------------------------------------------------------------------
# Make a steam user (Two Options)
    sudo useradd -m steam

    sudo passwd steam

or

    sudo adduser steam 
This will prompt you through the set-up
-------------------------------------------------------------------------------
# Switch to the steam user
    su steam
# Move to the steam home dir
    cd /home/steam
# Install all the needed files
    /usr/games/steamcmd +login anonymous +app_update 2394010 validate +quit
# CD to PalServer sub dir
    cd .steam/steam/steamapps/common/PalServer
# Run the server to create the server files
    ./PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
# Stop the server
Press "**Ctrl**" & "**C**" on your keyboard at the same time.
# Edit the PalWorldSettings.ini
    nano Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
**ADD THE FOLLOWING TO THE FILE**

    [/Script/Pal.PalGameWorldSettings]
    OptionSettings=(Difficulty=None,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=1.000000,PalCaptureRate=1.000000,PalSpawnNumRate=1.000000,PalDamageRateAttack=1.000000,PalDamageRateDefense=1.000000,PlayerDamageRateAttack=1.000000,PlayerDamageRateDefense=1.000000,PlayerStomachDecreaceRate=1.000000,PlayerStaminaDecreaceRate=1.000000,PlayerAutoHPRegeneRate=1.000000,PlayerAutoHpRegeneRateInSleep=1.000000,PalStomachDecreaceRate=1.000000,PalStaminaDecreaceRate=1.000000,PalAutoHPRegeneRate=1.000000,PalAutoHpRegeneRateInSleep=1.000000,BuildObjectDamageRate=1.000000,BuildObjectDeteriorationDamageRate=1.000000,CollectionDropRate=1.000000,CollectionObjectHpRate=1.000000,CollectionObjectRespawnSpeedRate=1.000000,EnemyDropItemRate=1.000000,DeathPenalty=All,bEnablePlayerToPlayerDamage=False,bEnableFriendlyFire=False,bEnableInvaderEnemy=True,bActiveUNKO=False,bEnableAimAssistPad=True,bEnableAimAssistKeyboard=False,DropItemMaxNum=3000,DropItemMaxNum_UNKO=100,BaseCampMaxNum=128,BaseCampWorkerMaxNum=15,DropItemAliveMaxHours=1.000000,bAutoResetGuildNoOnlinePlayers=False,AutoResetGuildTimeNoOnlinePlayers=72.000000,GuildPlayerMaxNum=20,BaseCampMaxNumInGuild=4,PalEggDefaultHatchingTime=72.000000,WorkSpeedRate=1.000000,AutoSaveSpan=30.000000,bIsMultiplay=False,bIsPvP=False,bCanPickupOtherGuildDeathPenaltyDrop=False,bEnableNonLoginPenalty=True,bEnableFastTravel=True,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bEnableDefenseOtherGuildPlayer=False,bInvisibleOtherGuildBaseCampAreaFX=False,CoopPlayerMaxNum=4,ServerPlayerMaxNum=32,ServerName="Default Palworld Server",ServerDescription="",AdminPassword="",ServerPassword="",PublicPort=8211,PublicIP="",RCONEnabled=False,RCONPort=25575,Region="",bUseAuth=True,BanListURL="https://api.palworldgame.com/api/banlist.txt",RESTAPIEnabled=False,RESTAPIPort=8212,bShowPlayerList=False,AllowConnectPlatform=Steam,bIsUseBackupSaveData=True,LogFormatType=Text,SupplyDropSpan=180)

**Notice:** There are settings from above that you need to edit: ServerName="", ServerDescription="" (this is optional), AdminPassword="" (this is optional), ServerPassword="" (this is optional), and PublicIP="". You can edit more settings here, but these are the ones I recommend starting with.

**Notice:** The file should have two lines and if you use nano it should look something like this

![image](https://github.com/user-attachments/assets/d70a4090-249a-4c59-9c3c-325a78cc7644)

**Note:** You can also fine the PalWorldSettings.ini settings located here

    nano /home/steam/.steam/steamapps/common/PalServer/DefaultPalWorldSettings.ini










-------------------------------------------------------------------------------
# References
1.     https://developer.valvesoftware.com/wiki/SteamCMD#Linux
2.     https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
3.     https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
4.     https://tech.palworldgame.com/settings-and-operation/configuration/
5. My personal experiences/knowledge 
