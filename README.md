# WebSocket服务器部署工具

这是一个简化的WebSocket服务器部署工具，用于在共享主机环境中快速部署WebSocket服务和哪吒探针。

## 特点

- 简单易用的交互式菜单界面
- 自动检测域名目录和Node.js环境
- 引导用户创建Node.js应用
- 自动安装和配置WebSocket服务
- 可选安装和配置哪吒探针
- 详细的日志记录

## 使用方法

### 快速开始

1. 下载脚本：

```bash
curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup.sh -o setup.sh && chmod +x setup.sh
```

2. 运行脚本：

```bash
./setup.sh
```

### 功能选项

脚本提供以下功能选项：

1. **修改配置文件**：
   - 设置域名、节点名称、端口、UUID等配置信息
   - 可选配置哪吒探针服务器地址和密钥
   - 所有配置信息保存在`~/tmp/ws_config/ws_config.conf`文件中

2. **启动WebSocket代理服务**：
   - 自动创建index.js和package.json文件
   - 使用Node.js虚拟环境启动服务
   - 安装依赖并启动服务

3. **启动哪吒探针**：
   - 下载并安装哪吒探针
   - 使用保存的配置信息启动探针

4. **退出脚本**：
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
- **哪吒服务器地址**：哪吒探针服务器地址（可选）
- **哪吒客户端密钥**：哪吒探针的客户端密钥（可选）
- **TLS连接**：是否使用TLS连接哪吒服务器（默认：是）

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

WebSocket服务启动后，您可以通过以下地址获取VLESS订阅：

```
https://您的域名/sub
```

例如：`https://example.com/sub`

## 常见问题

1. **WebSocket服务无法启动**：
   - 确保已在控制面板中创建Node.js应用
   - 查看node.log文件了解错误信息
   - 确保端口未被占用

2. **哪吒探针未连接**：
   - 确认服务器地址和密钥是否正确
   - 确保TLS设置正确（大多数哪吒服务器需要启用TLS）
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
- 命令（如果您选择"阻止电子邮件"选项）：`cd $HOME && $HOME/setup.sh check_and_start_all`
- 命令（如果您不选择"阻止电子邮件"选项）：`cd $HOME && $HOME/setup.sh check_and_start_all > /dev/null 2>&1`

**定期检查并重启服务**：
- 频率：每5分钟（Cron表达式：`*/5 * * * *`）
- 命令（如果您选择"阻止电子邮件"选项）：`cd $HOME && $HOME/setup.sh check_and_start_all`
- 命令（如果您不选择"阻止电子邮件"选项）：`cd $HOME && $HOME/setup.sh check_and_start_all > /dev/null 2>&1`

> **注意**：许多共享主机的控制面板在选择"阻止电子邮件"选项时会自动在命令末尾添加 `>/dev/null 2>&1`。如果您发现命令变成了 `cd $HOME && $HOME/setup.sh check_and_start_all > /dev/null 2>&1 >/dev/null 2>&1`，不用担心，这种重复的重定向不会影响脚本的正常执行。

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

- 脚本默认使用TLS连接哪吒服务器
- 配置信息保存在`~/tmp/ws_config/ws_config.conf`文件中
- 日志文件存储在`~/tmp/ws_setup_logs/`目录下
- 强制重新安装会删除所有相关文件和日志
- 自动保活功能需要先运行脚本并完成配置

## 贡献

欢迎提交问题和改进建议到GitHub仓库：[https://github.com/mqiancheng/host-node-ws](https://github.com/mqiancheng/host-node-ws)

## 许可证

MIT
