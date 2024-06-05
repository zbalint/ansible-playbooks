#!/bin/bash

# directory consts
readonly BASE_DIRECTORY="/root/.restic_backup"
readonly CONFIG_DIRECTORY="${BASE_DIRECTORY}/config"

# repository settings consts
readonly REPOSITORY_PATH_FILE="${CONFIG_DIRECTORY}/repository_path"
readonly REPOSITORY_PASS_FILE="${CONFIG_DIRECTORY}/repository_pass"
readonly REPOSITORY_CLIENTS_FILE="${CONFIG_DIRECTORY}/repository_clients"

readonly REPOSITORY_RETENTION_KEEP_YEARLY=3
readonly REPOSITORY_RETENTION_KEEP_MONTHLY=24
readonly REPOSITORY_RETENTION_KEEP_WEEKLY=4
readonly REPOSITORY_RETENTION_KEEP_DAILY=7
readonly REPOSITORY_RETENTION_KEEP_HOURLY=48
readonly REPOSITORY_RETENTION_KEEP_LAST=10

# healthcheck.io settings consts
readonly HEALTHCHECKS_IO_ID_FILE="${CONFIG_DIRECTORY}/healthchecks_io_id"

# sshfs settings consts
readonly LOCAL_MOUNT_PATH="/mnt"
readonly LOCAL_MOUNT_PATH_LIST_FILE="/tmp/restic_mount_path_list"
readonly SSHFS_BACKUP_OPTIONS="ro,reconnect,cache=no,compression=no,Ciphers=chacha20-poly1305@openssh.com"
readonly SSHFS_RESTORE_OPTIONS="reconnect,cache=no,compression=no,Ciphers=chacha20-poly1305@openssh.com"

function log() {
    local level="$1"; shift;
    local message="$*"

    echo "${BASH_SOURCE[0]} [${level}]: ${message}"
}

function log_info() {
    local level="INFO "
    local message="$*"

    log "${level}" "${message}"
}

function log_warn() {
    local level="WARN "
    local message="$*"

    log "${level}" "${message}"
}

function log_error() {
    local level="ERROR"
    local message="$*"

    log "${level}" "${message}"
}

function check_permissions() {
    if [[ $(stat -c "%a" "${BASH_SOURCE[0]}") != "700" ]]; then
        log_error "Incorrect permissions on script. Run: "
        log_info "  chmod 0700 $(realpath "${BASH_SOURCE[0]}")"
        exit 1
    fi
}

function validate_restic_installation() {
    if ! command -v restic >/dev/null; then
        log_error "You need to install restic."
        exit 1
    fi
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

function get_repository_path() {
    read_file "${REPOSITORY_PATH_FILE}"
}

function get_repository_password() {
    read_file "${REPOSITORY_PASS_FILE}"
}

function get_healthchecks_io_id() {
    read_file "${HEALTHCHECKS_IO_ID_FILE}"
}

function save_mount_path() {
    local mount_path="$1"

    echo "${mount_path}" >> "${LOCAL_MOUNT_PATH_LIST_FILE}"
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

function sshfs_mount() {
    local remote_user="$1"
    local remote_host="$2"
    local remote_path="$3"
    local local_path="$4"
    local sshfs_options="$5"

    sshfs -o "${sshfs_options}" "${remote_user}@${remote_host}:${remote_path}" "${local_path}" && \
    dir_is_exists "${local_path}" && \
    dir_is_mounted "${local_path}" && \
    save_mount_path "${local_path}"
}

function sshfs_umount() {
    local local_path="$1"

    umount "${local_path}"
}

function healthcheck() {
    local status="$1"
    local healthchecks_io_id
    healthchecks_io_id="$(get_healthchecks_io_id)"

    # using curl (10 second timeout, retry up to 5 times):

    case "${status}" in
        start)
            curl -m 10 --retry 5 https://hc-ping.com/"${healthchecks_io_id}"/start
            ;;
        stop)
            curl -m 10 --retry 5 https://hc-ping.com/"${healthchecks_io_id}"
            ;;
    esac
    
}

function call_restic() {
    local repository_path_file="${REPOSITORY_PATH_FILE}"
    local repository_pass_file="${REPOSITORY_PASS_FILE}"

    restic --verbose --repository-file "${repository_path_file}" --password-file "${repository_pass_file}" "$@"
}

function restic_init() {
    call_restic init
}

function restic_check() {
    call_restic check --read-data-subset 10%
}

function restic_forget() {
    call_restic forget \
    --keep-yearly "${REPOSITORY_RETENTION_KEEP_YEARLY}" \
    --keep-monthly "${REPOSITORY_RETENTION_KEEP_MONTHLY}" \
    --keep-weekly "${REPOSITORY_RETENTION_KEEP_WEEKLY}" \
    --keep-daily "${REPOSITORY_RETENTION_KEEP_DAILY}" \
    --keep-hourly "${REPOSITORY_RETENTION_KEEP_HOURLY}" \
    --keep-last "${REPOSITORY_RETENTION_KEEP_LAST}" \
    --prune
}

function restic_backup() {
    local backup_path="$1"
    local backup_tag="$2"
    local backup_host="$3"

    call_restic backup "${backup_path}" --tag "${backup_tag}" --host "${backup_host}"
}

function restic_restore() {
    local restore_path="$1"
    local backup_tag="$2"
    local backup_host="$3"
    local backup_path="$4"

    call_restic restore latest --tag "${backup_tag}" --host "${backup_host}" --path "${backup_path}" --target "${restore_path}"
}

function create_repository() {
    restic_init
}

function create_backup() {
    local local_path="$1"
    local backup_tag="$2"
    local backup_host="$3"

    dir_is_exists "${local_path}" && \
    dir_is_mounted "${local_path}" && \
    restic_backup "${local_path}" "${backup_tag}" "${backup_host}"
}

function restore_backup() {
    local local_path="$1"
    local backup_tag="$2"
    local backup_host="$3"
    local backup_path="$4"

    dir_is_exists "${local_path}" && \
    dir_is_mounted "${local_path}" && \
    restic_restore "${local_path}" "${backup_tag}" "${backup_host}" "${backup_path}"
}

function backup_client() {
    local client="$1"
    local remote_user
    local remote_host
    local remote_path
    local local_path

    remote_user=$(get_remote_user "${client}")
    remote_host=$(get_remote_host "${client}")
    remote_path=$(get_remote_path "${client}")
    local_path=$(get_local_path "${remote_host}" "${remote_path}")
    
    sshfs_mount "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}" "${SSHFS_BACKUP_OPTIONS}" && \
    create_backup "${local_path}" "${remote_user}@${remote_host}:${remote_path}" "${remote_host}"
    sshfs_umount "${local_path}"
}

function backup_clients() {
    local repository_clients_list="${REPOSITORY_CLIENTS_FILE}"

    healthcheck "start"

    while IFS= read -r client
    do
        backup_client "${client}"
    done < "${repository_clients_list}"

    restic_forget && \
    restic_check && \
    healthcheck "stop"
}

function restore_client() {
    local client="$1"
    local remote_user
    local remote_host
    local remote_path
    local local_path

    remote_user=$(get_remote_user "${client}")
    remote_host=$(get_remote_host "${client}")
    remote_path=$(get_remote_path "${client}")
    local_path=$(get_local_path "${remote_host}" "${remote_path}")

    sshfs_mount "${remote_user}" "${remote_host}" "${remote_path}" "${local_path}" "${SSHFS_RESTORE_OPTIONS}" && \
    restore_backup "/" "${remote_user}@${remote_host}:${remote_path}" "${remote_host}" "${local_path}"
    sshfs_umount "${local_path}"
}

function init() {
    check_permissions
    validate_restic_installation

    file_is_exists "${REPOSITORY_PATH_FILE}" && \
    file_is_exists "${REPOSITORY_PASS_FILE}" && \
    file_is_exists "${REPOSITORY_CLIENTS_FILE}" || \
    exit 1
}

function main() {
    local command="$1"
    local args="$2"

    case "${command}" in
        init)
            create_repository
            ;;
        backup)
            backup_clients
            ;;
        restore)
            local client="${args}"
            restore_client "${client}"
            ;;
        snapshots)
            call_restic snapshots
            ;;
        *)
            ;;
    esac
}

init && \
main "$@"