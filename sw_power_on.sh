#!/bin/bash
# Home Assistant Power On Script for PBS

# Source environment variables and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Use environment variables
DEVICE_NAME="$SW_DEVICE_NAME"
DEVICE_IP="$SWIP"
LOG_FILE="$SWITCH_LOG_FILE"


# Check Home Assistant permission before proceeding
log "Checking Home Assistant permission for $SWITCH_PERMISSION_ENTITY"
if ! check_ha_permission "$SWITCH_PERMISSION_ENTITY"; then
    log "WARNING: HA permission not granted. The server will not backup to $DEVICE_NAME"
    send_pushover "WARNING: HA permission not granted. The server will not backup to $DEVICE_NAME"
    exit 1
fi

# Turn on the switch via Home Assistant
log "Activating switch $SW_ENTITY via Home Assistant"
set_ha_entity "$SW_ENTITY" "on"

# Wait for device to respond
log "Waiting for device $DEVICE_NAME to respond"
if check_device_online 30; then
    log "Device $DEVICE_NAME is online and ready"
    exit 0
else
    log "WARNING: Device $DEVICE_NAME did not respond after power on"
    send_pushover "WARNING: Device $DEVICE_NAME did not respond after power turned on"
    exit 1
fi
