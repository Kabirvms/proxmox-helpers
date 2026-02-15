#!/bin/bash
# BACKUP Script Utilities
# ENV Required: HA_URL, HA_TOKEN, PUSHOVER_TOKEN, PUSHOVER_USER, LOG_FILE, DEVICE_IP

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

send_pushover() {
    curl -s \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "message=$1" \
        https://api.pushover.net/1/messages.json > /dev/null
}

check_ha_permission() {
    local entity_id=${1:-$WOL_ACTIVATION_PERMISSION_ENTITY}  # Default to WOL permission if not specified
    
    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        "$HA_URL/api/states/$entity_id")
    
    local state
    state=$(echo "$response" | jq -r '.state' 2>/dev/null)
    
    if [ "$state" = "on" ]; then
        log "Home Assistant: Permission granted for $entity_id"
        return 0
    else
        log "Home Assistant: Permission denied for $entity_id (state: $state)"
        send_pushover "Backup Aborted: HA permission not granted for $entity_id"
        return 1
    fi
}

set_ha_entity() {
    local entity_id=$1
    local new_state=$2
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"state\": \"$new_state\"}" \
        "$HA_URL/api/states/$entity_id")
    
    local state
    state=$(echo "$response" | jq -r '.state' 2>/dev/null)
    if [ "$state" = "$new_state" ]; then
        log "Successfully set $entity_id to $new_state"
    else
        log "Failed to set $entity_id to $new_state"
        send_pushover "Backup Aborted: Failed to set $entity_id to $new_state"
    fi
}

check_device_online() {
    local max_attempts=${1:-5}  # Default to 5 if not specified
    local device_ip=${2:-$DEVICE_IP}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Checking if device $device_ip is online (attempt $attempt/$max_attempts)..."
        if ping -c 1 -W 1 "$device_ip" > /dev/null 2>&1; then
            log "Device $device_ip is online"
            return 0  # Online
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log "Device $device_ip not responding, waiting 10 seconds before retry..."
            sleep 10
        fi
        
        attempt=$((attempt + 1))
    done
    
    log "Device $device_ip is offline after $max_attempts attempts"
    return 1  # Offline
}


shutdown_system() {
    local target_ip=${1:-$DEVICE_IP}
    local ssh_user=${SSH_USER:-root}  # Default to root if not set
    
    log "Checking Home Assistant permission for shutdown..."
    if ! check_ha_permission "$WOL_SHUTDOWN_ENTITY"; then
        log "Shutdown blocked by Home Assistant toggle"
        send_pushover "Auto Shutdown is disabled and machine will stay up"
        return 1
    fi
    
    log "Initiating remote shutdown via SSH to $ssh_user@$target_ip..."
    if ssh "$ssh_user@$target_ip" "sudo /sbin/shutdown -h now" 2>&1 | tee -a "$LOG_FILE"; then
        log "PBS shutdown command sent successfully"
        sleep 30  # Wait for shutdown to begin
        if check_device_online "$target_ip" 6; then
            log "ERROR: PBS is still online after shutdown command"
            send_pushover "WARNING SYSTEM FAILURE: PBS is still online after shutdown command"
            return 1
        else
            log "PBS has shut down successfully"
            return 0
        fi
    else
        log "ERROR: Failed to send shutdown command to PBS"
        send_pushover "ERROR: Failed to send ssh shutdown command to PBS"
        return 1
    fi
}