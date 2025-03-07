#!/bin/bash
# shellcheck disable=SC1091
. script/common.sh
. script/clashctl.sh

# 检测Docker环境
if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup || [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    export DOCKER_ENV=true
    _okcat '🐳' "检测到Docker环境，将使用脚本方式卸载Clash"
    
    # 如果存在，使用stop_clash.sh脚本停止服务
    if [ -f "$CLASH_BASE_DIR/stop_clash.sh" ]; then
        source "$CLASH_BASE_DIR/stop_clash.sh"
    else
        # 尝试直接杀死进程
        pkill -f "$(basename $BIN_KERNEL)" || true
        # 清除环境变量
        unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY
    fi
else
    # 原始的systemd环境检查
    [ "$(whoami)" != "root" ] && _error_quit "需要 root 或 sudo 权限执行"
    [ "$(ps -p $$ -o comm=)" != "bash" ] && _error_quit "当前终端不是 bash"
    [ "$(ps -p 1 -o comm=)" != "systemd" ] && _error_quit "系统不具备 systemd"
    
    # 使用systemctl停止服务
    clashoff >&/dev/null
    systemctl disable clash >&/dev/null
    rm -f /etc/systemd/system/clash.service
    systemctl daemon-reload
fi

# 清理文件和配置
rm -rf "$CLASH_BASE_DIR"
sed -i '/clashupdate/d' "$CLASH_CRON_TAB" 2>/dev/null || true
sed -i '/clashctl.sh/d' "$BASHRC" 2>/dev/null || true
sed -i '/common.sh/d' "$BASHRC" 2>/dev/null || true

_okcat '✨' '已卸载，相关配置已清除'

# 未 export 的变量和函数不会被继承
exec bash
