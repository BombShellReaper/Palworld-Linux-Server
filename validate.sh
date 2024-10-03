#!/bin/bash


# This doesn’t verify settings, but confirms that your directories & files exist.




# Function to prompt for user input
prompt_user() {
    local prompt_message="$1"
    read -p "$prompt_message" user_input
    echo "$user_input"
}

stamp="$(date '+%d-%m-%Y %H:%M:%S')"

# Start of the script
echo "Starting Palworld server setup verification..."

# Initialize success flag
success=true 

# Establish the username
username=$(prompt_user "Please enter the username you created: ")
user_home="/home/$username"
echo "User home directory is set to: $user_home."

# Establishing the log directory
logdir=$(prompt_user "Please enter the location of your log directory (relative to the user's home, Example: log): ")
log_dir="$user_home/$logdir"
echo "Log file directory is set to: $log_dir."

# Verify the log directory
if [ -d "$log_dir" ]; then
    echo "The log directory has been verified."
else
    echo "The log directory was not located. Please check the location of your log directory and try again." 
    success=false
    exit 1
fi

# Create the log .txt
log_file="$log_dir/verify.txt"
if [ ! -e "$log_file" ]; then
    touch "$log_file"
    echo "Log file not found. Creating the log file..."
    echo "$stamp" | tee "$log_file"
else 
    echo "The log file already exists." | tee -a "$log_file"
fi

# Validate steam directory 
server_dir="$user_home/Steam/steamapps/common/PalServer"
echo "Checking for server directory at: $server_dir."
if [ -d "$server_dir" ]; then
    echo "Server directory exists."
else
    custom_server_dir=$(prompt_user "If you changed the server directory, please specify the new path (or press Enter to skip): ") 
    if [ -n "$custom_server_dir" ]; then
        server_dir="$custom_server_dir"
        echo "Updated server directory to: $server_dir." | tee -a "$log_file"
    else    
        echo "Could not locate $server_dir, please review (Step 5) in GitHub for proper execution of the instructions." | tee -a "$log_file"
        echo "Server directory does NOT exist. Please review $log_file for instructions." | tee -a "$log_file"
        success=false
        exit 1
    fi
fi

# Check for PalworldSettings.ini file and that it has content
settings_file="$server_dir/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini"
if [ -f "$settings_file" ]; then
    echo "Settings file exists: $settings_file." | tee -a "$log_file"
    if [ -s "$settings_file" ]; then
        echo "Settings file has configs: $settings_file." | tee -a "$log_file"
    else
        echo "Settings file does NOT have any configs: $settings_file. Go back to (Step 6) in GitHub for proper execution of the instructions." | tee -a "$log_file"
        success=false
        exit 1
    fi
else
    echo "Could not locate $settings_file, please review (Step 5) in GitHub for proper execution of the instructions." | tee -a "$log_file"
    echo "Settings file does NOT exist: $settings_file. You may need to create or configure this file." | tee -a "$log_file"
    success=false
    exit 1
fi

# Verify script directory path
startupscript_dir=$(prompt_user "Please enter the location of your script directory (relative to the user's home, Example: script): ")
script_dir="$user_home/$startupscript_dir"
echo "Log script directory is set to: $script_dir."
echo "Checking for startup script directory at: $script_dir" | tee -a "$log_file"
if [ -d "$script_dir" ]; then
    echo "Startup script directory exists." | tee -a "$log_file"
else
    echo "Startup script directory does NOT exist. You may need to create it." | tee -a "$log_file"
    success=false
    exit 1
fi    

# Check for the startup script file and that it has content
startup_script_name=$(prompt_user "Please enter the name of your startup script: ")
startup_script="$script_dir/$startup_script_name"
if [ -f "$startup_script" ]; then
    echo "Startup script exists: $startup_script" | tee -a "$log_file"

    if [ -s "$startup_script" ]; then
        echo "Startup script has configurations.: $startup_script." | tee -a "$log_file"
    else
        echo "Startup script is empty: $startup_script Go back to (Step 7) in GitHub for proper execution of the instructions." | tee -a "$log_file"
        success=false
        exit 1
    fi
else
    echo "Startup script does NOT exist: $startup_script. Go back to (step 7) in GitHub for proper execution of the instructions." | tee -a "$log_file"
    success=false
    exit 1
fi

# Final message
if [ "$success" = true ]; then  
    echo "Congratulations! Everything looks to be in the right place. This doesn’t verify settings, but confirms that your directories & files exist."
    rm "$log_file"
else
    echo "Some checks failed. Please review the log file for details." | tee -a "$log_file"
    exit 1
fi
