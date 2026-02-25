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
        log "INFO: Home Assistant: Permission granted for $DEVICE_NAME"
        return 0
    elif [ "$state" = "off" ]; then
        log "WARNING: Home Assistant: Denied the Request for $DEVICE_NAME"
        send_pushover "WARNING: Home Assistant: Denied the Request for $DEVICE_NAME"
        return 1
    else
        #If the api call fails the following message is sent
        log "ERROR: Home Assistant: API Call error failed to check permissions in Home Assistant"
        send_pushover "ERROR: Home Assistant: API Call error failed to check permissions in Home Assistant: $entity_id"
        return 2
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
        log "INFO: Successfully set $entity_id to $new_state"
    else
        log "ERROR: Failed to set $entity_id to $new_state"
        send_pushover "ERROR: Failed to set $entity_id for $DEVICE_NAME"
    fi
}

check_device_online() {
    local max_attempts=${1:-5}  # Default to 5 if not specified
    local device_ip=${2:-$DEVICE_IP}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "INFO: Checking if device $DEVICE_NAME is online (attempt $attempt/$max_attempts)..."
        if ping -c 1 -W 1 "$device_ip" > /dev/null 2>&1; then
            log "INFO: Device $DEVICE_NAME is online"
            return 0  # Online
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log "INFO: Device $DEVICE_NAME not responding, waiting 10 seconds before retry..."
            sleep 10
        fi
        
        attempt=$((attempt + 1))
    done
    
    log "INFO: Device $DEVICE_NAME is offline after $max_attempts attempts"
    return 1  # Offline
}


shutdown_system() {
    local target_ip=${1:-$DEVICE_IP}
    local ssh_user=${SSH_USER:-root}

    
    log "INFO: Checking Home Assistant permission for shutdown"
    if ! check_ha_permission "$AUTO_OFF_ENTITY"; then
        log "WARNING: Shutdown blocked by Home Assistant toggle"
        send_pushover "WARNING: Auto Shutdown is disabled and $DEVICE_NAME will stay up"
        return 1
    fi
    
    log "INFO: Initiating remote shutdown via SSH to $ssh_user@$target_ip"
    if [ "$ssh_user" == "root" ]; then
        if ssh "$ssh_user@$target_ip" "/sbin/shutdown -h now" 2>&1 | tee -a "$LOG_FILE"; then
            log "INFO: Shutdown command sent successfully to $DEVICE_NAME"
        else
            log "ERROR: Failed to send shutdown command to $DEVICE_NAME"
            send_pushover "ERROR: Failed to send shutdown command to $DEVICE_NAME"
            return 1
        fi
    else
        if ssh "$ssh_user@$target_ip" "sudo /sbin/shutdown -h now" 2>&1 | tee -a "$LOG_FILE"; then
            log "INFO: Shutdown command sent successfully to $DEVICE_NAME"
        else
            log "ERROR: Failed to send shutdown command to $DEVICE_NAME"
            send_pushover "ERROR: Failed to send shutdown command to $DEVICE_NAME"
            return 1
        fi
    fi
    sleep 120 
    if check_device_online "$target_ip" 6; then
        log "ERROR: $DEVICE_NAME is still online after shutdown command"
        send_pushover "ERROR: $DEVICE_NAME is still online after shutdown command"
        return 1
    else
        log "INFO: $DEVICE_NAME has shutdown successfully"
        return 0
    fi
   
}