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