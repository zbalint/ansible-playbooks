#!/bin/bash

function print_log() {
    local level="$1"
    local message="$2"

    case "${level}" in
        INFO)
            ;&
        WARN)
            ;&
        ERROR)
            echo "restic_backup_helper.sh ($(date)) [${level}]: ${message}"
            ;;
        *)
            echo "restic_backup_helper.sh ($(date)) [UNKOWN]: ${message}"
            ;;
        
    esac
}

function log_info() {
    local message="$1"

    print_log "INFO" "${message}"
}

function log_warn() {
    local message="$1"

    print_log "WARN" "${message}"
}

function log_error() {
    local message="$1"

    print_log "ERROR" "${message}"
}

function var_is_empty() {
    local var="$1"

    if [ -z "${var}" ]; then
        return 0
    fi

    return 1
}

function var_is_equals() {
    local var="$1"
    local str="$2"

    if [ "${var}" == "${str}" ]; then
        return 0
    fi

    return 1
}

function connect_repository() {
    local repository_path="$1"
    local repository_password="$2"
    local remote_user="$3"
    local remote_host="$4"

    RESTIC_PASSWORD="${repository_password}" restic -r "${repository_path}" snapshots
}

function disconnect_repository() {
    # Restic does not require an explicit "disconnect" operation to stop using a repository.
    return 0
}

function create_snapshot() {
    local repository_path="$1"
    local repository_password="$2"
    local remote_user="$3"
    local remote_host="$4"
    local remote_path="$5"
    local local_path="$6"

    RESTIC_PASSWORD="${repository_password}" restic -r "${repository_path}" backup "${local_path}" --tag "${remote_user}@${remote_host}:${remote_path}"
}

function check_repository() {
    local repository_path="$1"
    local repository_password="$2"
    
    RESTIC_PASSWORD="${repository_password}" restic -r "${repository_path}" check --read-data
}

function maintenance_repository() {
    local repository_path="$1"
    local repository_password="$2"

    RESTIC_PASSWORD="${repository_password}" restic -r "${repository_path}" forget --keep-yearly 3 --keep-monthly 24 --keep-weekly 4 --keep-daily 7 --keep-hourly 48 --keep-last 10 --prune
}

function report_error() {
    return 1
}

function valiate_args_creds_only() {
    local repository_path="$1"
    local repository_password="$2"

    if var_is_empty "${repository_path}"; then
        log_error "Invalid repository path!"
        exit 1
    fi

    if var_is_empty "${repository_password}"; then
        log_error "Invalid repository password!"
        exit 1
    fi
}

function valiate_args() {
    local repository_path="$1"
    local repository_password="$2"
    local remote_user="$3"
    local remote_host="$4"
    local remote_path="$5"
    local local_path="$6"

    if var_is_empty "${repository_path}"; then
        log_error "Invalid repository path!"
        exit 1
    fi

    if var_is_empty "${repository_password}"; then
        log_error "Invalid repository password!"
        exit 1
    fi

    if var_is_empty "${remote_user}"; then
        log_error "Invalid remote user!"
        exit 1
    fi
    
    if var_is_empty "${remote_host}"; then
        log_error "Invalid remote host!"
        exit 1
    fi
    
    if var_is_empty "${remote_path}"; then
        log_error "Invalid remote path!"
        exit 1
    fi
    
    if var_is_empty "${local_path}"; then
        log_error "Invalid local path!"
        exit 1
    fi
}

function init() {
    local command="$1"
    local repository_path="$2"
    local repository_password="$3"
    local remote_user="$4"
    local remote_host="$5"
    local remote_path="$6"
    local local_path="$7"

    if var_is_empty "${command}"; then
        log_error "Invalid command!"
        exit 1
    else 
        if var_is_equals "${command}" "cleanup"; then
            return 0
        elif var_is_equals "${command}" "check"; then
            valiate_args_creds_only "${repository_path}" "${repository_password}"
        elif var_is_equals "${command}" "maintenance"; then
            valiate_args_creds_only "${repository_path}" "${repository_password}"
        else 
            valiate_args "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}"
        fi
    fi
}


function main() {
    local command="$1"
    local repository_path="$2"
    local repository_password="$3"
    local remote_user="$4"
    local remote_host="$5"
    local remote_path="$6"
    local local_path="$7"

    case "${command}" in
        backup)
            connect_repository "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" && \
            create_snapshot "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}" && \
            check_repository "${repository_path}" "${repository_password}" && \
            maintenance_repository "${repository_path}" "${repository_password}" && \
            disconnect_repository || \
            report_error
            ;;
        check)
            connect_repository "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" && \
            check_repository "${repository_path}" "${repository_password}" && \
            disconnect_repository || \
            report_error
            ;;
        maintenance)
            connect_repository "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" && \
            maintenance_repository "${repository_path}" "${repository_password}" && \
            disconnect_repository || \
            report_error
            ;;
        cleanup)
            disconnect_repository || \
            report_error
            ;;
        *)
            log_error "Invalid command: ${command}"
            exit 1
            ;;
    esac

    return 0
}

init $@
main $@