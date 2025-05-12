# Host-Node-WS

一个集成的WebSocket服务器部署工具，自动安装哪吒探针、配置WebSocket服务，简化部署流程。

## 功能特点

- 一键部署WebSocket服务器
- 自动安装和配置哪吒探针
- 智能检测并使用最佳Node.js环境
- 自动生成UUID或使用自定义UUID
- 支持自定义端口和节点名称
- 提供订阅地址，方便客户端配置

## 快速开始

### 方法一：直接运行安装脚本

```bash
curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup_integrated.sh -o setup_integrated.sh && chmod +x setup_integrated.sh && ./setup_integrated.sh
```

### 方法二：手动下载和运行

1. 下载安装脚本
```bash
curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup_integrated.sh -o setup_integrated.sh
```

2. 添加执行权限
```bash
chmod +x setup_integrated.sh
```

3. 运行脚本
```bash
./setup_integrated.sh
```

## 配置说明

安装过程中，脚本会询问以下信息：

- **域名**：您的网站域名
- **监听端口**：WebSocket服务器监听的端口（默认：3000）
- **节点名称**：显示在订阅信息中的节点名称（默认：NodeWS）
- **UUID**：可以自动生成或手动输入
- **哪吒服务器地址**：哪吒探针服务器地址（格式：nz.example.com:5555）
- **哪吒客户端密钥**：哪吒探针的客户端密钥

## 环境变量说明

WebSocket服务器支持以下环境变量配置：

| 变量名 | 是否必须 | 默认值 | 备注 |
|--------|----------|--------|------|
| UUID | 否 | 自动生成 | 用于客户端连接验证 |
| PORT | 否 | 3000 | 监听端口 |
| NEZHA_SERVER | 否 | | 哪吒服务器地址 |
| NEZHA_KEY | 否 | | 哪吒客户端密钥 |
| NAME | 否 | | 节点名称前缀 |
| DOMAIN | 是 | | 项目域名，不包括https://前缀 |
| SUB_PATH | 否 | sub | 订阅路径 |
| AUTO_ACCESS | 否 | true | 是否开启自动访问保活 |

## 管理服务

### 停止服务

```bash
# 停止Node.js应用
kill $(cat ~/domains/您的域名/public_html/node.pid)

# 卸载哪吒探针
cd ~/domains/您的域名/public_html && ./agent.sh uninstall
```

### 查看日志

```bash
cat ~/domains/您的域名/public_html/node.log
```

## 故障排除

如果自动部署失败，脚本会创建一个README.txt文件，提供手动配置的步骤。

常见问题：

1. **Node.js应用无法启动**：检查node.log文件查看错误信息
2. **哪吒探针未连接**：确认服务器地址和密钥是否正确
3. **端口被占用**：尝试更换其他端口

## 贡献

欢迎提交问题和改进建议到GitHub仓库：[https://github.com/mqiancheng/host-node-ws](https://github.com/mqiancheng/host-node-ws)
