function install_trino() 
{
    local CONNECTOR_ZIP=`readlink -f  ${TRINO_SRC}/connector/target/pixels-trino-connector-0.2.0-SNAPSHOT.zip`

    mvn package -f ${TRINO_SRC}/pom.xml

    rm -rf ${TRINO_OPT}/plugin/pixels-trino-connector-0.2.0-SNAPSHOT
    unzip ${CONNECTOR_ZIP} -d ${TRINO_OPT}/plugin
}

alias trino="${TRINO_OPT}/bin/launcher"