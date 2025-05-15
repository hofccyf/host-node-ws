# WebSocket服务器部署工具

这是一个简化的WebSocket服务器部署工具，用于在共享主机环境中快速部署WebSocket服务和哪吒探针。

## 目录

- [特点](#特点)
- [使用方法](#使用方法)
  - [快速开始](#快速开始)
  - [功能选项](#功能选项)
- [配置选项](#配置选项)
- [创建Node.js应用](#创建nodejs应用)
- [日志记录](#日志记录)
- [订阅地址](#订阅地址)
- [常见问题](#常见问题)
- [自动保活功能](#自动保活功能)
  - [设置自动保活](#设置自动保活)
  - [自动保活工作原理](#自动保活工作原理)
- [注意事项](#注意事项)
- [贡献](#贡献)
- [许可证](#许可证)

## 特点

- 简单易用的交互式菜单界面
- 自动检测域名目录和Node.js环境
- 引导用户创建Node.js应用
- 自动安装和配置WebSocket服务
- 可选安装和配置哪吒探针（支持v0和v1版本自动识别）
- 支持自定义反代域名
- 多协议支持（VLESS/VMess/Trojan）
- 支持订阅单一协议或全部协议
- 显示订阅地址，节点名称包含协议类型
- 运行统计功能
- 详细的日志记录

## 使用方法

### 快速开始

一键下载并运行脚本：

```bash
curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh
```

### 功能选项

脚本提供以下功能选项：

1. **修改配置文件**：
   - 设置域名、节点名称、端口、UUID等配置信息
   - 选择代理协议（VLESS/VMess/Trojan/全部）
   - 可选配置哪吒探针服务器地址和密钥（自动识别v0/v1版本）
   - 所有配置信息保存在`~/tmp/ws_config/ws_config.conf`文件中

2. **启动WebSocket代理服务**：
   - 自动创建index.js和package.json文件
   - 使用Node.js虚拟环境启动服务
   - 安装依赖并启动服务
   - 显示订阅地址，根据选择的协议显示相应信息

3. **启动哪吒探针**：
   - 下载并安装哪吒探针
   - 使用保存的配置信息启动探针

0. **退出脚本**：
   - 安全退出脚本

5. **强制重新安装**：
   - 停止所有相关进程
   - 删除所有相关文件
   - 清理配置信息和日志

## 配置选项

在"修改配置文件"选项中，您需要提供以下信息：

- **域名**：脚本会自动扫描您的域名目录，您可以从列表中选择或手动输入
- **节点名称**：显示在订阅信息中的节点名称（默认：hostvps）
- **监听端口**：WebSocket服务器监听的端口（默认：3000）
- **UUID**：可以自动生成或手动输入，用于WebSocket连接验证
- **反代域名**：用于代理连接的反代域名（默认：www.visa.com.tw）
- **哪吒服务器地址**：哪吒探针服务器地址（可选，自动识别v0/v1版本）
  - v1格式：`nz.example.com:443`（包含端口号）
  - v0格式：`nz.example.com`（不包含端口号，会额外询问端口）
- **哪吒客户端密钥**：哪吒探针的客户端密钥（可选）

配置文件保存在`~/tmp/ws_config/ws_config.conf`中，包含以下内容：

```
# WebSocket服务配置
DOMAIN="yourdomain.com"           # 您的域名
DOMAIN_DIR="/home/user/domains/yourdomain.com/public_html"  # 域名目录
NODE_NAME="NodeWS"                # 节点名称
PORT="3000"                       # 内部端口
UUID="a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6"  # UUID
CF_DOMAIN="www.visa.com.tw"       # 反代域名
PROTOCOL="vless"                  # 代理协议
PROTOCOL_NAME="VLESS"             # 协议名称

# 哪吒探针配置
NEZHA_SERVER="nezha.example.com:5555"  # 哪吒服务器地址（v1格式）
NEZHA_KEY="your_nezha_key"        # 哪吒客户端密钥
NEZHA_PORT=""                     # 哪吒v0版本端口（仅v0版本需要）
NEZHA_TLS="true"                  # v1版本：true/false，v0版本：--tls/空
```

## 创建Node.js应用

如果脚本检测到您尚未创建Node.js应用，它会引导您完成以下步骤：

1. 进入控制面板 -> Node.js APP
2. 点击"创建应用程序"
3. Node.js版本: 选择最新版本
4. Application root: domains/您的域名/public_html
5. Application startup file: index.js
6. 点击"创建"按钮

创建完成后，重新运行脚本继续配置。

## 日志记录

脚本会在用户主目录下创建详细的日志文件（格式：`~/tmp/ws_setup_logs/ws_setup_日期时间.log`），记录安装过程中的每一步操作。如果遇到问题，请查看此日志文件以获取详细信息。

## 订阅地址

WebSocket服务启动后，脚本会自动显示您的VLESS订阅地址：

```
您的VLESS订阅地址是：https://您的域名/sub
```

例如：`https://example.com/sub`

订阅地址会返回一个Base64编码的VLESS链接，可以直接导入到支持VLESS协议的客户端中。

VLESS链接使用您配置的反代域名作为服务器地址，使用您的实际域名作为SNI和Host参数，这样可以提高连接成功率。

## 常见问题

1. **WebSocket服务无法启动**：
   - 确保已在控制面板中创建Node.js应用
   - 查看node.log文件了解错误信息
   - 确保端口未被占用

2. **哪吒探针未连接**：
   - 确认服务器地址和密钥是否正确
   - 检查是否正确识别了哪吒版本（v0/v1）
   - 检查网络连接是否正常

3. **订阅地址返回"It works!"**：
   - 检查WebSocket服务是否正常启动
   - 查看node.log文件了解可能的错误
   - 访问`/debug`路径查看当前配置信息

4. **域名目录检测失败**：
   - 确认您的域名是否已在控制面板中创建
   - 检查域名目录结构是否正确

## 自动保活功能

脚本提供了自动保活功能，可以通过定时任务自动检查并重启服务。这对于共享主机环境特别有用，因为服务器可能会定期清理长时间运行的进程。

### 设置自动保活

1. 在控制面板中找到"Cron Jobs"（定时任务）功能
2. 添加以下两个定时任务：

**系统重启后自动启动服务**：
- 选择"Run on @reboot"选项
- 命令：`cd $HOME && $HOME/setup.sh check_and_start_all`（如果使用统一入口脚本）
- 或者：`cd $HOME && $HOME/setup-ws.sh check_and_start_all`（如果直接使用WebSocket模式脚本）
- 如果您担心收到电子邮件通知，请选择"阻止电子邮件"选项

**定期检查并重启服务**：
- 频率：每5-10分钟（Cron表达式：`*/10 * * * *`）
- 命令：`cd $HOME && $HOME/setup.sh check_and_start_all`（如果使用统一入口脚本）
- 或者：`cd $HOME && $HOME/setup-ws.sh check_and_start_all`（如果直接使用WebSocket模式脚本）
- 如果您担心收到电子邮件通知，请选择"阻止电子邮件"选项

> **注意**：许多共享主机的控制面板在选择"阻止电子邮件"选项时会自动在命令末尾添加重定向（如 `>/dev/null 2>&1`）。这是正常现象，不会影响脚本的执行。即使出现重复的重定向也不用担心，命令仍然可以正常工作。

### 自动保活工作原理

1. **WebSocket服务保活**：
   - 脚本会检查WebSocket服务是否运行
   - 如果服务未运行，会通过访问订阅地址（`/sub`）来触发服务启动
   - 这利用了Web服务器的按需启动机制

2. **哪吒探针保活**：
   - 脚本会检查哪吒探针是否运行
   - 如果探针未运行，会使用配置文件中的信息重新启动探针

3. **日志记录**：
   - 自动保活的操作会记录在`~/tmp/ws_setup_logs/cron_autorestart.log`文件中
   - 您可以查看此日志了解自动保活的运行情况

## 注意事项

- 哪吒探针服务器地址格式会自动识别v0/v1版本
- 强制重新安装会删除所有相关文件和日志
- 自动保活功能需要先运行脚本并完成配置
- 统一入口脚本会自动下载缺失的脚本文件
- 配置信息保存在`~/tmp/ws_config/ws_config.conf`文件中
- 日志文件存储在`~/tmp/ws_setup_logs/`目录下
- 仅支持VLESS协议

## 贡献

欢迎提交问题和改进建议到GitHub仓库：[https://github.com/mqiancheng/host-node-ws](https://github.com/mqiancheng/host-node-ws)

## 许可证

MIT
