#!/bin/bash

set -euo pipefail

PROCESS_NAME="test"
MONITORING_URL="https://test.com/monitoring/test/api"
LOG_FILE="/var/log/monitoring.log"
STATE_FILE="/var/run/monitor/monitor-test.state"

STATE_FIRST_START=0
STATE_RESTART=1
STATE_RUNNING=2

init_logging() {
	local log_dir
	log_dir=$(dirname "$LOG_FILE")

    	echo "DEBUG: Current user: $(whoami)" >&2
    	echo "DEBUG: Log directory: $log_dir" >&2
    	echo "DEBUG: Log file: $LOG_FILE" >&2


    	if [[ ! -d "$log_dir" ]]; then
        	echo "DEBUG: Creating log directory" >&2
        	mkdir -p "$log_dir"
        	chmod 755 "$log_dir"
    	fi

    	if [[ ! -f "$LOG_FILE" ]]; then
        	echo "DEBUG: Creating log file" >&2
        	touch "$LOG_FILE"
        	chmod 644 "$LOG_FILE"
    	fi

    	if [[ ! -w "$LOG_FILE" ]]; then
        	echo "DEBUG: Checking permissions..." >&2
        	ls -la "$LOG_FILE" >&2
        	echo "CRITICAL: Cannot write to log file: $LOG_FILE" >&2
        	exit 1
    	fi
}

curl_error_msg() {
    local code=$1
    case $code in
        1)  echo "Unsupported protocol" ;;
        2)  echo "Failed to initialize" ;;
        3)  echo "URL malformed" ;;
        5)  echo "Couldn't resolve proxy" ;;
        6)  echo "Couldn't resolve host" ;;
        7)  echo "Failed to connect to host" ;;
        28) echo "Operation timed out" ;;
        35) echo "SSL connect error" ;;
        51) echo "SSL certificate verification failed" ;;
        52) echo "Empty reply from server" ;;
        56) echo "Failure receiving network data" ;;
        60) echo "SSL certificate problem (expired, self-signed, etc.)" ;;
        *)  echo "Unknown error (code $code)" ;;
    esac
}

log() {
    local level=$1
    local message=$2
    printf '%s - %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$LOG_FILE"
}

get_pid() {
    pgrep -x "$PROCESS_NAME" | head -n1 || true
}

save_state() {
    local pid=$1
    local state_type=$2
    echo "$pid $(date +%s) $state_type" > "$STATE_FILE"
    chmod 644 "$STATE_FILE"
}

check_monitoring_server() {
    local http_code="000"
    local rc=0
    
    http_code=$(curl -s -o /dev/null --connect-timeout 7 \
        --max-time 15 \
        -w "%{http_code}" \
        -H "User-Agent: Monitoring-Script" \
        "$MONITORING_URL" 2>/dev/null) && rc=0 || rc=$?

    if [ $rc -ne 0 ]; then
        local msg
        msg=$(curl_error_msg "$rc")
        log "ERROR" "Monitoring server unreachable - $msg"
        return 1
    else
        if [ "$http_code" = "000" ]; then
            log "ERROR" "Monitoring server unreachable — No response (curl returned 000)"
            return 1
        elif [ "$http_code" != "200" ]; then
            log "ERROR" "Monitoring server returned HTTP $http_code"
            return 1
        else
            log "INFO" "Monitoring server check successful (HTTP 200)"
            return 0
        fi
    fi
}

main() {
    init_logging
    
    local prev_pid="" prev_time="" prev_state=""
    if [ -f "$STATE_FILE" ]; then
        read -r prev_pid prev_time prev_state < "$STATE_FILE" || true
    fi

    local cur_pid
    cur_pid=$(get_pid)

    if [ -z "$cur_pid" ]; then
        if [ -n "$prev_pid" ]; then
            log "INFO" "Process $PROCESS_NAME stopped (was PID: $prev_pid)"
        fi
        : > "$STATE_FILE"
        exit 0
    fi

    local state_change=""
    
    if [ -z "$prev_pid" ]; then
        log "INFO" "Process $PROCESS_NAME started (PID: $cur_pid)"
        save_state "$cur_pid" "$STATE_FIRST_START"
        state_change="first_start"
    elif [ "$prev_pid" != "$cur_pid" ]; then
        log "INFO" "Process $PROCESS_NAME restarted (new PID: $cur_pid, was PID: $prev_pid)"
        save_state "$cur_pid" "$STATE_RESTART"
        state_change="restart"
    else
        save_state "$cur_pid" "$STATE_RUNNING"
        state_change="running"
    fi

    if [ -n "$cur_pid" ]; then
        check_monitoring_server
    fi
}

main
exit 0
