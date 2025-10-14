function install_trino() 
{
    local CONNECTOR_ZIP=`readlink -f  ${TRINO_SRC}/connector/target/pixels-trino-connector-0.2.0-SNAPSHOT.zip`

    mvn package -f ${TRINO_SRC}/pom.xml
    check_fatal_exit "failed to build pixels-trino"
    rm -rf ${TRINO_OPT}/plugin/pixels-trino-connector-0.2.0-SNAPSHOT
    unzip ${CONNECTOR_ZIP} -d ${TRINO_OPT}/plugin
    log_info "Success to install trino"
}

function trino_cli()
{
    ${TRINO_OPT}/./bin/trino --server ${TRINO_ADD} --catalog ${TRINO_CATALOG}
}

alias trino="${TRINO_OPT}/bin/launcher"