#!/bin/bash
# PBS backup hook script

#imports dependenices
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Pulls in from .env
DEVICE_IP="$SWITCH_IP"
SWITCH_PERMISSION_ENTITY="$SWITCH_ACTIVATION_PERMISSION_ENTITY"
SWITCH_SHUTDOWN_ENTITY="$SWITCH_AUTO_OFF_ENTITY"
LOG_FILE="$SWITCH_LOG_FILE"

case "$1" in
    job-start)
        log "Backup job starting with smart hook attached"
        send_pushover "Backup started"
        
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
        
        log "Waiting 2 minutes before initiating shutdown..."
        sleep 120
        
        if ! shutdown_system; then
            log "Shutdown failed or was blocked"
            send_pushover "Shutdown failed or was blocked after backup completion"
        else
            log "Shutdown initiated successfully"
            sleep 300
            set_ha_entity "$SWITCH_ENTITY" "off"
            send_pushover "Shutdown initiated successfully after backup completion"
        fi
        ;;
        
    job-abort)
        log "=== Backup job aborted or failed ==="
        send_pushover "BACKUP ABORTED: job aborted or failed"
        log "Waiting 5 minutes before attempting shutdown..."
        sleep 300
        
        if ! shutdown_system; then
            log "Shutdown failed or was blocked"
            send_pushover "Shutdown failed or was blocked after backup abort"
        else
            log "Shutdown initiated successfully after abort"
            sleep 300
            set_ha_entity "$SWITCH_ENTITY" "off"
            send_pushover "Shutdown initiated successfully after backup abort"
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
