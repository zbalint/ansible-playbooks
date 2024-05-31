#!/bin/bash

readonly CONFIG_DIRECTORY="/root/.restic_backup"
readonly REPOSITORY_PATH_FILE="${CONFIG_DIRECTORY}/repository_path"
readonly REPOSITORY_PASS_FILE="${CONFIG_DIRECTORY}/repository_pass"

function main() {
    local repository_path_file="${REPOSITORY_PATH_FILE}"
    local repository_pass_file="${REPOSITORY_PASS_FILE}"

    restic --verbose --repository-file "${repository_path_file}" --password-file "${repository_pass_file}" $@
}

main $@