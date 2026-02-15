#!/bin/bash
# PBS Backup Automation Hook Script

# Source environment variables and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Use environment variables
DEVICE_IP="$WOL_IP"
WOL_PERMISSION_ENTITY="$WOL_ACTIVATION_PERMISSION_ENTITY"
WOL_SHUTDOWN_ENTITY="$WOL_AUTO_OFF_ENTITY"
LOG_FILE="$WOL_LOG_FILE"

# Main script logic
case "$1" in
    job-start)
        log "Backup job starting with smart hook attached"
        send_pushover "Backup started"
        
        # Check if PBS is online
        if check_device_online 1; then
            log "PBS is online, proceeding with backup"
            exit 0
        else
            log "ERROR: PBS is offline!"
            send_pushover "Backup Aborting: PBS is offline! Configure crontab to wake PBS in advance of backup schedule"
            exit 1
        fi
        ;;
        
    job-end)
        log "Backup job completed successfully initialating shutdown sequence"
        send_pushover "Backup completed successfully on IP: $DEVICE_IP at $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Wait 2 minutes before shutdown
        log "Waiting 2 minutes before initiating shutdown..."
        sleep 120
        
        shutdown_system
        ;;
        
    job-abort)
        log "=== Backup job aborted or failed ==="
        send_pushover "BACKUP ABORTED:job aborted or failed"
        log "Waiting 5 minutes before attempting shutdown..."
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