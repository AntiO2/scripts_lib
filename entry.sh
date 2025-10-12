#!/bin/bash

SOURCE_PATH=`readlink -f $BASH_SOURCE` 2>/dev/null

if [[ -z ${SOURCE_PATH} ]]; then
    # for debug
    SOURCE_PATH=`readlink -f $0`
fi

PROJECT_DIR=`dirname ${SOURCE_PATH}`
SCRIPT_DIR=${PROJECT_DIR}/scripts


main()
{
    source ${SCRIPT_DIR}/log_func.sh
    source ${SCRIPT_DIR}/util_func.sh
    
    local ENV_DIR=${PROJECT_DIR}/env
    
    local PROFILE_DEFAULT_FILE_PATH="${ENV_DIR}/default.env"
    [[ -f ${PROFILE_DEFAULT_FILE_PATH} ]] || check_fatal_exit "Profile ${PROFILE_DEFAULT_FILE_PATH} doesn't exist"
    log_info "Use default profile file: ${PROFILE_DEFAULT_FILE_PATH}"
    source ${PROFILE_DEFAULT_FILE_PATH}
    
    local PROFILE=$1
    if [[ -n ${PROFILE} ]];then
        local PROFILE_FILE_PATH="${ENV_DIR}/${PROFILE}.env"
        [[ -f ${PROFILE_FILE_PATH} ]] || check_fatal_exit "Profile ${PROFILE_FILE_PATH} doesn't exist"
        log_info "Use custom profile file: ${PROFILE_FILE_PATH}"
        source ${PROFILE_FILE_PATH}
    fi
}

main $@