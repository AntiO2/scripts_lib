function check_pixels_env()
{
 exit 0   
}

function install_pixels()
{
    cd ${PIXELS_SRC}
    ./install.sh
    back
}

function start_pixels()
{
    ${PIXELS_HOME}/sbin/start-pixels.sh
}



function stop_pixels()
{
    ${PIXELS_HOME}/sbin/stop-pixels.sh
}

function pixels_meta()
{
    docker exec -it pixels-mysql mysql -uroot -ppixels_root -Dpixels_metadata
}
