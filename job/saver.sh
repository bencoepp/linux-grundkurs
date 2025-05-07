#!/bin/bash

# Directory where backups will be saved
BACKUP_DIR="/var/saver"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Loop through each directory in /home
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")
        archive_name="${BACKUP_DIR}/${username}_home_$(date +%F).tar.gz"
        tar -czf "$archive_name" -C /home "$username"
    fi
done