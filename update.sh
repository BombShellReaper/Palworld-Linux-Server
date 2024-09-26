#!/bin/bash

# This script will update the server, but you might have to make edits to the dir path

steamcmd +force_install_dir /home/steam/.steam/steamapps/common/PalServer/ +login anonymous +app_update 2394010 validate +quit
