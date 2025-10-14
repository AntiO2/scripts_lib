function check_pixels_env()
{
    
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