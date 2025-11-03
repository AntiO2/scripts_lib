#!/bin/bash

if [ -n "$BASH_VERSION" ]; then
    # Bash
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "$ZSH_VERSION" ]; then
    # Zsh
    PROJECT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    # Fall Back
    PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

SCRIPT_DIR=${PROJECT_DIR}/scripts

main()
{
    source ${SCRIPT_DIR}/log_func.sh
    source ${SCRIPT_DIR}/util_func.sh
    
    local ENV_DIR=${PROJECT_DIR}/env
    
    local PROFILE_DEFAULT_FILE_PATH="${ENV_DIR}/default.env"
    [[ -f ${PROFILE_DEFAULT_FILE_PATH} ]] || check_fatal_exit "Profile ${PROFILE_DEFAULT_FILE_PATH} doesn't exist"
    # log_info "Use default profile file: ${PROFILE_DEFAULT_FILE_PATH}"
    source ${PROFILE_DEFAULT_FILE_PATH}
    
    local PROFILE=$1
    if [[ -n ${PROFILE} ]];then
        local PROFILE_FILE_PATH="${ENV_DIR}/${PROFILE}.env"
        [[ -f ${PROFILE_FILE_PATH} ]] || check_fatal_exit "Profile ${PROFILE_FILE_PATH} doesn't exist"
        # log_info "Use custom profile file: ${PROFILE_FILE_PATH}"
        source ${PROFILE_FILE_PATH}
    fi
    
    for f in $(find "${SCRIPT_DIR}" -type f -name '*_func.sh'); do
        # log_info "source $f"
        source "$f"
    done
}

main $@
