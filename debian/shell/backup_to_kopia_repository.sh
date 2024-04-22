#!/bin/bash
# kopia repository connect server --url https://vm-kopia-01.tail0e99d.ts.net:51515 --server-cert-fingerprint A8F393B6ADB9D2EE4EC52671C49B87C9BE77CC0174F91E7F141268E161E45BC2

function connect_repository() {
    local server_address="$1"
    local server_fingerprint="$2"
    local server_password="$3"

    KOPIA_PASSWORD="${server_password}" kopia repository connect server --url "${server_address}" --server-cert-fingerprint "${server_fingerprint}"
}

function disconnect_repository() {
    kopia repository disconnect
}

function create_snapshot() {
    local source_path="$1"
    kopia snapshot create "${source_path}" && kopia snapshot verify
}

function main() {
    return 0
}

main