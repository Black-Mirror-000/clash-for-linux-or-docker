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

### 设置代理环境变量
```bash
source /opt/clash/set_proxy.sh
```

**重要说明**：在Docker环境中，每次打开新的终端窗口时，代理环境变量不会自动传递。您需要在每个新的终端会话中执行此命令来设置代理环境变量，否则该终端无法通过代理连接外网。

该脚本会执行以下操作：
1. 设置所有必要的代理环境变量（http_proxy, https_proxy, all_proxy等）
2. 显示当前设置的代理信息
3. 自动测试代理连接是否正常工作
4. 提供故障排除提示（如果测试失败）

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

如果您可以连接到Clash但无法访问外网：
1. 检查代理环境变量是否正确设置：`echo $http_proxy $https_proxy`
2. 如果没有输出或输出为空，运行：`source /opt/clash/set_proxy.sh`
3. 确认Clash服务正在运行：`ps -ef | grep clash`
4. 测试代理连接：`curl -v -x http://127.0.0.1:7890 https://www.google.com`

## 新终端会话问题

Docker环境中的常见问题是在新终端窗口中代理不工作。这是因为每个新会话不会自动继承环境变量。

**解决方案**：
- 在每个新终端会话中执行：`source /opt/clash/set_proxy.sh`
- 将此命令添加到您的`.bashrc`或`.profile`文件以自动执行
- 如果使用别的Shell，添加到相应的配置文件中

**验证代理设置**：
```bash
# 检查代理环境变量
echo $http_proxy $https_proxy

# 测试代理连接
curl -v -x $http_proxy https://www.google.com
```

## 注意事项

- 此安装方式专为Docker容器环境设计，没有使用systemd服务管理
- 每次启动容器后，需要手动启动Clash：`source /opt/clash/start_clash.sh`
- 每次打开新终端窗口，需要手动设置代理：`source /opt/clash/set_proxy.sh`
- curl可能不存在于您的容器中，如果遇到"curl: command not found"错误，您可以安装curl或使用wget