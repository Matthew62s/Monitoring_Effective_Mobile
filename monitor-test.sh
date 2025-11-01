#!/bin/bash

set -euo pipefail

PROCESS_NAME="test"
MONITORING_URL="https://test.com/monitoring/test/api"
LOG_FILE="/var/log/monitoring.log"
STATE_FILE="/var/run/monitor-test.state"


init_logging() {
    	local log_dir
    	log_dir=$(dirname "$LOG_FILE")
    	if [[ ! -d "$log_dir" ]]; then
        	mkdir -p "$log_dir"
        	chmod 755 "$log_dir"
    	fi
    	if [[ ! -f "$LOG_FILE" ]]; then
        	touch "$LOG_FILE"
        	chmod 644 "$LOG_FILE"
    	fi
    	if [[ ! -w "$LOG_FILE" ]]; then
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
	printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

get_pid() {
    	pgrep -x "$PROCESS_NAME" | head -n1 || true
}

main() {
	init_logging
    	local prev_pid="" prev_time=""
    	if [ -f "$STATE_FILE" ]; then
        	read -r prev_pid prev_time < "$STATE_FILE" || true
    	fi

    	local cur_pid
    	cur_pid=$(get_pid)

	if [ -n "$cur_pid" ]; then
		if [ "$prev_pid" != "$cur_pid" ]; then
            		log "INFO: Process $PROCESS_NAME restarted (PID: $cur_pid)"
            		echo "$cur_pid $(date +%s)" > "$STATE_FILE"
        	fi

		local http_code="000"
		local rc=0
        	http_code=$(curl -s -o /dev/null --connect-timeout 7 \
			--max-time 15\
                	-w "%{http_code}" \
                	-H "User-Agent: Monitoring-Script" \
                	"$MONITORING_URL" 2>/dev/null) && rc=0 || rc=$?

        	if [ $rc -ne 0 ]; then
			local msg
			msg=$(curl_error_msg "$rc")
            		log "ERROR: Monitoring server unreachable - $msg"
		else
			if [ "$http_code" = "000" ]; then
            			log "ERROR: Monitoring server unreachable — No response (curl returned 000)"
        		elif [ "$http_code" != "200" ]; then
            			log "ERROR: Monitoring server returned HTTP $http_code"
        		fi
		fi

	else
		: > "$STATE_FILE"
	fi

}

main

exit 0
