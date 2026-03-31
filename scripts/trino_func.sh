function install_trino() 
{
    local CONNECTOR_ZIP=`readlink -f  ${TRINO_SRC}/connector/target/pixels-trino-connector-0.2.0-SNAPSHOT.zip`

    mvn package -f ${TRINO_SRC}/pom.xml
    check_fatal_exit "failed to build pixels-trino"
    rm -rf ${TRINO_OPT}/plugin/pixels-trino-connector-0.2.0-SNAPSHOT
    unzip ${CONNECTOR_ZIP} -d ${TRINO_OPT}/plugin
    log_info "Success to install trino"
}

function trino_cli_2()
{
    ${TRINO_OPT}/./bin/trino --server ${TRINO_ADD} --catalog ${TRINO_CATALOG}
}

alias trino="${TRINO_OPT}/bin/launcher"

sync_trino_cluster_configs() {
    # ================= 1. 配置区域 =================
    local TRINO_HOME="/home/ubuntu/opt/trino-server-466"
    local PIXELS_HOME="/home/ubuntu/opt/pixels" # 假设 Pixels 路径
    local NODE_LIST_FILE="$HOME/nodes.txt"
    local RSYNC_USER="ubuntu"
    local SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

    # ================= 2. 检查节点 =================
    if [[ ! -f "$NODE_LIST_FILE" ]]; then
        echo "❌ 错误: 找不到节点文件 $NODE_LIST_FILE"
        return 1
    fi

    local nodes
    mapfile -t nodes < <(grep -vE '^\s*#|^\s*$' "$NODE_LIST_FILE")

    if [[ ${#nodes[@]} -eq 0 ]]; then
        echo "❌ 错误: $NODE_LIST_FILE 中没有有效节点"
        return 1
    fi

    echo "🚀 准备同步配置到 ${#nodes[@]} 个节点..."

    # ================= 3. 执行同步 =================
    for node in "${nodes[@]}"; do
        echo "----------------------------------------------------"
        echo "📡 目标节点: $node"

        # 使用 rsync -R (relative) 确保文件同步到远程的对应绝对路径
        # 注意：rsync 会从当前路径开始创建目录，所以我们需要先 cd 到根目录 /
        # 或者使用绝对路径并配合 -R 选项
        echo "[1/2] 正在同步配置文件至对应位置..."
        
        # 同步 Trino 相关配置
        rsync -avzR -e "ssh $SSH_OPTS" \
            "$TRINO_HOME/etc/jvm.config" \
            "$TRINO_HOME/etc/config.properties" \
            "$RSYNC_USER@$node:/"

        # 同步 Pixels 相关配置
        rsync -avzR -e "ssh $SSH_OPTS" \
            "$PIXELS_HOME/etc/pixels.properties" \
            "$RSYNC_USER@$node:/"

        if [[ $? -ne 0 ]]; then
            echo "⚠️  结果: $node 物理同步失败，跳过后续操作。"
            continue
        fi

        # 4. 修改远程 node.id
        echo "[2/2] 正在设置远程 node.id..."
        ssh $SSH_OPTS "$RSYNC_USER@$node" \
            "sed -i 's/^node.id=.*/node.id=$node/' $TRINO_HOME/etc/node.properties"

        if [[ $? -eq 0 ]]; then
            echo "✅ 结果: $node 配置更新成功"
        else
            echo "❌ 结果: $node node.id 修改失败"
        fi
    done

    echo "----------------------------------------------------"
    echo "✨ 所有节点的 Trino 与 Pixels 配置已同步至对应路径。"
}