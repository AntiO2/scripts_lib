ssh_retina() {
    # 检查是否提供了IP地址参数
    if [ $# -ne 1 ]; then
        echo "使用方法: ssh_retina <ip地址>"
        return 1
    fi
    # 执行ssh连接，使用指定的密钥和用户名，通过代理连接
    ssh -i ~/.ssh/retina.pem -o "ProxyCommand nc -X connect -x $USER_PROXY %h %p" ubuntu@"$1"
}

function proxy_on(){
    export HTTP_PROXY="http://10.77.110.28:7890"
    export SOCKS_PROXY="socks5://10.77.110.28:7891"
    export HTTPS_PROXY="http://10.77.110.28:7890"
    export http_proxy="http://10.77.110.28:7890"
    export socks_proxy="socks5://10.77.110.28:7891"
    export https_proxy="http://10.77.110.28:7890"
}

function proxy_off(){
    unset http_proxy
    unset https_proxy
    unset socks_proxy
    unset HTTPS_PROXY
    unset HTTP_PROXY
    unset SOCKS_PROXY
}