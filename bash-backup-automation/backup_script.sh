
#!/bin/bash

# Check if log file parameter is provided
if [ -z "$1" ]; then
    echo "You have failed to pass a log file parameter. Please try again."
    exit 255
fi

# Set variables
MYLOG=$1
SOURCE_DIR="/home/$USER/work"
BACKUP_DIR="/home/$USER/work_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_ARCHIVE="/home/$USER/work_backup_$TIMESTAMP.tar.gz"

# Ctrl+C handler function
function ctrlc {
    log "Received Ctrl+C. Cleaning up..."
    rm -rf $BACKUP_DIR
    log "Backup directory removed: $BACKUP_DIR"
    exit 255
}

# Set trap for Ctrl+C
trap ctrlc SIGINT

# Logging function
function log {
    echo "$(date +"%D %T") - $1" | tee -a $MYLOG
}

# Start logging
log "Script started."

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
    log "Source directory $SOURCE_DIR does not exist. Exiting."
    exit 1
fi

# Create backup directory
log "Creating backup directory: $BACKUP_DIR"
if ! mkdir -p $BACKUP_DIR; then
    log "Failed to create backup directory: $BACKUP_DIR. Exiting."
    exit 1
fi

# Copy files
log "Copying files from $SOURCE_DIR to $BACKUP_DIR"
if ! cp -vr $SOURCE_DIR/* $BACKUP_DIR/ >> $MYLOG 2>&1; then
    log "File copy operation failed. Exiting."
    exit 1
fi

log "Finished copying files."

# Compress the backup directory
log "Compressing backup directory."
if tar -czf $BACKUP_ARCHIVE -C $BACKUP_DIR .; then
    log "Backup directory compressed successfully: $BACKUP_ARCHIVE"
    rm -rf $BACKUP_DIR
else
    log "Failed to compress backup directory. Exiting."
    exit 1
fi

# Finish logging
log "Script completed successfully."

