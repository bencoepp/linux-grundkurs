#!/bin/bash

# Configuration
LOG_DIR="/var/log/logger"
INTERVAL_BETWEEN_LOGS=5         # seconds
INTERVAL_BETWEEN_FILES=180      # seconds (3 minutes)

mkdir -p "$LOG_DIR"

while true; do
    FILE_NAME="log_$(date +'%Y%m%d_%H%M%S').log"
    FILE_PATH="$LOG_DIR/$FILE_NAME"
    echo "[INFO] Creating new log file: $FILE_PATH"

    START_TIME=$(date +%s)

    while [ $(($(date +%s) - START_TIME)) -lt $INTERVAL_BETWEEN_FILES ]; do
        echo "$(date +'%Y-%m-%d %H:%M:%S') - INFO - Sample log message" >> "$FILE_PATH"
        sleep $INTERVAL_BETWEEN_LOGS
    done
done
