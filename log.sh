#!/bin/bash

readonly INFO=1
readonly WARNING=2
readonly ERROR=3


log() {
    local level="$1"
    local message="$2"
    local timestamp
	
	local level_string

    # Map numeric log level to string
    case "$level" in
        "$INFO")
            level_string="INFO"
            ;;
        "$WARNING")
            level_string="WARNING"
            ;;
        "$ERROR")
            level_string="ERROR"
            ;;
        *)
            level_string="UNKNOWN"
            ;;
    esac
	
	

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    # Handle multiline messages by using printf
    printf "[%s] [%s]: %s\n" "$timestamp" "$level_string" "$message"
	
	if [ "$level" -eq "$ERROR" ]; then
		printf "[%s] [%s]: %s\n" "$timestamp" "$level_string" "$message" >> ./log/error.log
	fi	
	
}
