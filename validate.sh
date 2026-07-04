#!/bin/bash

# ==============================================================================
#                 PALWORLD INFRASTRUCTURE VALIDATION UTILITY
# ==============================================================================
# AUTHOR: BombShellReaper
# REPO: https://github.com/BombShellReaper/Palworld-Linux-Server
# ==============================================================================

# Function to prompt for user input
prompt_user() {
    local prompt_message="$1"
    read -p "$prompt_message" user_input
    echo "$user_input"
}

stamp="$(date '+%d-%m-%Y %H:%M:%S')"

echo "========================================================================"
echo "Starting BombShellReaper Palworld Server Architecture Verification..."
echo "========================================================================"

# Initialize overall master status metrics tracking flag
success=true 

# --- STEP 1: USER CONTEXT INGESTION ---
username=$(prompt_user "Please enter the non-sudo username you created: ")
user_home="/home/$username"

if [ ! -d "$user_home" ]; then
    echo "❌ CRITICAL: The user home directory [$user_home] does not exist on this OS."
    exit 1
fi
echo "User home directory verified at: $user_home."

# --- STEP 2: LOG ENVIRONMENT TRACE MAPPING ---
logdir=$(prompt_user "Please enter the location of your log directory (relative to user home, e.g., logs): ")
log_dir="$user_home/$logdir"

if [ -d "$log_dir" ]; then
    echo "✅ The log directory has been verified."
else
    echo "❌ ERROR: The log directory was not located at: $log_dir"
    success=false
fi

# Initialize runtime tracking audit file
log_file="$log_dir/verify.txt"
if [ "$success" = true ]; then
    touch "$log_file"
    echo "=========================================" > "$log_file"
    echo "Palworld Verification Audit: $stamp" >> "$log_file"
    echo "=========================================" >> "$log_file"
fi

# --- STEP 3: REPO ALIGNED SERVER DIRECTORY VALIDATION ---
# Base template defaults straight to your Step 5 'pw_server' layout configuration
server_dir="$user_home/pw_server"
echo "Checking for server installation directory at: $server_dir..."

if [ -d "$server_dir" ]; then
    echo "✅ Server directory verified." | tee -a "$log_file"
else
    echo "⚠️ NOTICE: Default folder structure not found at $server_dir"
    custom_server_dir=$(prompt_user "If you changed the destination path, enter the custom path (or hit Enter to skip): ") 
    if [ -n "$custom_server_dir" ] && [ -d "$custom_server_dir" ]; then
        server_dir="$custom_server_dir"
        echo "✅ Updated server directory target to: $server_dir" | tee -a "$log_file"
    else    
        echo "❌ CRITICAL: Could not locate server path. Please review (Step 5) in GitHub." | tee -a "$log_file"
        success=false
    fi
fi

# --- STEP 4: CONFIGURATION LAYER INTEGRITY CHECK ---
if [ "$success" = true ]; then
    settings_file="$server_dir/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini"
    if [ -f "$settings_file" ]; then
        if [ -s "$settings_file" ]; then
            echo "✅ Settings file exists and has data: $settings_file" | tee -a "$log_file"
        else
            echo "❌ ERROR: PalWorldSettings.ini exists but is completely empty. Review (Step 6) on GitHub." | tee -a "$log_file"
            success=false
        fi
    else
        echo "❌ ERROR: Could not locate $settings_file. File configuration layer is missing." | tee -a "$log_file"
        success=false
    fi
fi

# --- STEP 5: AUTOMATION SCRIPT TRACKING ---
scriptdir=$(prompt_user "Please enter the location of your script directory (relative to user home, e.g., name): ")
script_dir="$user_home/$scriptdir"

echo "Checking automation directory at: $script_dir..." | tee -a "$log_file"
if [ -d "$script_dir" ]; then
    echo "✅ Startup script directory exists." | tee -a "$log_file"
    
    # Check for the Startup Script (palworld.sh)
    startup_script_name=$(prompt_user "Please enter the name of your startup script (e.g., palworld.sh): ")
    startup_script="$script_dir/$startup_script_name"
    if [ -f "$startup_script" ] && [ -s "$startup_script" ]; then
        echo "✅ Startup script verified: $startup_script" | tee -a "$log_file"
    else
        echo "❌ ERROR: Startup script is missing or empty. Review (Step 7) on GitHub." | tee -a "$log_file"
        success=false
    fi

    # Check for the Graceful Shutdown Script (palworld_stop.sh)
    shutdown_script="$script_dir/palworld_stop.sh"
    if [ -f "$shutdown_script" ] && [ -s "$shutdown_script" ]; then
        echo "✅ Graceful shutdown script verified: $shutdown_script" | tee -a "$log_file"
    else
        echo "⚠️ WARNING: palworld_stop.sh was not found. Advanced grace routines disabled." | tee -a "$log_file"
    fi
else
    echo "❌ ERROR: Startup script directory does not exist. Review (Step 7) on GitHub." | tee -a "$log_file"
    success=false
fi    

# --- STEP 6: SYSTEMD SERVICE INTEGRITY CHECK ---
service_file="/etc/systemd/system/PalWorld.service"
echo "Scanning for system orchestration layers..." | tee -a "$log_file"
if [ -f "$service_file" ]; then
    echo "✅ Advanced Systemd Service Unit detected: $service_file" | tee -a "$log_file"
else
    echo "ℹ️ Systemd configuration skipped. Service file not deployed to the OS." | tee -a "$log_file"
fi

# ==============================================================================
#                             FINAL AUDIT REPORT
# ==============================================================================
echo "========================================================================"
if [ "$success" = true ]; then  
    echo "🎉 CONGRATULATIONS! Your directory structures and file targets match perfectly."
    echo "Your deployment environment matches the BombShellReaper repository standard."
    [ -f "$log_file" ] && rm "$log_file"
else
    echo "❌ AUTOMATION AUDIT FAILED."
    echo "Some required infrastructure boundaries are misaligned."
    echo "Please run: 'cat $log_file' to review the targeted instructions for repair."
    exit 1
fi
echo "========================================================================"
