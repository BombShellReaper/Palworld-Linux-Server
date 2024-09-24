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

Note: **To make this more secure you can change the "any" in "from any" to an IP address or to a range of address**
# Allow SSH connections through the UFW (Optional)
    sudo ufw allow from any to any port 22 comment "SSH"

Note: **To make this more secure you can change the "any" in "from any" to an IP address to a range of address**
# Enable UFW (UFW will enable on reboot)
    sudo ufw enable
--------------------------------------------------------------------------------
# Make a steam user (Two options on how to complete this)
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
# Edit the PalWorldSettings.ini **(or)** cat the info
    nano Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
**ADD THE FOLLOWING TO THE FILE**

or

    cat 







-------------------------------------------------------------------------------
# References
1.     https://developer.valvesoftware.com/wiki/SteamCMD#Linux
2.     https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
3.     https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
4. My personal experiences/knowledge 
