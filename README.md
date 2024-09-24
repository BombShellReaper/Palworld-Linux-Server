# Palworld server
This is the step-by-step on how to setup and run a Ubuntu Palworld server.
# Update-Upgrade-Clean_up
sudo apt update

sudo apt full-upgrade -y

sudo apt autoremove -y
# Dependencies
sudo add-apt-repository multiverse 
sudo dpkg --add-architecture i386; sudo apt update
# Install screen
sudo apt install screen
# Update
sudo apt update
# Install Steamcmd
sudo apt install steamcmd -y
# Install UFW (Firewall)
sudo apt install ufw -y
# UFW allow server port & server Query Port
sudo ufw allow from any proto udp to any port 8211 comment "Palworld Server port"

sudo ufw allow from any proto udp to any port 27015/udp comment "Palworld Query port"
# Allow SSH connections through the UFW (Optional)
sudo ufw allow ssh



--------------------------------------------------------------------------------

# Make a steam user
sudo useradd -m steam

sudo passwd steam

or

sudo adduser steam (This will prompt you through the set-up)

-------------------------------------------------------------------------------

# References
1. https://developer.valvesoftware.com/wiki/SteamCMD#Linux
2. https://tech.palworldgame.com/getting-started/deploy-dedicated-server/
3. My personal experiences/knowledge 
