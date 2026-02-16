#!/bin/bash
# BACKUP Script Utilities

# Sets up a simple log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

#Sends the pushover notifications see the webiste for config options
send_pushover() {
    curl -s \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "message=$1" \
        https://api.pushover.net/1/messages.json > /dev/null
}

check_ha_permission() {
    local entity_id=${1}
    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        "$HA_URL/api/states/$entity_id")
    
    local state
    state=$(echo "$response" | jq -r '.state' 2>/dev/null)
    
    if [ "$state" = "on" ]; then
        log "Home Assistant: Permission granted for $DEVICE_NAME"
        return 0
    else
        #IF the entity is not on or the api call fails the following message is sent
        log "Home Assistant: Permission denied for $DEVICE_NAME (state: $state)"
        send_pushover "WARNING: HA permission not granted for $entity_id"
        return 1
    fi
}

#This is used to turn on or of a ha entitiy such as a swtich.
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
        send_pushover "WARNING: Failed to set $entity_id for $DEVICE_NAME"
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
    local ssh_user=${SSH_USER:-root}
    
    log "Checking Home Assistant permission for shutdown..."
    if ! check_ha_permission "$WOL_SHUTDOWN_ENTITY"; then
        log "Shutdown blocked by Home Assistant toggle"
        send_pushover "INFO: Auto Shutdown is disabled and $DEVICE_NAME will stay up"
        return 1
    fi
    
    log "Initiating remote shutdown via SSH to $ssh_user@$target_ip..."
    if ssh "$ssh_user@$target_ip" "sudo /sbin/shutdown -h now" 2>&1 | tee -a "$LOG_FILE"; then
        log "PBS shutdown command sent successfully"
        # Wait 2 mins for shutdown to happen before checking
        sleep 120 
        if check_device_online "$target_ip" 6; then
            log "ERROR: PBS is still online after shutdown command"
            send_pushover "WARNING: $DEVICE_NAME is still online after shutdown command"
            return 1
        else
            log "$DEVICE_NAME has shutdown successfully"
            return 0
        fi
    else
        log "Failed to send shutdown command to $DEVICE_NAME"
        send_pushover "WARNING: Failed to send ssh shutdown command to $DEVICE_NAME. Aborting next steps."
        return 1
    fi
}