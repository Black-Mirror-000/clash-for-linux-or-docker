#!/bin/bash
# shellcheck disable=SC1091
. script/common.sh
. script/clashctl.sh

# 检查环境 - 修改以适应Docker环境
_docker_env() {
    [ "$(whoami)" != "root" ] && [ -z "$DOCKER_ENV" ] && _error_quit "需要 root 或 sudo 权限执行"
    [ "$(ps -p $$ -o comm=)" != "bash" ] && _error_quit "当前终端不是 bash"
    # 检测是否在Docker中运行
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup; then
        export DOCKER_ENV=true
        _okcat '🐳' "检测到Docker环境，将使用脚本方式管理Clash"
    fi
    # 检查systemd是否存在，不存在则使用Docker模式
    if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
        export DOCKER_ENV=true
        _failcat '⚠️' "系统不具备 systemd，将使用脚本方式管理Clash"
    fi
}

# 替换原始的环境验证
#_valid_env
_docker_env

[ -d "$CLASH_BASE_DIR" ] && _error_quit "请先执行卸载脚本,以清除安装路径：$CLASH_BASE_DIR"

_get_kernel
# shellcheck disable=SC2086
install -D -m +x <(gzip -dc $ZIP_KERNEL) "$BIN_KERNEL"
# shellcheck disable=SC2086
tar -xf $ZIP_SUBCONVERTER -C "$BIN_BASE_DIR"
# shellcheck disable=SC2086
tar -xf $ZIP_YQ -C "${BIN_BASE_DIR}" && install -m +x ${BIN_BASE_DIR}/yq_* "$BIN_YQ"

_valid_config "$RESOURCES_CONFIG" || {
    prompt=$(_okcat '✈️ ' '输入订阅链接：')
    read -p "$prompt" -r url
    _okcat '⏳' '正在下载...'
    # start=$(date +%s)>&/dev/null
    _download_config "$RESOURCES_CONFIG" "$url" || {
        rm -rf "$CLASH_BASE_DIR"
        _error_quit "下载失败: 请将配置内容写入 $RESOURCES_CONFIG 后重新安装"
    }
    _valid_config "$RESOURCES_CONFIG" || {
        rm -rf "$CLASH_BASE_DIR"
        _error_quit "配置无效，请检查：$RESOURCES_CONFIG"
    }
}
# end=$(date +%s) >&/dev/null
# _okcat '⌛' $((end-start))s
_okcat '✅' '配置可用'
echo "$url" >"$CLASH_CONFIG_URL"

/bin/cp -rf script "$CLASH_BASE_DIR"
/bin/ls "$RESOURCES_BASE_DIR" | grep -Ev 'zip|png' | xargs -I {} /bin/cp -rf "${RESOURCES_BASE_DIR}/{}" "$CLASH_BASE_DIR"
tar -xf "$ZIP_UI" -C "$CLASH_BASE_DIR"

_merge_config_restart

# 根据环境创建不同的启动方式
if [ "$DOCKER_ENV" = "true" ]; then
    # 创建Docker环境下的启动脚本
    cat <<EOF >"$CLASH_BASE_DIR/start_clash.sh"
#!/bin/bash

CLASH_BASE_DIR='/opt/clash'
BIN_KERNEL="\${CLASH_BASE_DIR}/bin/$(basename "$BIN_KERNEL")"
CLASH_CONFIG_RUNTIME="\${CLASH_BASE_DIR}/runtime.yaml"

# 检查内核是否存在
if [ ! -f "\$BIN_KERNEL" ]; then
  echo "错误：找不到Clash内核 \$BIN_KERNEL"
  exit 1
fi

# 检查配置文件是否存在
if [ ! -f "\$CLASH_CONFIG_RUNTIME" ]; then
  echo "错误：找不到Clash配置文件 \$CLASH_CONFIG_RUNTIME"
  exit 1
fi

# 如果存在PID文件，检查进程是否存在，存在则杀死
if [ -f "\${CLASH_BASE_DIR}/clash.pid" ]; then
  pid=\$(cat "\${CLASH_BASE_DIR}/clash.pid")
  if kill -0 \$pid 2>/dev/null; then
    echo "Clash 已在运行，正在停止..."
    kill \$pid
    sleep 1
  fi
  rm -f "\${CLASH_BASE_DIR}/clash.pid"
fi

# 启动Clash
echo "正在启动Clash..."
nohup \$BIN_KERNEL -d \$CLASH_BASE_DIR -f \$CLASH_CONFIG_RUNTIME > "\${CLASH_BASE_DIR}/clash.log" 2>&1 &
echo \$! > "\${CLASH_BASE_DIR}/clash.pid"
echo "Clash已启动，PID: \$(cat \${CLASH_BASE_DIR}/clash.pid)"

# 获取混合端口
MIXED_PORT=\$(\${CLASH_BASE_DIR}/bin/yq '.mixed-port // "7890"' \$CLASH_CONFIG_RUNTIME)
UI_PORT=\$(\${CLASH_BASE_DIR}/bin/yq '.external-controller // "0.0.0.0:9090"' \$CLASH_CONFIG_RUNTIME | cut -d':' -f2)

# 设置环境变量
echo "设置代理环境变量，混合端口: \$MIXED_PORT"
export http_proxy="http://127.0.0.1:\${MIXED_PORT}"
export https_proxy="\$http_proxy"
export HTTP_PROXY="\$http_proxy"
export HTTPS_PROXY="\$http_proxy"
export all_proxy="socks5://127.0.0.1:\${MIXED_PORT}"
export ALL_PROXY="\$all_proxy"
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="\$no_proxy"

# 打印Web控制台信息
local_ip=\$(hostname -I | awk '{print \$1}')
public_ip=\$(curl -s --noproxy "*" --connect-timeout 2 api64.ipify.org || echo "无法获取")

echo -e "\n"
echo -e "╔═══════════════════════════════════════════════╗"
echo -e "║                🌐 Web 控制台                  ║"
echo -e "║═══════════════════════════════════════════════║"
echo -e "║                                               ║"
echo -e "║     🔓 注意放行端口：\$UI_PORT                    ║"
echo -e "║     🏠 内网：http://\${local_ip}:\${UI_PORT}/ui    ║"
echo -e "║     🌏 公网：http://\${public_ip:-无法获取}:\${UI_PORT}/ui ║"
echo -e "║                                               ║"
echo -e "╚═══════════════════════════════════════════════╝"
echo -e "\n"

echo "使用方法: 用 'source $CLASH_BASE_DIR/start_clash.sh' 命令启动并设置环境变量"
echo "         用 'source $CLASH_BASE_DIR/stop_clash.sh' 命令停止并清除环境变量"
EOF

    # 创建停止脚本
    cat <<EOF >"$CLASH_BASE_DIR/stop_clash.sh"
#!/bin/bash

CLASH_BASE_DIR='/opt/clash'

# 如果存在PID文件，检查进程是否存在，存在则杀死
if [ -f "\${CLASH_BASE_DIR}/clash.pid" ]; then
  pid=\$(cat "\${CLASH_BASE_DIR}/clash.pid")
  if kill -0 \$pid 2>/dev/null; then
    echo "正在停止Clash进程 (PID: \$pid)..."
    kill \$pid
    sleep 1
  else
    echo "Clash进程不存在，PID文件可能已过期"
  fi
  rm -f "\${CLASH_BASE_DIR}/clash.pid"
else
  echo "Clash似乎没有运行"
fi

# 清除代理环境变量
echo "清除代理环境变量"
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset all_proxy
unset ALL_PROXY
unset no_proxy
unset NO_PROXY

echo "Clash已停止，代理环境变量已清除"
EOF

    # 创建README.md说明文件
    cat <<EOF >"$CLASH_BASE_DIR/README.md"
# Clash Docker环境使用指南

本文档提供在没有 systemd 的Docker环境中使用 Clash 的指南。

## 基本命令

### 启动 Clash
\`\`\`bash
source /opt/clash/start_clash.sh
\`\`\`
这将启动 Clash 服务并设置代理环境变量。

### 停止 Clash
\`\`\`bash
source /opt/clash/stop_clash.sh
\`\`\`
这将停止 Clash 服务并清除代理环境变量。

### 更新订阅配置
\`\`\`bash
/opt/clash/update_config.sh [订阅链接]
\`\`\`
如果不提供链接，将使用上次保存的链接更新。

## Web 控制台

Clash Web 控制台地址：\`http://127.0.0.1:9090/ui\`

如果需要在容器外访问控制台，请确保将容器的 9090 端口映射到主机。

## 配置文件

- 主配置文件：\`/opt/clash/config.yaml\`
- Mixin 配置文件：\`/opt/clash/mixin.yaml\`
- 运行时配置：\`/opt/clash/runtime.yaml\`

若要更新配置，可通过以下命令：

```bash
# 使用订阅链接更新配置
/opt/clash/update_config.sh 您的订阅链接

# 使用之前保存的链接更新配置
/opt/clash/update_config.sh

# 更新完成后重启Clash
source /opt/clash/stop_clash.sh
source /opt/clash/start_clash.sh
```

## 日志查看

查看 Clash 运行日志：
\`\`\`bash
cat /opt/clash/clash.log
\`\`\`

## 注意事项

- 此安装方式专为Docker容器环境设计，没有使用 systemd 服务管理
- 每次启动容器后，需要手动启动 Clash：\`source /opt/clash/start_clash.sh\`
EOF

    # 给脚本添加执行权限
    chmod +x "$CLASH_BASE_DIR/start_clash.sh" "$CLASH_BASE_DIR/stop_clash.sh"
    
    # 创建更新配置脚本
    cat <<'EOF' > "$CLASH_BASE_DIR/update_config.sh"
#!/bin/bash

CLASH_BASE_DIR='/opt/clash'
CLASH_CONFIG_URL="${CLASH_BASE_DIR}/url"
CLASH_CONFIG_RAW="${CLASH_BASE_DIR}/config.yaml"
CLASH_CONFIG_RAW_BAK="${CLASH_CONFIG_RAW}.bak"
CLASH_CONFIG_MIXIN="${CLASH_BASE_DIR}/mixin.yaml"
CLASH_CONFIG_RUNTIME="${CLASH_BASE_DIR}/runtime.yaml"
CLASH_UPDATE_LOG="${CLASH_BASE_DIR}/clashupdate.log"
BIN_YQ="${CLASH_BASE_DIR}/bin/yq"

# 彩色输出函数
_color() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "\e[38;2;%d;%d;%dm" "$r" "$g" "$b"
}

_color_msg() {
    local color=$(_color "$1")
    local msg=$2
    local reset="\033[0m"
    printf "%b%s%b\n" "$color" "$msg" "$reset"
}

_okcat() {
    local color=#c8d6e5
    local emoji=😼
    [ $# -gt 1 ] && emoji=$1 && shift
    local msg="${emoji} $1"
    _color_msg "$color" "$msg" && return 0
}

_failcat() {
    local color=#fd79a8
    local emoji=😾
    [ $# -gt 1 ] && emoji=$1 && shift
    local msg="${emoji} $1"
    _color_msg "$color" "$msg" >&2 && return 1
}

# 主函数
update_config() {
    local url="$1"
    
    # 如果没有提供URL，尝试从URL文件读取
    if [ -z "$url" ]; then
        if [ -f "$CLASH_CONFIG_URL" ]; then
            url=$(cat "$CLASH_CONFIG_URL")
            _okcat "📑" "使用保存的订阅链接: $url"
        else
            _failcat "❌" "未提供订阅链接，使用方法: $0 <订阅链接>"
            return 1
        fi
    fi
    
    # 备份当前配置
    if [ -f "$CLASH_CONFIG_RAW" ]; then
        cp "$CLASH_CONFIG_RAW" "$CLASH_CONFIG_RAW_BAK"
        _okcat "💾" "已备份当前配置到: $CLASH_CONFIG_RAW_BAK"
    fi

    # 下载新配置
    _okcat "🌐" "正在下载配置..."
    if curl --silent --show-error --connect-timeout 10 --retry 3 --output "$CLASH_CONFIG_RAW" "$url"; then
        _okcat "✅" "配置下载成功"
    else
        _failcat "❌" "配置下载失败"
        # 如果有备份，则恢复
        if [ -f "$CLASH_CONFIG_RAW_BAK" ]; then
            cp "$CLASH_CONFIG_RAW_BAK" "$CLASH_CONFIG_RAW"
            _okcat "♻️" "已恢复备份配置"
        fi
        return 1
    fi

    # 测试配置有效性
    if [ -f "$CLASH_CONFIG_RAW" ] && [ "$(wc -l < "$CLASH_CONFIG_RAW")" -gt 1 ]; then
        _okcat "🔍" "正在验证配置..."
        
        # 合并配置
        if [ -f "$CLASH_CONFIG_MIXIN" ]; then
            "$BIN_YQ" -n "load(\"$CLASH_CONFIG_RAW\") * load(\"$CLASH_CONFIG_MIXIN\")" > "$CLASH_CONFIG_RUNTIME"
            _okcat "🔄" "已合并mixin配置生成运行时配置"
        else
            cp "$CLASH_CONFIG_RAW" "$CLASH_CONFIG_RUNTIME"
        fi
        
        # 更新URL记录
        echo "$url" > "$CLASH_CONFIG_URL"
        _okcat "📝" "已更新订阅链接记录"
        
        # 记录更新日志
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 订阅更新成功: $url" >> "$CLASH_UPDATE_LOG"
        
        _okcat "🎉" "配置更新成功，请重启Clash使配置生效:"
        echo "   source $CLASH_BASE_DIR/stop_clash.sh"
        echo "   source $CLASH_BASE_DIR/start_clash.sh"
    else
        _failcat "❌" "下载的配置无效"
        if [ -f "$CLASH_CONFIG_RAW_BAK" ]; then
            cp "$CLASH_CONFIG_RAW_BAK" "$CLASH_CONFIG_RAW"
            _okcat "♻️" "已恢复备份配置"
        fi
        return 1
    fi
}

# 执行更新
update_config "$1"
EOF
    chmod +x "$CLASH_BASE_DIR/update_config.sh"

    # 更新bashrc
    [ -n "$(tail -1 "$BASHRC")" ] && echo >>"$BASHRC"
    echo "source $CLASH_BASE_DIR/script/common.sh" >>"$BASHRC"

    # 立即启动Clash
    source "$CLASH_BASE_DIR/start_clash.sh"
    
    _okcat '🐳' 'Docker模式安装完成'
    _okcat '🚀' "请使用 'source $CLASH_BASE_DIR/start_clash.sh' 启动Clash"
    _okcat '📝' "详细使用说明请查看：$CLASH_BASE_DIR/README.md"
    _okcat '🎉' 'enjoy 🎉'
else
    # 标准systemd安装方式
    cat <<EOF >/etc/systemd/system/clash.service
[Unit]
Description=$BIN_KERNEL_NAME Daemon, A[nother] Clash Kernel.

[Service]
Type=simple
Restart=always
ExecStart=${BIN_KERNEL} -d ${CLASH_BASE_DIR} -f ${CLASH_CONFIG_RUNTIME}

[Install]
WantedBy=multi-user.target
EOF

    [ -n "$(tail -1 "$BASHRC")" ] && echo >>"$BASHRC"
    echo "source $CLASH_BASE_DIR/script/common.sh && source $CLASH_BASE_DIR/script/clashctl.sh" >>"$BASHRC"

    systemctl daemon-reload
    clashon
    # shellcheck disable=SC2015
    systemctl enable clash >&/dev/null && _okcat '🚀' "已设置开机自启" || _failcat '💥' "设置自启失败"
    _okcat '🎉' 'enjoy 🎉'
    clashui
    clash
fi
