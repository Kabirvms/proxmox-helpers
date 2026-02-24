#!/bin/bash
# Wake-on-LAN Power On Script for PBS

# Source environment variables and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Use environment variables
DEVICE_NAME="$WOL_DEVICE_NAME"
DEVICE_IP="$WOL_IP"
LOG_FILE="$WOL_LOG_FILE"



# Check Home Assistant permission before proceeding
log "INFO: Checking Home Assistant permission for WOL activation on $DEVICE_NAME"
if ! check_ha_permission "$WOL_ACTIVATION_PERMISSION_ENTITY"; then
    log "WARNING: WOL activation blocked by Home Assistant toggle. $DEVICE_NAME is not ready"
    send_pushover "WARNING: HA permission not granted for $DEVICE_NAME"
    exit 1
fi

# Send Wake-on-LAN
log "INFO: Sending Wake-on-LAN to $DEVICE_NAME"
wakeonlan "$DEVICE_MAC"

 if ! check_device_online 30; then
        log "WARNING: Device $DEVICE_NAME is offline after WOL command"
        send_pushover "WARNING: Device $DEVICE_NAME did not respond after WOL command"
        exit 1
fi  
log "INFO: Device $DEVICE_NAME is online and ready"
exit 0
