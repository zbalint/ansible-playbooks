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
            echo "kopia_backup_helper.sh ($(date)) [${level}]: ${message}"
            ;;
        *)
            echo "kopia_backup_helper.sh ($(date)) [UNKOWN]: ${message}"
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

    KOPIA_CHECK_FOR_UPDATES=false KOPIA_PASSWORD="${repository_password}" kopia repository connect filesystem --override-username "${remote_user}" --override-hostname "${remote_host}" --path="${repository_path}"
}

function disconnect_repository() {
    KOPIA_CHECK_FOR_UPDATES=false kopia repository disconnect
}

function create_snapshot() {
    local remote_user="$1"
    local remote_host="$2"
    local remote_path="$3"
    local local_path="$4"

    KOPIA_CHECK_FOR_UPDATES=false kopia snapshot create "${local_path}" --description "${remote_user}@${remote_host}:${remote_path}"
}

function init_repository() {
    local repository_path="$1"
    local repository_password="$2"

    KOPIA_CHECK_FOR_UPDATES=false kopia repository create filesystem --ecc-overhead-percent 10 --path="${repository_path}"
}

function check_repository() {
    KOPIA_CHECK_FOR_UPDATES=false kopia snapshot verify
}

function maintenance_repository() {
    KOPIA_CHECK_FOR_UPDATES=false kopia snapshot expire && \
    KOPIA_CHECK_FOR_UPDATES=false kopia maintenance run --full
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
        elif var_is_equals "${command}" "init"; then
            valiate_args_creds_only "${repository_path}" "${repository_password}"
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
        init)
            init_repository "${repository_path}" "${repository_password}" && \
            report_error
            ;;
        backup)
            connect_repository "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" && \
            create_snapshot "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}" && \
            disconnect_repository || \
            report_error
            ;;
        check)
            connect_repository "${repository_path}" "${repository_password}" "${USER}" "$(hostname)" && \
            check_repository && \
            disconnect_repository || \
            report_error
            ;;
        maintenance)
            connect_repository "${repository_path}" "${repository_password}" "${USER}" "$(hostname)" && \
            maintenance_repository && \
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
}

init $@
main $@