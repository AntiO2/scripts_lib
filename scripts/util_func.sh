check_fatal_exit() {
    [[ $? -ne 0 ]] && { log_fatal_exit "$@";}
    return 0
}

check_warning() {
    [[ $? -ne 0 ]] && { log_warning "$@"; }
    return 0
}

check_return() {
    [[ $? -ne 0 ]] && { log_warning "$@" && exit 1; }
    return 0
}



gen_dir_md5sum() {
    local md5dir_path=$1
    if [ -z ${md5dir_path} ]; then
        md5dir_path="."
    fi
    [[ -d ${md5dir_path} ]] || { check_return "${md5dir_path} is not dir"; }
    find ${md5dir_path} -maxdepth 1  -type f| xargs md5sum  > ${md5dir_path}/md5sum.txt
}

# @1: placeholder
# @2: replacement
# @3: src_file (template)
# @4: dst_file
gen_config_by_template() {
    if [ "$#" -ne 3 ] && [ "$#" -ne 4 ]; then
        log_fatal_exit "Usage: gen_config_by_template <placeholder_name> <replacement_value> <source_file> <dst_file>"
    fi
    local placeholder_name="$1"
    local replacement_value="$2"
    local source_file="$3"
    
    if [ ! -f "$source_file" ]; then
        log_fatal_exit "Template file '$source_file' does not exist."
    fi
    
    
    local dst_file="${4:-${source_file%.template}}"
    
    sed "s/<\\$ ${placeholder_name}>/${replacement_value}/g" "$source_file" > "$dst_file"
}

wait_for_url() {
    local url=$1
    local retries=${2:-10}
    local interval=3
    
    for ((i=1; i<=retries; i++)); do
        if curl --silent --head --fail "$url" > /dev/null; then
            log_info "URL $url is ready."
            return 0
        else
            log_warning "Attempt $i/$retries: URL $url is not ready. Retrying in $interval seconds..."
            sleep $interval
        fi
    done
    
    log_fatal "URL $url did not become ready after $retries attempts."
    return 1
}

try_command() {
    local MAX_RETRIES=10
    local INTERVAL=6
    local COMMAND="$@"
    local count=0
    local STATUS
    
    while [ $count -lt $MAX_RETRIES ]; do
        log_info "Attempting to execute command: $COMMAND (Attempt $((count+1))/$MAX_RETRIES)"
        
        "$@"  # Execute the command using "$@" to pass the arguments as individual parameters
        STATUS=$?
        
        if [ $STATUS -eq 0 ]; then
            log_info "Command executed successfully!"
            return 0
        fi
        
        log_warning "Command failed, retrying in $INTERVAL seconds..."
        count=$((count + 1))
        sleep $INTERVAL
    done
    log_fatal "Max retries ($MAX_RETRIES) reached. Command failed."
    return 1
}

check_env() {
    log_info "Check Java"
    java --version
    check_fatal_exit "JAVA is not installed"
    
    log_info "Check FLINK"
    [[ -z ${FLINK_HOME} ]] && { log_warning "FLINK_HOME is not set"; }
    
    log_info "Finish env check"
}

load_props() {
    local file="$1"
    [[ ! -f "$file" ]] && { log_fatal_exit  "Properties file not found: ${file}"; }
    
    while IFS='=' read -r key value; do
        log_info "Read Props: ${key}=${value}"
        key=$(echo "$key" | sed 's/^[ \t]*//;s/[ \t]*$//')
        value=$(echo "$value" | sed 's/^[ \t]*//;s/[ \t]*$//')
        [[ -z "$key" ]] && continue
        [[ "$key" =~ ^# ]] && continue
        [[ "$key" =~ ^\; ]] && continue
        export "$key"="$value"
    done < "$file"
}

parallel_executor() {
    local file_path="$1"
    local threads="${2:-8}"
    
    # 参数验证
    if [[ -z "$file_path" ]]; then
        log_fatal_exit "必须提供文件路径参数"
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_fatal_exit "文件 '$file_path' 不存在"
    fi
    
    if ! [[ "$threads" =~ ^[1-9][0-9]*$ ]]; then
        log_fatal_exit "线程数必须是正整数"
    fi
    
    log_info "开始并行执行 文件: $file_path 线程数: $threads"
    # 创建命名管道用于控制并发
    local fifo_file
    fifo_file=$(mktemp -u)
    mkfifo "$fifo_file"
    exec 3<>"$fifo_file"
    rm -f "$fifo_file"
    
    # 初始化管道
    for ((i=0; i<threads; i++)); do
        echo >&3
    done
    
    # 计数器
    local success_count=0
    local fail_count=0
    local current_line=0
    local total_lines
    total_lines=$(wc -l < "$file_path" | tr -d ' ')
    
    # 读取文件并并行执行
    while IFS= read -r command; do
        ((current_line++))
        
        # 跳过空行
        if [[ -z "$command" ]]; then
            continue
        fi
        
        log_info "[进度: $current_line/$total_lines] 执行: $command"
        
        # 控制并发
        read -u 3
        
        # 在子进程中执行命令
        {
            if eval "$command"; then
                log_info "[成功] $command"
                ((success_count++))
            else
                log_warning "[失败] $command"
                ((fail_count++))
            fi
            
            # 释放一个并发槽位
            echo >&3
        } &
        
    done < "$file_path"
    
    # 等待所有后台任务完成
    wait
    
    # 关闭文件描述符
    exec 3>&-
    
    log_info "执行完成! 成功: $success_count 失败: $fail_count 总计: $total_lines"
}