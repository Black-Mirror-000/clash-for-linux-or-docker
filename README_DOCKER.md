# Docker环境中的Clash使用说明

## 常用命令

### 1. 启动和停止Clash

```bash
# 启动Clash服务并设置环境变量
source /opt/clash/start_clash.sh

# 停止Clash服务并清除环境变量
source /opt/clash/stop_clash.sh
```

### 2. 在新终端窗口中设置代理环境变量

每次打开新的终端窗口，都需要设置代理环境变量才能使用代理功能：

```bash
# 在新终端窗口中快速设置代理环境变量
source /opt/clash/set_proxy.sh
```

### 3. 更新订阅配置

```bash
# 更新Clash配置（需要提供订阅链接）
/opt/clash/update_config.sh 你的订阅链接URL

# 或者使用Docker专用的更新脚本（含更多错误处理）
/opt/clash/docker_update_config.sh -u 你的订阅链接URL -r
```

## 访问控制面板

Web控制台地址：http://localhost:9000/ui
控制台密码：admin

## 代理设置

- HTTP 代理：127.0.0.1:7890
- SOCKS5 代理：127.0.0.1:7890

## 故障排除

1. **代理无法连接外网**：
   - 检查Clash是否正在运行：`ps -ef | grep clash`
   - 重启Clash服务：先运行 `source /opt/clash/stop_clash.sh` 再运行 `source /opt/clash/start_clash.sh`
   - 查看日志：`cat /opt/clash/clash.log`

2. **新窗口不能使用代理**：
   - 在新窗口中运行：`source /opt/clash/set_proxy.sh`

3. **配置更新失败**：
   - 确保提供了正确的订阅链接
   - 使用Docker专用的更新脚本：`/opt/clash/docker_update_config.sh -h` 查看帮助

4. **检查环境变量是否正确设置**：
   - 运行 `echo $http_proxy $https_proxy` 检查是否有输出
   - 如果没有输出，运行 `source /opt/clash/set_proxy.sh` 设置环境变量 