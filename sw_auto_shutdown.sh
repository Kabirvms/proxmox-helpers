#!/bin/bash
#This needs to be attached to the backup as a hook script

#Imports dependenices
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Pulls in from .env
DEVICE_NAME="$SW_DEVICE_NAME"
DEVICE_IP="$SW_IP"
LOG_FILE="$SW_LOG_FILE"
AUTO_OFF_ENTITY="$SW_AUTO_OFF_ENTITY"
SSH_USER="$SW_USER"

case "$1" in
    job-start)
        log "INFO: Backup job starting with smart hook attached"        
        if check_device_online 1; then
            log "PBS is online, proceeding with backup"
            exit 0
        else
            log "WARNING: $DEVICE_NAME is offline!"
            send_pushover "WARNING: $DEVICE_NAME is offline! Configure crontab to wake $DEVICE_NAME in advance of backup schedule"
            exit 1
        fi
        ;;
        
    job-end)
        log "INFO: Backup job completed successfully initialating shutdown sequence"
        send_pushover "INFO: Backup completed successfully on IP: $DEVICE_NAME at $(date '+%Y-%m-%d %H:%M:%S')"
        
        log "INFO: Waiting 2 minutes before initiating shutdown..."
        sleep 120
        
        if ! shutdown_system; then
            log "WARNING: Shutdown failed or was blocked"
            send_pushover "WARNING: Shutdown failed or was blocked after backup completion"
        else
            log "INFO: Shutdown initiated successfully"
            sleep 300
            set_ha_entity "$SW_ENTITY" "off"
        fi
        ;;
        
    job-abort)
        log "ERROR: Backup job aborted or failed and initiating shutdown"
        send_pushover "ERROR: Backup job aborted or failed. Continuing to shutdown"
        log "CRITICAL: Waiting 5 minutes before attempting shutdown"
        sleep 300
        
        if ! shutdown_system; then
            log "WARNING: Shutdown failed or was blocked"
            send_pushover "WARNING: Shutdown failed or was blocked after backup abort"
        else
            log "INFO: Shutdown initiated successfully after abort"
            sleep 300
            set_ha_entity "$SW_ENTITY" "off"
            send_pushover "INFO: Shutdown initiated successfully after backup abort"
        fi
        ;;
        
    backup-start|backup-end|pre-stop|pre-restart|post-restart|log-end|job-init)
    #Ignores all running of the backup phases
        ;;
        
    *)
        log "Unknown phase: $1"
        ;;
esac

exit 0
