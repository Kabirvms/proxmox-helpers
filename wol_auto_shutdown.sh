#!/bin/bash
# PBS Backup Automation Hook Script

# Source environment variables and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Use environment variables
DEVICE_NAME="$WOL_DEVICE_NAME"
DEVICE_IP="$WOL_IP"
LOG_FILE="$WOL_LOG_FILE"

# Main script logic
case "$1" in
    job-start)
        log "INFO: Backup job starting with smart hook attached"        
        # Check if PBS is online
        if check_device_online 1; then
            log "INFO: $DEVICE_NAME is online, proceeding with backup"
            exit 0
        else
            log "WARNING: $DEVICE_NAME is offline!"
            send_pushover "WARNING: $DEVICE_NAME is offline! Configure crontab to wake PBS in advance of backup schedule"
            exit 1
        fi
        ;;
        
    job-end)
        log "INFO: Backup job completed successfully on $DEVICE_NAME initialating shutdown sequence"
        send_pushover "INFO: Backup completed successfully to $DEVICE_NAME at $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Wait 2 minutes before shutdown
        log "CRITICAL: Waiting 2 minutes before initiating shutdown"
        sleep 120
        
        shutdown_system
        ;;
        
    job-abort)
        log "ERROR: Backup Failed to $DEVICE_NAME"
        send_pushover "ERROR: Backup Failed to $DEVICE_NAME"
        log "CRITICAL: Waiting 5 minutes before attempting shutdown"
        sleep 300
        
        shutdown_system
        ;;
        
    backup-start|backup-end|pre-stop|pre-restart|post-restart|log-end|job-init)
        # Silently ignore these phases - they're per-VM, not per-job
        ;;
        
    *)
        log "Unknown phase: $1"
        ;;
esac

exit 0