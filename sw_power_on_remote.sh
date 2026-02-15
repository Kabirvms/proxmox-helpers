#!/bin/bash
# Home Assistant Power On Script for PBS

# Source environment variables and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/utilities.sh"

# Use environment variables
SWITCH_ENTITY="$SWITCH_ENTITY"
DEVICE_IP="$SWITCH_IP"
SWITCH_PERMISSION_ENTITY="$SWITCH_ACTIVATION_PERMISSION_ENTITY"

# Check Home Assistant permission before proceeding
log "Checking Home Assistant permission for switch activation..."
if ! check_ha_permission "$SWITCH_PERMISSION_ENTITY"; then
    log "Switch activation blocked by Home Assistant toggle"
    send_pushover "Backup Aborted: HA permission not granted"
    exit 1
fi

# Turn on the switch via Home Assistant
log "Activating switch $SWITCH_ENTITY via Home Assistant..."
set_ha_entity "$SWITCH_ENTITY" "on"

# Wait for device to respond
log "Waiting for device $DEVICE_IP to respond"
if check_device_online 30; then
    log "Device $DEVICE_IP is online and ready"
    exit 0
else
    log "BACKUP WILL FAIL: Device $DEVICE_IP did not respond after power on"
    send_pushover "BACKUP WILL FAIL: Device $DEVICE_IP did not respond after power turned on"
    exit 1
fi
