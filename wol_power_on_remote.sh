#!/bin/bash
# Wake-on-LAN Power On Script for PBS

# Source environment variables and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Use environment variables
DEVICE_MAC="$WOL_MAC"
DEVICE_IP="$WOL_IP"
WOL_ENTITY="$WOL_ACTIVATION_PERMISSION_ENTITY"



# Check Home Assistant permission before proceeding
log "Checking Home Assistant permission for WOL activation..."
if ! check_ha_permission "$WOL_ENTITY"; then
    log "WOL activation blocked by Home Assistant toggle"
    send_pushover "Backup Aborted: HA permission not granted"
    exit 1
fi

# Send Wake-on-LAN
log "Sending Wake-on-LAN to $DEVICE_MAC..."
wakeonlan "$DEVICE_MAC"

 if ! check_device_online 30; then
        log "Device $DEVICE_IP is offline after WOL command"
        send_pushover "BACKUP WILL FAIL: Device $DEVICE_IP did not respond after WOL command"
        exit 1
fi  
log "Device $DEVICE_IP is online and ready"
exit 0
