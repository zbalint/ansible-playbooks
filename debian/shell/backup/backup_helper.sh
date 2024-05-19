#!/bin/bash

readonly BASE_DIR="/root/backup_helper"
readonly CONFIG_DIR="${BASE_DIR}/config"
readonly SCRIPTS_DIR="${BASE_DIR}/scripts"
readonly LOCAL_MOUNT_PATH="/mnt"
readonly LOCAL_MOUNT_PATH_LIST_FILE="/tmp/mount_path_list"
readonly REPOSITORY_TYPE_FILE="${CONFIG_DIR}/repository_type"
readonly REPOSITORY_PATH_FILE="${CONFIG_DIR}/repository_path"
readonly REPOSITORY_PASSWORD_FILE="${CONFIG_DIR}/repository_creds"
readonly REPOSITORY_CLIENT_LIST_FILE="${CONFIG_DIR}/repository_clients"
REPOSITORY_TYPE=""
REPOSITORY_PATH=""
REPOSITORY_PASSWORD=""
BACKUP_HELPER_SCRIPT=""

function print_log() {
    local level="$1"
    local message="$2"

    case "${level}" in
        INFO)
            ;&
        WARN)
            ;&
        ERROR)
            echo "backup_script.sh ($(date)) [${level}]: ${message}"
            ;;
        *)
            echo "backup_script.sh ($(date)) [UNKOWN]: ${message}"
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

handle_sigint() {
    log_warn "Caught SIGINT signal! Interrupting ${CURRENT_OPERATION}."

    bash ${BACKUP_HELPER_SCRIPT} cleanup

    while IFS= read -r mount_point
    do
        sshfs_umount "${mount_point}"
    done < "${LOCAL_MOUNT_PATH_LIST_FILE}"
    exit 1
}

trap 'handle_sigint' SIGINT

function var_is_empty() {
    local var="$1"

    if [ -z "${var}" ]; then
        return 0
    fi

    return 1
}

function file_is_exists() {
    local file="$1"
    
    if [ -e "${file}" ]; then
        if [ -r "${file}" ]; then
            return 0
        fi
    fi

    return 1
}

function dir_is_exists() {
    local directory="$1"

    if [ -d "${directory}" ]; then
        return 0
    fi

    return 1
}

function dir_is_mounted() {
    local directory="$1"

    if mountpoint -q "${directory}"; then
        return 0
    fi

    return 1
}

function read_file() {
    local file="$1"

    cat "${file}"
}

function get_repository_type() {
    read_file "${REPOSITORY_TYPE_FILE}"
}

function get_repository_path() {
    read_file "${REPOSITORY_PATH_FILE}"
}

function get_repository_password() {
    read_file "${REPOSITORY_PASSWORD_FILE}"
}

function get_remote_user() {
    local client="$1"
    echo "${client}" | cut -d ";" -f 1
}

function get_remote_host() {
    local client="$1"
    echo "${client}" | cut -d ";" -f 2
}

function get_remote_path() {
    local client="$1"
    echo "${client}" | cut -d ";" -f 3
}

function get_local_path() {
    local remote_host="$1"
    local remote_path="$2"
    local local_base_path="${LOCAL_MOUNT_PATH}"
    local local_path="${local_base_path}/${remote_host}${remote_path}"

    mkdir -p "${local_path}"
    echo "${local_path}"
}

function save_mount_path() {
    local mount_path="$1"

    echo "${mount_path}" >> "${LOCAL_MOUNT_PATH_LIST_FILE}"
}

function sshfs_mount() {
    local remote_user="$1"
    local remote_host="$2"
    local sshfs_options="ro,reconnect,compression=no,Ciphers=chacha20-poly1305@openssh.com"
    local remote_path="$3"
    local local_path="$4"

    sshfs -o "${sshfs_options}" "${remote_user}@${remote_host}":"${remote_path}" "${local_path}" && \
    save_mount_path "${local_path}"
}

function sshfs_umount() {
    local local_path="$1"

    umount "${local_path}"
}

function create_backup() {
    local repository_path="$1"
    local repository_password="$2"
    local remote_user="$3"
    local remote_host="$4"
    local remote_path="$5"
    local local_path="$6"

    bash ${BACKUP_HELPER_SCRIPT} backup "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}"
}

function check_repository() {
    local repository_path="$1"
    local repository_password="$2"

    bash ${BACKUP_HELPER_SCRIPT} check "${repository_path}" "${repository_password}"
}

function maintenance_repository() {
    local repository_path="$1"
    local repository_password="$2"

    bash ${BACKUP_HELPER_SCRIPT} maintenance "${repository_path}" "${repository_password}"
}


function send_notification() {
    log_warn "Notification sending not implemented!"
}

function backup_client() {
    local repository_path="$1"
    local repository_password="$2"
    local client="$3"
    local remote_user=$(get_remote_user "${client}")
    local remote_host=$(get_remote_host "${client}")
    local remote_path=$(get_remote_path "${client}")
    local local_path=$(get_local_path "${remote_host}" "${remote_path}")

    
    sshfs_mount "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}" && \
    create_backup "${repository_path}" "${repository_password}" "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}" || \
    send_notification
    sshfs_umount "${local_path}"
}

function backup() {
    local repository_path="$1"
    local repository_password="$2"
    local client_list_file="$3"

    while IFS= read -r client
    do
        backup_client "${repository_path}" "${repository_password}" "${client}"
    done < "${client_list_file}"

    check_repository "${repository_path}" "${repository_password}" && \
    maintenance_repository "${repository_path}" "${repository_password}"
}

function init() {
    if file_is_exists "${REPOSITORY_TYPE_FILE}"; then
        local repository_type=$(get_repository_type)

        if var_is_empty "${repository_type}"; then
            log_error "Unkown or empty repository type."
            exit 1
        fi

        REPOSITORY_TYPE="${repository_type}"
        BACKUP_HELPER_SCRIPT="${SCRIPTS_DIR}/${repository_type}_backup_helper.sh"

        if ! file_is_exists "${BACKUP_HELPER_SCRIPT}"; then
            log_error "Backup helper script does not exists! Missing file: ${BACKUP_HELPER_SCRIPT}"
            exit 1
        fi
    else
        log_error "Repository type config file does not exists! Missing file: ${REPOSITORY_TYPE_FILE}"
        exit 1
    fi

    if file_is_exists "${REPOSITORY_PATH_FILE}"; then
        local repository_path=$(get_repository_path)

        if var_is_empty "${repository_path}"; then
            log_error "Repository path is empty!"
            exit 1
        else
            if dir_is_exists "${repository_path}"; then
                if dir_is_mounted "${repository_path}"; then
                    REPOSITORY_PATH="${repository_path}"
                else
                    log_error "Repository path is not mounted! Invalid directory: ${repository_path}"
                    exit 1  
                fi
            else
                log_error "Repository path does not exists! Invalid directory: ${repository_path}"
                exit 1
            fi
        fi
    else
        log_error "Repository path config file does not exists! Missing file: ${REPOSITORY_PATH_FILE}"
        exit 1
    fi

    if file_is_exists "${REPOSITORY_PASSWORD_FILE}"; then
        local repository_password=$(get_repository_password)

        if var_is_empty "${repository_password}"; then
            log_error "Repository password is empty!"
            exit 1
        else 
            REPOSITORY_PASSWORD="${repository_password}"
        fi
    else
        log_error "Repository password config file does not exists! Missing file: ${REPOSITORY_PASSWORD_FILE}"
        exit 1
    fi

    if ! file_is_exists "${REPOSITORY_CLIENT_LIST_FILE}"; then
        log_error "Repository client config file does not exists! Missing file: ${REPOSITORY_CLIENT_LIST_FILE}"
        exit 1
    fi
    
    rm -f "${LOCAL_MOUNT_PATH_LIST_FILE}" && touch "${LOCAL_MOUNT_PATH_LIST_FILE}"
}

function main() {
    local repository_path="${REPOSITORY_PATH}"
    local repository_password="${REPOSITORY_PASSWORD}"
    local client_list_file="${REPOSITORY_CLIENT_LIST_FILE}"

    backup "${repository_path}" "${repository_password}" "${client_list_file}"
    return 0
}

init
main