# Clash Docker环境使用指南

本文档提供在没有systemd的Docker容器环境中使用Clash的指南。

## 安装位置

Clash已安装在: `/opt/clash`

## 基本命令

### 启动 Clash
```bash
source /opt/clash/start_clash.sh
```
这将启动Clash服务并设置代理环境变量。

### 停止 Clash
```bash
source /opt/clash/stop_clash.sh
```
这将停止Clash服务并清除代理环境变量。

## Web 控制台

Clash Web控制台地址：`http://127.0.0.1:9000/ui`

如果需要在容器外访问控制台，请确保将容器的9000端口映射到主机。

## 配置文件

- 主配置文件：`/opt/clash/config.yaml`
- Mixin配置文件：`/opt/clash/mixin.yaml`
- 运行时配置：`/opt/clash/runtime.yaml`

## 更新配置

我们提供了一个简便的脚本来更新配置：

```bash
# 使用新的订阅链接更新配置
/opt/clash/update_config.sh 您的订阅链接

# 使用之前保存的链接更新配置
/opt/clash/update_config.sh

# 更新完成后，脚本会提示您重启Clash
source /opt/clash/stop_clash.sh
source /opt/clash/start_clash.sh
```

## 日志查看

查看Clash运行日志：
```bash
cat /opt/clash/clash.log
```

## 排障

如果Clash无法启动，请检查：
1. 配置文件是否有效
2. 日志文件中的错误信息
3. 端口是否被占用

## 注意事项

- 此安装方式专为Docker容器环境设计，没有使用systemd服务管理
- 每次启动容器后，需要手动启动Clash：`source /opt/clash/start_clash.sh`
- curl可能不存在于您的容器中，如果遇到"curl: command not found"错误，您可以安装curl或使用wget