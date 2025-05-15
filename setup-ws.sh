#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本版本
VERSION="1.3.2"

# 获取运行统计
get_run_stats() {
    # 使用curl获取统计数据，超时设置为3秒
    local stats_data=$(curl -s -m 3 "https://visit.okyes.filegear-sg.me/?url=https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup.sh" 2>/dev/null)

    # 解析统计数据
    if [ -n "$stats_data" ]; then
        TODAY=$(echo "$stats_data" | grep -o '"daily_count":[0-9]*' | grep -o '[0-9]*')
        TOTAL=$(echo "$stats_data" | grep -o '"total_count":[0-9]*' | grep -o '[0-9]*')

        # 如果解析失败，设置默认值
        TODAY=${TODAY:-0}
        TOTAL=${TOTAL:-0}
    else
        # 如果获取失败，设置默认值
        TODAY=0
        TOTAL=0
    fi
}

# 创建日志目录
LOG_DIR="$HOME/tmp/ws_setup_logs"
mkdir -p "$LOG_DIR"

# 清理旧日志文件（超过7天的）
find "$LOG_DIR" -type f -name "ws_setup_*.log" -mtime +7 -delete 2>/dev/null

# 设置日志文件
if [ "$1" = "check_and_start_all" ]; then
    # cron任务执行，使用固定的日志文件
    LOG_FILE="$LOG_DIR/cron_autorestart.log"
    # 如果日志文件超过1MB，则清空它
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null) -gt 1048576 ]; then
        echo "=== 日志文件已重置 $(date) ===" > "$LOG_FILE"
    fi
else
    # 手动执行，创建带时间戳的日志文件
    LOG_FILE="$LOG_DIR/ws_setup_$(date +%Y%m%d%H%M%S).log"
    touch "$LOG_FILE"
    echo "=== 安装日志开始 $(date) ===" > "$LOG_FILE"
fi

# 创建配置目录和文件
CONFIG_DIR="$HOME/tmp/ws_config"
mkdir -p "$CONFIG_DIR"
CONFIG_FILE="$CONFIG_DIR/ws_config.conf"

# 打印带颜色的信息并记录日志
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $(date +%H:%M:%S) $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[SUCCESS] $(date +%H:%M:%S) $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $(date +%H:%M:%S) $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $(date +%H:%M:%S) $1" >> "$LOG_FILE"
}

# 记录调试信息到日志（只在关键点记录）
log_debug() {
    # 只记录重要的调试信息
    if [[ "$1" == *"配置文件"* ]] || [[ "$1" == *"启动"* ]] || [[ "$1" == *"停止"* ]] || [[ "$1" == *"错误"* ]]; then
        echo "[DEBUG] $(date +%H:%M:%S) $1" >> "$LOG_FILE"
    fi
}

# 获取用户名
username=$(whoami)
print_info "检测到用户名: $username"

# 检查配置文件是否存在
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_warning "未找到配置文件，请先执行'修改配置文件'选项"
        return 1
    fi
    return 0
}

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

# 检查进程状态
check_processes() {
    NODE_RUNNING=false
    NEZHA_RUNNING=false

    # WebSocket服务进程检测 - 支持多种Node.js进程类型
    if ps aux | grep "lsnode:" | grep -v grep > /dev/null; then
        NODE_RUNNING=true
        NODE_PID=$(ps aux | grep "lsnode:" | grep -v grep | awk '{print $2}')
        NODE_TYPE="lsnode"

    # 检测通用node index.js进程
    elif ps aux | grep "node index.js" | grep -v grep > /dev/null; then
        NODE_RUNNING=true
        NODE_PID=$(ps aux | grep "node index.js" | grep -v grep | awk '{print $2}')
        NODE_TYPE="node"
    fi

    # 简化的哪吒探针进程检测
    if pgrep -u "$USER" -f "nezha-agent" > /dev/null; then
        NEZHA_RUNNING=true
        NEZHA_PID=$(pgrep -u "$USER" -f "nezha-agent")
    fi
}

# 显示进程状态
show_status() {
    check_processes

    print_info "进程状态："
    if [ "$NODE_RUNNING" = true ]; then
        echo "- WebSocket服务: 运行中 ($NODE_TYPE进程, PID: $NODE_PID)"
    else
        echo "- WebSocket服务: 未运行"
    fi

    if [ "$NEZHA_RUNNING" = true ]; then
        echo "- 哪吒探针: 运行中 (PID: $NEZHA_PID)"
    else
        echo "- 哪吒探针: 未运行"
    fi
}

# 引导用户创建Node.js应用
guide_nodejs_creation() {
    print_info "请按照以下步骤在控制面板中创建Node.js应用程序:"
    echo "1. 进入控制面板 -> Node.js APP"
    echo "2. 点击\"创建应用程序\""
    echo "3. Node.js版本: 选择V20或者V18版本"
    echo "4. Application root: domains/$1/public_html"
    echo "5. Application startup file: index.js"
    echo "6. 点击\"创建\"按钮"
    echo ""
    print_info "创建完成后，请重新运行此脚本"
}

# 修改配置文件
modify_config() {
    print_info "修改配置文件..."

    # 检查domains目录
    domains_dir="/home/$username/domains"
    if [ ! -d "$domains_dir" ]; then
        print_error "未找到domains目录: $domains_dir"
        return 1
    fi

    # 列出所有域名目录
    print_info "正在扫描域名目录..."
    domains=()
    for dir in "$domains_dir"/*; do
        if [ -d "$dir" ]; then
            domain_name=$(basename "$dir")
            domains+=("$domain_name")
        fi
    done

    # 显示域名列表
    if [ ${#domains[@]} -eq 0 ]; then
        print_warning "未找到任何域名目录，请手动输入域名"
        read -p "请输入您的域名 (例如: example.com): " domain
    else
        echo "检测到以下域名:"
        for i in "${!domains[@]}"; do
            echo "[$i] ${domains[$i]}"
        done

        echo "[m] 手动输入其他域名"
        read -p "请选择域名 [0-$((${#domains[@]}-1))/m]: " domain_choice

        if [[ "$domain_choice" == "m" ]]; then
            read -p "请输入您的域名 (例如: example.com): " domain
        elif [[ "$domain_choice" =~ ^[0-9]+$ ]] && [ "$domain_choice" -ge 0 ] && [ "$domain_choice" -lt ${#domains[@]} ]; then
            domain="${domains[$domain_choice]}"
            print_info "已选择域名: $domain"
        else
            print_error "无效选择！"
            return 1
        fi
    fi

    # 确认域名目录是否存在
    domain_dir="/home/$username/domains/$domain/public_html"
    if [ ! -d "$domain_dir" ]; then
        print_error "域名目录 $domain_dir 不存在！"
        print_info "请检查您的域名是否正确，或者域名是否已经在控制面板中创建。"
        return 1
    fi

    print_info "域名目录: $domain_dir"

    # 检查Node.js应用是否已创建
    NODE_ENV_PATH="/home/$username/nodevenv/domains/$domain/public_html"
    if [ ! -d "$NODE_ENV_PATH" ]; then
        print_warning "未检测到Node.js应用环境，请先创建Node.js应用"
        guide_nodejs_creation "$domain"
        return 1
    fi

    # 询问节点名称
    read -p "请输入节点名称 (默认: hostvps): " node_name
    node_name=${node_name:-"hostvps"}

    # 询问端口号
    read -p "请输入监听端口 (默认: 3000，必须更换): " port
    port=${port:-3000}

    # UUID处理
    read -p "是否自动生成UUID? (Y/n, 默认: Y): " auto_uuid
    auto_uuid=${auto_uuid:-"Y"}

    if [[ $auto_uuid =~ ^[Yy]$ ]]; then
        # 生成UUID
        if command -v uuidgen > /dev/null; then
            uuid=$(uuidgen)
        else
            # 如果没有uuidgen，使用其他方式生成UUID
            uuid=$(cat /proc/sys/kernel/random/uuid)
        fi
        print_info "自动生成的UUID: $uuid"
    else
        read -p "请输入UUID: " uuid
        if [ -z "$uuid" ]; then
            print_error "UUID不能为空！"
            return 1
        fi
    fi

    # 询问反代域名（可选）
    read -p "请输入反代域名 (如果没有可回车默认使用www.visa.com.tw): " cf_domain
    cf_domain=${cf_domain:-"www.visa.com.tw"}

    # 使用VLESS协议
    print_info "使用VLESS协议"

    # 询问哪吒探针信息（可选）
    read -p "请输入哪吒服务器地址 (v1格式: nz.example.com:端口号；v0格式: nz.example.com，回车跳过配置哪吒探针): " nezha_server

    if [ -n "$nezha_server" ]; then
        read -p "请输入哪吒客户端密钥 (必填): " nezha_key

        # 自动检测哪吒版本（通过检查服务器地址是否包含端口号）
        if [[ "$nezha_server" == *":"* ]]; then
            # 包含冒号，使用哪吒v1
            print_info "检测到哪吒v1格式的服务器地址"
            nezha_port=""

            # 检查是否需要TLS
            NEZHA_TLS="false"
            if [[ "$nezha_server" == *":443"* ]] || [[ "$nezha_server" == *":8443"* ]] || [[ "$nezha_server" == *":2096"* ]] || [[ "$nezha_server" == *":2087"* ]] || [[ "$nezha_server" == *":2083"* ]] || [[ "$nezha_server" == *":2053"* ]]; then
                print_info "检测到TLS端口，将使用TLS连接"
                nezha_tls=true
            else
                # 询问是否使用TLS
                read -p "是否使用TLS连接哪吒服务器? (Y/n, 默认: Y): " use_tls
                use_tls=${use_tls:-"Y"}
                if [[ $use_tls =~ ^[Yy]$ ]]; then
                    nezha_tls=true
                else
                    nezha_tls=false
                fi
            fi
        else
            # 不包含冒号，使用哪吒v0
            print_info "检测到哪吒v0格式的服务器地址"
            read -p "请输入哪吒v0端口: " nezha_port

            # 检查是否需要TLS
            if [[ "$nezha_port" == "443" ]] || [[ "$nezha_port" == "8443" ]] || [[ "$nezha_port" == "2096" ]] || [[ "$nezha_port" == "2087" ]] || [[ "$nezha_port" == "2083" ]] || [[ "$nezha_port" == "2053" ]]; then
                print_info "检测到TLS端口，将使用TLS连接"
                nezha_tls="--tls"
            else
                # 询问是否使用TLS
                read -p "是否使用TLS连接哪吒服务器? (Y/n, 默认: N): " use_tls
                use_tls=${use_tls:-"N"}
                if [[ $use_tls =~ ^[Yy]$ ]]; then
                    nezha_tls="--tls"
                else
                    nezha_tls=""
                fi
            fi
        fi
    else
        nezha_key=""
        nezha_port=""
        nezha_tls=true
    fi

    # 保存配置到文件
    cat > "$CONFIG_FILE" << EOF
# WebSocket服务配置
DOMAIN="$domain"
DOMAIN_DIR="$domain_dir"
NODE_NAME="$node_name"
PORT="$port"
UUID="$uuid"
CF_DOMAIN="$cf_domain"

# 哪吒探针配置
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
NEZHA_PORT="$nezha_port"
NEZHA_TLS="$nezha_tls"
EOF
    chmod 600 "$CONFIG_FILE"
    print_success "配置文件已保存！"
    return 0
}

# 启动WebSocket代理服务
start_websocket() {
    print_info "启动WebSocket代理服务..."

    # 检查配置文件
    if ! check_config; then
        return 1
    fi

    # 加载配置
    load_config

    # 检查Node.js应用是否已创建
    NODE_ENV_PATH="/home/$username/nodevenv/domains/$DOMAIN/public_html"
    if [ ! -d "$NODE_ENV_PATH" ]; then
        print_error "未检测到Node.js应用环境，请先创建Node.js应用"
        guide_nodejs_creation "$DOMAIN"
        return 1
    fi

    # 检查端口是否被占用
    if lsof -i:$PORT -t &> /dev/null; then
        print_error "端口 $PORT 已被占用，请修改配置文件中的端口或停止占用该端口的进程"
        return 1
    fi

    # 创建index.js文件
    print_info "创建index.js文件..."
    cat > "$DOMAIN_DIR/index.js" << EOF
const http = require('http');
const fs = require('fs');
const { Buffer } = require('buffer');
const net = require('net');
const { WebSocket, createWebSocketStream } = require('ws');

// 配置参数
const UUID = process.env.UUID || '$UUID';    // UUID用于验证连接
const DOMAIN = process.env.DOMAIN || '$DOMAIN';    // 域名
const CF_DOMAIN = process.env.CF_DOMAIN || '$CF_DOMAIN';    // 反代域名
const SUB_PATH = process.env.SUB_PATH || 'sub';     // 获取节点的订阅路径
const NAME = process.env.NAME || '$NODE_NAME';  // 节点名称
const PORT = process.env.PORT || $PORT;     // http和ws服务端口

const httpServer = http.createServer((req, res) => {
    // 记录请求信息，帮助调试
    console.log(\`收到请求: \${req.method} \${req.url}\`);

    // 处理/sub路径，不区分大小写
    if (req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('It works!\\nNodeJS ' + process.versions.node + '\\n');
    } else if (req.url.toLowerCase() === \`/\${SUB_PATH.toLowerCase()}\`) {
        console.log('处理订阅请求...');
        console.log(\`UUID: \${UUID}, DOMAIN: \${DOMAIN}, NAME: \${NAME}\`);

        const nodeName = NAME || 'NodeWS';

        // 生成VLESS URL
        const vlessURL = \`vless://\${UUID}@\${CF_DOMAIN}:443?encryption=none&security=tls&sni=\${DOMAIN}&type=ws&host=\${DOMAIN}&path=%2F#\${nodeName}\`;
        console.log('生成的VLESS URL:', vlessURL);

        // 转换为Base64
        const base64Content = Buffer.from(vlessURL).toString('base64');

        console.log('Base64编码后的URL:');
        console.log(base64Content);

        res.writeHead(200, {
            'Content-Type': 'text/plain',
            'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
        });
        res.end(base64Content + '\\n');
    } else if (req.url === '/status') {
        // 添加状态检查端点
        const { exec } = require('child_process');
        exec('ps aux | grep -v grep | grep "node\\\\|nezha-agent"', (error, stdout) => {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(\`服务状态:\\n\${stdout}\\n\`);
        });
    } else if (req.url === '/debug') {
        // 添加调试端点
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(\`调试信息:
UUID: \${UUID}
DOMAIN: \${DOMAIN}
SUB_PATH: \${SUB_PATH}
NAME: \${NAME}
PORT: \${PORT}
\`);
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found\\n');
    }
});

const wss = new WebSocket.Server({ server: httpServer });
const uuid = UUID.replace(/-/g, "");
wss.on('connection', ws => {
    ws.once('message', msg => {
        const [VERSION] = msg;
        const id = msg.slice(1, 17);
        if (!id.every((v, i) => v == parseInt(uuid.substr(i * 2, 2), 16))) return;
        let i = msg.slice(17, 18).readUInt8() + 19;
        const port = msg.slice(i, i += 2).readUInt16BE(0);
        const ATYP = msg.slice(i, i += 1).readUInt8();
        const host = ATYP == 1 ? msg.slice(i, i += 4).join('.') :
            (ATYP == 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg.slice(i, i + 1).readUInt8())) :
                (ATYP == 3 ? msg.slice(i, i += 16).reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), []).map(b => b.readUInt16BE(0).toString(16)).join(':') : ''));
        ws.send(new Uint8Array([VERSION, 0]));
        const duplex = createWebSocketStream(ws);
        net.connect({ host, port }, function () {
            this.write(msg.slice(i));
            duplex.on('error', () => { }).pipe(this).on('error', () => { }).pipe(duplex);
        }).on('error', () => { });
    }).on('error', () => { });
});

httpServer.listen(PORT, () => {
    console.log(\`Server is running on port \${PORT}\`);
});
EOF

    # 创建package.json
    print_info "创建package.json文件..."
    cat > "$DOMAIN_DIR/package.json" << EOF
{
  "name": "node-ws",
  "version": "1.0.0",
  "description": "WebSocket Server",
  "main": "index.js",
  "author": "mqiancheng",
  "repository": "https://github.com/mqiancheng/host-node-ws",
  "license": "MIT",
  "private": false,
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "ws": "^8.14.2"
  },
  "engines": {
    "node": ">=14"
  }
}
EOF

    # 停止现有进程
    check_processes
    if [ "$NODE_RUNNING" = true ]; then
        print_info "停止现有WebSocket服务进程..."
        kill $NODE_PID
    fi

    # 获取Node.js虚拟环境激活脚本
    NODE_VERSIONS=( $(ls -d "$NODE_ENV_PATH"/* 2>/dev/null | grep -o '[0-9]*$' | sort -nr) )
    if [ ${#NODE_VERSIONS[@]} -gt 0 ]; then
        SELECTED_VERSION="${NODE_VERSIONS[0]}"
        NODE_ENV_ACTIVATE="$NODE_ENV_PATH/$SELECTED_VERSION/bin/activate"
        print_info "使用Node.js版本: $SELECTED_VERSION"

        # 安装依赖并启动服务
        print_info "安装依赖并启动服务..."
        cd "$DOMAIN_DIR"
        source "$NODE_ENV_ACTIVATE"
        npm install

        # 如果已有进程在运行，先停止它
        if [ -f "node.pid" ] && ps -p $(cat node.pid) > /dev/null 2>&1; then
            print_info "停止已运行的WebSocket服务 (PID: $(cat node.pid))..."
            kill -9 $(cat node.pid) > /dev/null 2>&1
            sleep 1
        fi

        # 启动Node.js应用
        nohup node index.js > node.log 2>&1 &
        echo $! > node.pid

        # 等待服务启动
        sleep 2

        # 检查服务是否成功启动
        if ps -p $(cat node.pid) > /dev/null 2>&1; then
            # 检查日志文件中是否有错误信息
            if grep -q "Error:" "$DOMAIN_DIR/node.log" || grep -q "error:" "$DOMAIN_DIR/node.log" || grep -q "EADDRINUSE" "$DOMAIN_DIR/node.log"; then
                print_error "WebSocket服务启动失败，发现错误:"
                grep -i "error" "$DOMAIN_DIR/node.log" | head -3 | while read -r line; do
                    echo -e "${RED}$line${NC}"
                done
                echo -e "${YELLOW}请查看完整日志文件: $DOMAIN_DIR/node.log${NC}"
                return 1
            fi

            # 尝试访问服务检查是否真正运行
            local check_url="http://localhost:$PORT/"
            local response=$(curl -s -m 2 "$check_url" 2>/dev/null)

            if [ "$?" -ne 0 ] || [ -z "$response" ]; then
                print_error "WebSocket服务启动失败，无法访问服务"
                echo -e "${RED}服务进程存在但无法响应请求${NC}"
                echo -e "${YELLOW}请查看日志文件: $DOMAIN_DIR/node.log${NC}"
                return 1
            fi

            print_success "WebSocket服务已启动，PID: $(cat node.pid)"
            echo -e "${GREEN}您的VLESS订阅地址是：${NC}https://${DOMAIN}/sub"
        else
            print_error "WebSocket服务启动失败，进程未运行"
            echo -e "${RED}请检查日志文件: $DOMAIN_DIR/node.log${NC}"

            # 显示日志中的错误信息
            if [ -f "$DOMAIN_DIR/node.log" ]; then
                echo -e "${RED}日志中的错误信息:${NC}"
                grep -i "error" "$DOMAIN_DIR/node.log" | head -3 | while read -r line; do
                    echo -e "${RED}$line${NC}"
                done
            fi

            return 1
        fi
    else
        print_error "未找到Node.js版本，请确保已正确创建Node.js应用"
        return 1
    fi

    return 0
}

# 启动哪吒探针
start_nezha() {
    print_info "启动哪吒探针..."

    # 检查配置文件
    if ! check_config; then
        return 1
    fi

    # 加载配置
    load_config

    # 检查哪吒探针配置
    if [ -z "$NEZHA_SERVER" ] || [ -z "$NEZHA_KEY" ]; then
        print_warning "哪吒探针配置不完整，请先修改配置文件"
        return 1
    fi

    # 停止现有哪吒探针进程
    check_processes
    if [ "$NEZHA_RUNNING" = true ]; then
        print_info "停止现有哪吒探针进程..."
        kill $NEZHA_PID
    fi

    # 下载并启动哪吒探针
    start_nezha_process

    # 等待探针启动
    sleep 2
    check_processes
    if [ "$NEZHA_RUNNING" = true ]; then
        print_success "哪吒探针已启动，PID: $NEZHA_PID"
    else
        print_warning "哪吒探针可能未正常启动，请检查日志"
    fi

    return 0
}

# 下载并启动哪吒探针进程（供多个函数调用）
start_nezha_process() {
    # 下载agent.sh（如果不存在）
    if [ ! -f "$HOME/agent.sh" ]; then
        print_info "下载哪吒探针安装脚本..."
        cd "$HOME"
        curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/refs/heads/main/agent.sh -o agent.sh && chmod +x agent.sh
    fi

    # 启动哪吒探针
    print_info "启动哪吒探针..."
    cd "$HOME"

    # 根据配置决定使用哪吒v0还是v1
    if [ -n "$NEZHA_PORT" ]; then
        # 使用哪吒v0
        print_info "使用哪吒v0..."
        env NZ_SERVER="$NEZHA_SERVER" NZ_PORT="$NEZHA_PORT" NZ_KEY="$NEZHA_KEY" NZ_TLS="$NEZHA_TLS" ./agent.sh > /dev/null 2>&1 &
    else
        # 使用哪吒v1
        print_info "使用哪吒v1..."
        env NZ_SERVER="$NEZHA_SERVER" NZ_TLS=$NEZHA_TLS NZ_UUID="$UUID" NZ_CLIENT_SECRET="$NEZHA_KEY" ./agent.sh > /dev/null 2>&1 &
    fi
}

# 强制重新安装
force_reinstall() {
    print_info "准备强制重新安装..."

    read -p "此操作将删除所有现有文件和进程，确定继续? (y/N, 默认: N): " confirm_reinstall
    confirm_reinstall=${confirm_reinstall:-"N"}

    if [[ ! $confirm_reinstall =~ ^[Yy]$ ]]; then
        print_info "已取消重新安装。"
        return 1
    fi

    # 加载配置（如果存在）
    if [ -f "$CONFIG_FILE" ]; then
        load_config
    fi

    # 停止并清理现有安装
    print_info "正在清理现有安装..."

    # 停止所有进程
    check_processes
    if [ "$NODE_RUNNING" = true ]; then
        print_info "停止WebSocket服务进程..."
        kill $NODE_PID
    fi

    if [ "$NEZHA_RUNNING" = true ]; then
        print_info "停止哪吒探针进程..."
        kill $NEZHA_PID
    fi

    # 卸载哪吒探针
    if [ -f "$HOME/agent.sh" ]; then
        cd "$HOME"
        ./agent.sh uninstall
        print_info "已卸载哪吒探针"
    fi

    # 删除文件
    print_info "删除现有文件..."

    # 删除域名目录下的文件
    if [ -n "$DOMAIN_DIR" ] && [ -d "$DOMAIN_DIR" ]; then
        rm -f "$DOMAIN_DIR/index.js" "$DOMAIN_DIR/package.json" "$DOMAIN_DIR/node.pid" "$DOMAIN_DIR/node.log"
    fi

    # 删除其他文件和目录
    rm -f "$HOME/agent.sh" "$CONFIG_FILE"
    rm -rf "$HOME/nezha"

    # 清理日志文件夹
    rm -rf "$LOG_DIR"
    mkdir -p "$LOG_DIR"

    print_success "清理完成！"
    return 0
}

# 主菜单
show_menu() {
    clear
    echo "========================================"
    echo "      基础WebSocket代理服务 v$VERSION      "
    echo "========================================"
    echo -e "${CYAN}今日运行: ${YELLOW}${TODAY}次   ${CYAN}累计运行: ${YELLOW}${TOTAL}次${NC}"
    echo -e "----------By mqiancheng----------"
    echo -e "项目地址: https://github.com/mqiancheng/host-node-ws"
    echo ""

    # 显示进程状态
    show_status

    echo ""
    echo "请选择操作："
    echo "1. 修改配置文件"
    echo "2. 启动WebSocket代理服务"
    echo "3. 启动哪吒探针"
    echo "5. 强制重新安装（清除现有安装）"
    echo "0. 退出脚本"
    echo ""

    read -p "请输入选项 [0-5]: " option
    log_debug "用户选择操作: $option"

    case $option in
        0)
            print_info "退出脚本。"
            log_debug "用户选择退出脚本"
            exit 0
            ;;
        1)
            modify_config
            ;;
        2)
            start_websocket
            ;;
        3)
            start_nezha
            ;;
        5)
            force_reinstall
            ;;
        *)
            print_error "无效选项，请重新选择。"
            log_debug "用户输入了无效选项: $option"
            ;;
    esac

    # 操作完成后暂停
    echo ""
    read -p "按Enter键继续..." dummy

    # 返回主菜单
    show_menu
}

# 主函数
main() {
    # 获取运行统计
    get_run_stats

    # 显示欢迎信息
    clear
    echo "========================================"
    echo "      WebSocket服务器部署工具 v$VERSION      "
    echo "========================================"
    echo -e "${CYAN}今日运行: ${YELLOW}${TODAY}次   ${CYAN}累计运行: ${YELLOW}${TOTAL}次${NC}"
    echo -e "----------By mqiancheng----------"
    echo -e "项目地址: https://github.com/mqiancheng/host-node-ws"
    echo ""
    print_info "欢迎使用WebSocket服务器部署工具！"
    print_info "此工具可以帮助您快速部署WebSocket服务和哪吒探针。"
    echo ""

    # 显示主菜单
    show_menu
}

# 检查并启动所有服务（用于Cron任务）
check_and_start_all() {
    # 创建日志目录（如果不存在）
    mkdir -p "$LOG_DIR"

    # 加载配置
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"

        # 检查并启动哪吒探针
        if ! pgrep -u "$USER" -f "nezha-agent" > /dev/null && [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
            # 使用通用函数启动哪吒探针
            start_nezha_process
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 哪吒探针已启动" >> "$LOG_FILE"
        fi

        # 检查并启动WebSocket服务
        if [ -n "$DOMAIN" ] && [ -n "$DOMAIN_DIR" ]; then
            # 使用check_processes函数检测进程状态
            check_processes

            # 如果WebSocket服务未运行，尝试通过curl访问订阅地址来启动它
            if [ "$NODE_RUNNING" = false ]; then
                curl -s -o /dev/null "https://$DOMAIN/sub"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试通过访问订阅地址启动WebSocket服务" >> "$LOG_FILE"
            fi
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 配置文件不存在，无法启动服务" >> "$LOG_FILE"
    fi
}

# 处理命令行参数
if [ "$1" = "check_and_start_all" ]; then
    check_and_start_all
    exit 0
fi

# 执行主函数
main