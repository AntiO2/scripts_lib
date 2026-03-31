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

sync_retina_indexes() {
  local retina_file="${1:-$PIXELS_HOME/etc/retina}"
  local src_dir="${2:-$HOME/disk2/index_bak/}"
  local dst_dir="${3:-/home/ubuntu/disk1/}"
  local parallel_jobs="${4:-16}"
  local user="ubuntu"

  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$retina_file" ]]; then
    echo "retina file not found: $retina_file" >&2
    return 1
  fi

  export src_dir dst_dir user

  # 一次性读取所有行到数组，避免最后一行丢失
  mapfile -t hosts < "$retina_file"

  # 过滤空行和注释
  filtered_hosts=()
  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"   # 去掉首尾空白
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue
    filtered_hosts+=("$host")
  done

  # 并行同步
  printf "%s\n" "${filtered_hosts[@]}" | \
  parallel --line-buffer -j "$parallel_jobs" '
    host={}
    echo "=== [${host}] sync started ==="

    if rsync -avz --delete \
        --partial \
        --numeric-ids \
        --info=stats2 \
        -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
        "$src_dir" \
        "${user}@${host}:${dst_dir}"
    then
      echo "=== [${host}] sync finished OK ==="
    else
      echo "=== [${host}] sync FAILED ===" >&2
    fi
  '
}


clean_retina_checkpoints() {
  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  local prop_file="$PIXELS_HOME/etc/pixels.properties"
  local retina_file="${1:-$PIXELS_HOME/etc/retina}"
  local user="ubuntu"

  # 1. 从 prop 文件读取路径
  local raw_checkpoint_dir
  raw_checkpoint_dir=$(get_prop "$prop_file" "pixels.retina.checkpoint.dir")

  # 如果读取失败，设置默认值
  if [[ -z "$raw_checkpoint_dir" ]]; then
    echo "Warning: pixels.retina.checkpoint.dir not found in $prop_file, using default."
    raw_checkpoint_dir="file:///tmp/pixels-checkpoints"
  fi

  # 2. 处理路径格式：去除 file:/// 前缀
  # 使用 shell 的参数替换去除前缀
  local target_dir="${raw_checkpoint_dir#file://}"

  echo "Resolved target directory: $target_dir"

  if [[ ! -f "$retina_file" ]]; then
    echo "retina file not found: $retina_file" >&2
    return 1
  fi

  # 一次性读入所有行
  mapfile -t hosts < "$retina_file"

  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue

    echo "[${host}] checking ${target_dir}"

    # 使用单引号包裹远程执行的命令，防止本地变量提前解析
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${user}@${host}" "
      if [[ -d '${target_dir}' ]]; then
        echo '[${host}] removing ${target_dir}'
        # 安全检查：确保 target_dir 不为空且不是根目录
        if [[ -n '${target_dir}' && '${target_dir}' != '/' ]]; then
          rm -rf '${target_dir}'
          echo '[${host}] removed'
        fi
      else
        echo '[${host}] not exists'
      fi
    "
  done
}

sync_sink_nodes() {
  local sink_file="${1:-$PIXELS_HOME/etc/sink}"
  local src_dir1="${2:-$HOME/pixels-sink/}"
  local src_dir2="${3:-$HOME/disk2/hybench/hybench1000_4/}"
  local src_dir3="${4:-$PIXELS_HOME/etc/}"
  local parallel_jobs="${5:-4}"
  local user="ubuntu"

  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$sink_file" ]]; then
    echo "sink file not found: $sink_file" >&2
    return 1
  fi

  export src_dir1 src_dir2 src_dir3 user

  # 一次性读取所有行到数组，避免最后一行丢失
  mapfile -t hosts < "$sink_file"

  # 过滤空行和注释
  filtered_hosts=()
  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"   # 去掉首尾空白
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue
    filtered_hosts+=("$host")
  done

  # 并行同步
  printf "%s\n" "${filtered_hosts[@]}" | \
  parallel --line-buffer -j "$parallel_jobs" '
    host={}
    echo "=== [${host}] sync started ==="

    for SRC in "$src_dir1" "$src_dir2" "$src_dir3"; do
      echo "=== [${host}] syncing $SRC ==="

      # 1. 确保远程目录存在
      ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${user}@${host}" "mkdir -p $SRC"

      # 2. 同步
      if rsync -avz --delete \
          --partial \
          --numeric-ids \
          --info=stats2 \
          -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
          "$SRC" \
          "${user}@${host}:$SRC"
      then
        echo "=== [${host}] $SRC sync OK ==="
      else
        echo "=== [${host}] $SRC sync FAILED ===" >&2
      fi
    done

    echo "=== [${host}] sync finished ==="
  '
}

start_pixels_sink() {
  local sink_file="${1:-$PIXELS_HOME/etc/sink}"
  local user="ubuntu"

  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ -z "${PIXELS_SINK_HOME:-}" ]]; then
    echo "PIXELS_SINK_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$sink_file" ]]; then
    echo "sink file not found: $sink_file" >&2
    return 1
  fi

  echo "Starting pixels-sink on all nodes"
  echo "PIXELS_HOME=${PIXELS_HOME}"
  echo "PIXELS_SINK_HOME=${PIXELS_SINK_HOME}"

  # 一次性读取，避免最后一行丢失
  mapfile -t hosts < "$sink_file"

  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue

    echo "=== [${host}] starting pixels-sink ==="

    ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${user}@${host}" "
      export PIXELS_HOME='${PIXELS_HOME}'
      export PIXELS_SINK_HOME='${PIXELS_SINK_HOME}'

      if [[ ! -x '${PIXELS_SINK_HOME}/pixels-sink' ]]; then
        echo '[${host}] pixels-sink not found or not executable'
        exit 1
      fi

      cd '${PIXELS_SINK_HOME}'
      nohup ./pixels-sink > pixels-sink.out 2>&1 &
      echo '[${host}] started'
    "
  done
}


clean_sink_monitor_report() {
  local sink_file="${1:-$PIXELS_HOME/etc/sink}"
  local conf_file="${PIXELS_SINK_HOME}/conf/pixels-sink.aws.properties"
  local user="ubuntu"

  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ -z "${PIXELS_SINK_HOME:-}" ]]; then
    echo "PIXELS_SINK_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$sink_file" ]]; then
    echo "sink file not found: $sink_file" >&2
    return 1
  fi

  if [[ ! -f "$conf_file" ]]; then
    echo "config file not found: $conf_file" >&2
    return 1
  fi

  # 读取 sink.monitor.report.file 配置
  local report_file
  report_file="$(grep -E '^\s*sink\.monitor\.report\.file\s*=' "$conf_file" \
    | tail -n 1 \
    | sed 's/^[^=]*=//g' \
    | xargs)"

  if [[ -z "$report_file" ]]; then
    echo "sink.monitor.report.file not found or empty in $conf_file" >&2
    return 1
  fi

  echo "Target report file: $report_file"

  # 一次性读取，避免最后一行丢失
  mapfile -t hosts < "$sink_file"

  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue

    echo "[${host}] cleaning ${report_file}"

    ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${user}@${host}" "
      if [[ -f '${report_file}' ]]; then
        rm -f '${report_file}'
        echo '[${host}] removed'
      else
        echo '[${host}] not exists'
      fi
    "
  done
}

collect_sink_monitor_logs() {
  local sink_file="${1:-$PIXELS_HOME/etc/sink}"
  local output_dir="${2:-$PWD/collected-logs}"
  local conf_file="${PIXELS_SINK_HOME}/conf/pixels-sink.aws.properties"
  local user="ubuntu"

  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ -z "${PIXELS_SINK_HOME:-}" ]]; then
    echo "PIXELS_SINK_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$sink_file" ]]; then
    echo "sink file not found: $sink_file" >&2
    return 1
  fi

  if [[ ! -f "$conf_file" ]]; then
    echo "config file not found: $conf_file" >&2
    return 1
  fi

  # 解析 sink.monitor.report.file
  local report_file
  report_file="$(grep -E '^\s*sink\.monitor\.report\.file\s*=' "$conf_file" \
    | tail -n 1 \
    | sed 's/^[^=]*=//g' \
    | xargs)"

  if [[ -z "$report_file" ]]; then
    echo "sink.monitor.report.file not found or empty" >&2
    return 1
  fi

  echo "Report file: $report_file"
  echo "Collecting logs to: $output_dir"

  mkdir -p "$output_dir"

  # 一次性读取，避免最后一行丢失
  mapfile -t hosts < "$sink_file"

  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue

    local host_dir="${output_dir}/${host}"
    mkdir -p "$host_dir"

    echo "=== [${host}] collecting log ==="

    # 先检查远端是否存在
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${user}@${host}" "[[ -f '${report_file}' ]]"
    then
      rsync -av \
        -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
        "${user}@${host}:${report_file}" \
        "${host_dir}/"
      echo "=== [${host}] collected ==="
    else
      echo "=== [${host}] report file not exists ==="
    fi
  done
}

collect_retina_logs() {
  local suffix="${1:-$(date +%Y%m%d_%H%M%S)}"
  local retina_list="${PIXELS_HOME}/etc/retina"
  local output_dir="${2:-$PWD/collected-retina-logs}"
  local user="ubuntu"
  
  # Basic environment checks
  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$retina_list" ]]; then
    echo "Retina list file not found: $retina_list" >&2
    return 1
  fi

  # Define the target log path on remote nodes
  local remote_log="${PIXELS_HOME}/logs/retina.out"

  echo "Collecting Retina logs with suffix: $suffix"
  echo "Target remote log: $remote_log"
  echo "Local output directory: $output_dir"

  mkdir -p "$output_dir"

  # Read host list into array
  mapfile -t hosts < "$retina_list"

  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue

    echo "=== [${host}] collecting log ==="

    # Check if the log exists on the remote node
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${user}@${host}" "[[ -f '${remote_log}' ]]"
    then
      # Use rsync to copy, then rename locally with the suffix
      # This prevents overwriting if multiple hosts have the same log name
      rsync -av \
        -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
        "${user}@${host}:${remote_log}" \
        "${output_dir}/retina_${host}_${suffix}.out"
      
      echo "=== [${host}] collected as retina_${host}_${suffix}.out ==="
    else
      echo "=== [${host}] log file does not exist on remote ==="
    fi
  done
}

stop_pixels_sink() {
  local sink_file="${1:-$PIXELS_HOME/etc/sink}"
  local user="ubuntu"

  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$sink_file" ]]; then
    echo "sink file not found: $sink_file" >&2
    return 1
  fi

  echo "Stopping pixels-sink on all nodes"

  # 一次性读取，避免最后一行丢失
  mapfile -t hosts < "$sink_file"

  for host in "${hosts[@]}"; do
    host="$(echo "$host" | xargs)"
    [[ -z "$host" ]] && continue
    [[ "$host" == \#* ]] && continue

    echo "=== [${host}] killing pixels-sink ==="

    ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${user}@${host}" "
      if ! command -v jps >/dev/null 2>&1; then
        echo '[${host}] jps not found (JAVA_HOME?)'
        exit 1
      fi

      pids=\$(jps | grep pixels-sink | awk '{print \$1}')

      if [[ -z \"\$pids\" ]]; then
        echo '[${host}] no pixels-sink process'
        exit 0
      fi

      echo '[${host}] killing pids:' \$pids
      for pid in \$pids; do
        kill -9 \$pid
      done
    "
  done
}

collect_retina_indexes_parallel() {
  local retina_file="${1:-$PIXELS_HOME/etc/retina}"
  local remote_disk="${2:-/home/ubuntu/disk1}"
  local local_base_dir="${3:-/home/ubuntu/disk6/collected_indexes}"
  local parallel_jobs="${4:-8}"
  local user="ubuntu"

  # 1. 环境检查
  if [[ -z "${PIXELS_HOME:-}" ]]; then
    echo "Error: PIXELS_HOME is not set" >&2
    return 1
  fi

  if [[ ! -f "$retina_file" ]]; then
    echo "Error: retina file not found: $retina_file" >&2
    return 1
  fi

  # 2. 规范化路径：确保 remote_disk 以 / 结尾，这样 rsync 只同步目录内容
  [[ "$remote_disk" != */ ]] && remote_disk="$remote_disk/"

  # 导出变量给 parallel 的子 shell 使用
  export user local_base_dir remote_disk

  echo "=== Starting Parallel Collection ==="
  echo "Remote Source: $remote_disk"
  echo "Local Destination: $local_base_dir"
  echo "Parallel Jobs: $parallel_jobs"

  # 3. 执行并发拉取
  grep -vE '^\s*(#|$)' "$retina_file" | \
  parallel --line-buffer -j "$parallel_jobs" '
    host=$(echo {} | xargs)
    # 针对每个 host 创建独立的本地存放目录
    target_dir="${local_base_dir}/${host}"
    mkdir -p "$target_dir"
    
    echo "[{%}] >>> Processing ${host}..."
    
    # rsync 执行
    # --numeric-ids: 避免远端和本地 UID/GID 不一致导致的权限映射错误
    # -z: 压缩传输，对于索引文件效果极佳
    if rsync -avz \
        --partial \
        --numeric-ids \
        --info=stats2 \
        -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
        "${user}@${host}:${remote_disk}" \
        "$target_dir/"; then
      echo "[OK] >>> ${host} collected to ${target_dir}"
    else
      echo "[ERROR] <<< ${host} failed" >&2
    fi
  '
}

dispatch_retina_indexes_parallel() {
  local local_base_dir="${1:-/home/ubuntu/disk6/collected_indexes}"
  local remote_disk="${2:-/home/ubuntu/disk1}"
  local parallel_jobs="${3:-8}"
  local user="ubuntu"

  if [[ ! -d "$local_base_dir" ]]; then
    echo "Error: local directory not found: $local_base_dir" >&2
    return 1
  fi

  # 规范化远程路径：确保以 / 结尾
  [[ "$remote_disk" != */ ]] && remote_disk="$remote_disk/"

  export user remote_disk local_base_dir

  echo "=== Starting Parallel Dispatch (Push) ==="
  echo "Local Source: $local_base_dir"
  echo "Remote Destination: $remote_disk"
  echo "Parallel Jobs: $parallel_jobs"

  # 获取本地目录下所有的子目录（每个子目录名即为 host）
  # 使用 find 只查找一级目录，避免深度遍历
  find "$local_base_dir" -maxdepth 1 -mindepth 1 -type d | \
  parallel --line-buffer -j "$parallel_jobs" '
    src_dir={}
    # 提取目录名作为目标主机名
    host=$(basename "$src_dir")
    
    # 规范化本地源路径：确保以 / 结尾，同步目录下的内容
    [[ "$src_dir" != */ ]] && src_dir="${src_dir}/"

    echo "[{%}] >>> Dispatching to ${host}..."
    
    # 执行 rsync 推送
    # --delete: 关键参数，确保远程目录与本地备份完全一致（删除远程多余文件）
    if rsync -avz --delete \
        --partial \
        --numeric-ids \
        --info=stats2 \
        -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
        "$src_dir" \
        "${user}@${host}:${remote_disk}"; then
      echo "[OK] >>> ${host} dispatch finished"
    else
      echo "[ERROR] <<< ${host} dispatch failed" >&2
    fi
  '
}
