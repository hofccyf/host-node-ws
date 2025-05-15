#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本版本
VERSION="1.0.0"

# 获取运行统计
get_run_stats() {
    # 使用curl获取统计数据，超时设置为3秒
    local stats_data=$(curl -s -m 3 "https://visit.okyes.filegear-sg.me/?url=https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup-argo.sh" 2>/dev/null)

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
LOG_DIR="$HOME/tmp/argo_setup_logs"
mkdir -p "$LOG_DIR"

# 清理旧日志文件（超过7天的）
find "$LOG_DIR" -type f -name "argo_setup_*.log" -mtime +7 -delete 2>/dev/null

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
    LOG_FILE="$LOG_DIR/argo_setup_$(date +%Y%m%d%H%M%S).log"
    touch "$LOG_FILE"
    echo "=== 安装日志开始 $(date) ===" > "$LOG_FILE"
fi

# 创建配置目录和文件
CONFIG_DIR="$HOME/tmp/argo_config"
mkdir -p "$CONFIG_DIR"
CONFIG_FILE="$CONFIG_DIR/argo_config.conf"

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
        echo "===== 调试: 加载配置文件 $CONFIG_FILE =====" >> debug.log
        echo "配置文件内容:" >> debug.log
        cat "$CONFIG_FILE" >> debug.log
        echo "===== 配置文件内容结束 =====" >> debug.log

        # 加载配置
        source "$CONFIG_FILE"

        # 验证配置是否正确加载
        echo "===== 调试: 配置加载后的变量值 =====" >> debug.log
        echo "UUID=$UUID" >> debug.log
        echo "DOMAIN=$DOMAIN" >> debug.log
        echo "CF_DOMAIN=$CF_DOMAIN" >> debug.log
        echo "NODE_NAME=$NODE_NAME" >> debug.log
        echo "PORT=$PORT" >> debug.log
        echo "NEZHA_SERVER=$NEZHA_SERVER" >> debug.log
        echo "NEZHA_PORT=$NEZHA_PORT" >> debug.log
        echo "NEZHA_KEY=$NEZHA_KEY" >> debug.log
        echo "ARGO_DOMAIN=$ARGO_DOMAIN" >> debug.log
        echo "ARGO_AUTH=$ARGO_AUTH" >> debug.log
        echo "ARGO_PORT=$ARGO_PORT" >> debug.log
        echo "AUTO_ACCESS=$AUTO_ACCESS" >> debug.log
        echo "PROJECT_URL=$PROJECT_URL" >> debug.log
        echo "===== 配置加载验证结束 =====" >> debug.log

        return 0
    else
        echo "===== 调试: 配置文件 $CONFIG_FILE 不存在 =====" >> debug.log
        return 1
    fi
}

# 检查进程状态
check_processes() {
    ARGO_RUNNING=false
    NEZHA_RUNNING=false
    XRAY_RUNNING=false

    # 检查Argo隧道进程
    if pgrep -u "$USER" -f "cloudflared.*tunnel" > /dev/null; then
        ARGO_RUNNING=true
        ARGO_PID=$(pgrep -u "$USER" -f "cloudflared.*tunnel")
    fi

    # 检查哪吒探针进程
    if pgrep -u "$USER" -f "nezha-agent" > /dev/null; then
        NEZHA_RUNNING=true
        NEZHA_PID=$(pgrep -u "$USER" -f "nezha-agent")
    fi

    # 检查Xray进程
    if pgrep -u "$USER" -f "xray" > /dev/null; then
        XRAY_RUNNING=true
        XRAY_PID=$(pgrep -u "$USER" -f "xray")
    fi
}

# 显示进程状态
show_status() {
    check_processes

    print_info "进程状态："
    if [ "$XRAY_RUNNING" = true ]; then
        echo "- Xray代理服务: 运行中 (PID: $XRAY_PID)"
    else
        echo "- Xray代理服务: 未运行"
    fi

    if [ "$ARGO_RUNNING" = true ]; then
        echo "- Cloudflare Argo隧道: 运行中 (PID: $ARGO_PID)"
    else
        echo "- Cloudflare Argo隧道: 未运行"
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
    echo "3. Node.js版本: 选择最新版本"
    echo "4. Application root: domains/$1/public_html"
    echo "5. Application startup file: argows.js"
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
    read -p "请输入节点名称 (默认: argo-ws): " node_name
    node_name=${node_name:-"argo-ws"}

    # 询问端口号
    read -p "请输入HTTP服务端口 (默认: 3000): " port
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

    # 询问Argo隧道配置
    read -p "是否使用固定隧道? (Y/n, 默认: n): " use_fixed_tunnel
    use_fixed_tunnel=${use_fixed_tunnel:-"n"}

    if [[ $use_fixed_tunnel =~ ^[Yy]$ ]]; then
        read -p "请输入Argo隧道域名: " argo_domain
        if [ -z "$argo_domain" ]; then
            print_error "Argo隧道域名不能为空！"
            return 1
        fi

        read -p "请输入Argo隧道Token或JSON密钥: " argo_auth
        if [ -z "$argo_auth" ]; then
            print_error "Argo隧道Token或JSON密钥不能为空！"
            return 1
        fi
    else
        argo_domain=""
        argo_auth=""
    fi

    # 询问哪吒探针信息（可选）
    read -p "请输入哪吒服务器地址 (v1格式: nz.example.com:端口号；v0格式: nz.example.com，回车跳过配置哪吒探针): " nezha_server

    if [ -n "$nezha_server" ]; then
        read -p "请输入哪吒客户端密钥 (必填): " nezha_key

        # 自动检测哪吒版本（通过检查服务器地址是否包含端口号）
        if [[ "$nezha_server" == *":"* ]]; then
            # 包含冒号，使用哪吒v1
            print_info "检测到哪吒v1格式的服务器地址"
            nezha_port=""
        else
            # 不包含冒号，使用哪吒v0
            print_info "检测到哪吒v0格式的服务器地址"
            read -p "请输入哪吒v0端口: " nezha_port
        fi
    else
        nezha_key=""
        nezha_port=""
    fi

    # 询问是否启用自动保活
    read -p "是否启用自动保活? (Y/n, 默认: Y): " auto_access
    auto_access=${auto_access:-"Y"}
    if [[ $auto_access =~ ^[Yy]$ ]]; then
        auto_access="true"
    else
        auto_access="false"
    fi

    # 保存配置到文件
    cat > "$CONFIG_FILE" << EOF
# 基本配置
DOMAIN="$domain"
DOMAIN_DIR="$domain_dir"
NODE_NAME="$node_name"
PORT="$port"
UUID="$uuid"
CF_DOMAIN="$cf_domain"

# Argo隧道配置
ARGO_DOMAIN="$argo_domain"
ARGO_AUTH="$argo_auth"
ARGO_PORT="8001"

# 哪吒探针配置
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
NEZHA_PORT="$nezha_port"

# 其他配置
AUTO_ACCESS="$auto_access"
PROJECT_URL="https://$domain"
EOF
    chmod 600 "$CONFIG_FILE"
    print_success "配置文件已保存！"
    return 0
}

# 部署Argo代理服务
deploy_argo_service() {
    print_info "部署Argo代理服务..."

    # 检查配置文件
    if ! check_config; then
        return 1
    fi

    # 加载配置
    load_config

    # 检查Node.js应用是否已创建
    NODE_ENV_PATH="/home/$username/nodevenv/domains/$DOMAIN/public_html"
    if [ ! -d "$NODE_ENV_PATH" ]; then
        print_warning "未检测到Node.js应用环境，请先创建Node.js应用"
        guide_nodejs_creation "$DOMAIN"
        return 1
    fi

    # 下载argows.js文件
    print_info "下载argows.js文件..."
    curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/refs/heads/main/argows.js -o "$DOMAIN_DIR/argows.js"
    if [ $? -ne 0 ]; then
        print_error "下载argows.js文件失败！"
        return 1
    fi

    # 直接修改argows.js中的配置值
    print_info "修改argows.js配置值..."

    # 转义特殊字符，避免sed命令出错
    ARGO_AUTH_ESCAPED=$(echo "$ARGO_AUTH" | sed 's/[\/&]/\\&/g')

    # 修改配置值 - 直接替换变量值，不再依赖环境变量
    sed -i "s/const UUID = '';/const UUID = '$UUID';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const DOMAIN = '';/const DOMAIN = '$DOMAIN';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const CF_DOMAIN = 'www.visa.com.tw';/const CF_DOMAIN = '$CF_DOMAIN';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const NAME = 'argo-ws';/const NAME = '$NODE_NAME';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const PORT = 3001;/const PORT = $PORT;/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const NEZHA_SERVER = '';/const NEZHA_SERVER = '$NEZHA_SERVER';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const NEZHA_PORT = '';/const NEZHA_PORT = '$NEZHA_PORT';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const NEZHA_KEY = '';/const NEZHA_KEY = '$NEZHA_KEY';/g" "$DOMAIN_DIR/argows.js"
    sed -i "s/const ARGO_DOMAIN = '';/const ARGO_DOMAIN = '$ARGO_DOMAIN';/g" "$DOMAIN_DIR/argows.js"

    # 转义ARGO_AUTH中的特殊字符
    ARGO_AUTH_ESCAPED=$(echo "$ARGO_AUTH" | sed 's/[\/&]/\\&/g')
    sed -i "s/const ARGO_AUTH = '';/const ARGO_AUTH = '$ARGO_AUTH_ESCAPED';/g" "$DOMAIN_DIR/argows.js"

    sed -i "s/const ARGO_PORT = 8001;/const ARGO_PORT = $ARGO_PORT;/g" "$DOMAIN_DIR/argows.js"

    # 修改AUTO_ACCESS变量
    if [[ "$AUTO_ACCESS" == "true" ]]; then
        sed -i "s/const AUTO_ACCESS = true;/const AUTO_ACCESS = true;/g" "$DOMAIN_DIR/argows.js"
    else
        sed -i "s/const AUTO_ACCESS = true;/const AUTO_ACCESS = false;/g" "$DOMAIN_DIR/argows.js"
    fi

    # 修改PROJECT_URL变量
    PROJECT_URL_ESCAPED=$(echo "$PROJECT_URL" | sed 's/[\/&]/\\&/g')
    sed -i "s|const PROJECT_URL = '';|const PROJECT_URL = '$PROJECT_URL_ESCAPED';|g" "$DOMAIN_DIR/argows.js"

    print_success "argows.js配置值已修改！"

    # 创建package.json
    print_info "创建package.json文件..."
    cat > "$DOMAIN_DIR/package.json" << EOF
{
  "name": "argo-ws",
  "version": "1.0.0",
  "description": "Argo Tunnel WebSocket Server",
  "main": "argows.js",
  "author": "mqiancheng",
  "repository": "https://github.com/mqiancheng/host-node-ws",
  "license": "MIT",
  "private": false,
  "scripts": {
    "start": "node argows.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.2"
  },
  "engines": {
    "node": ">=14"
  }
}
EOF

    # 停止现有进程
    check_processes
    if [ "$XRAY_RUNNING" = true ]; then
        print_info "停止现有Xray代理服务进程..."
        kill $XRAY_PID
    fi
    if [ "$ARGO_RUNNING" = true ]; then
        print_info "停止现有Argo隧道进程..."
        kill $ARGO_PID
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

        # 启动服务
        print_info "启动Argo代理服务..."

        # 记录配置信息到日志
        echo "===== 配置信息 =====" > debug.log
        echo "UUID=$UUID" >> debug.log
        echo "DOMAIN=$DOMAIN" >> debug.log
        echo "CF_DOMAIN=$CF_DOMAIN" >> debug.log
        echo "NODE_NAME=$NODE_NAME" >> debug.log
        echo "PORT=$PORT" >> debug.log
        echo "NEZHA_SERVER=$NEZHA_SERVER" >> debug.log
        echo "NEZHA_PORT=$NEZHA_PORT" >> debug.log
        echo "NEZHA_KEY=$NEZHA_KEY" >> debug.log
        echo "ARGO_DOMAIN=$ARGO_DOMAIN" >> debug.log
        echo "ARGO_AUTH=$ARGO_AUTH" >> debug.log
        echo "ARGO_PORT=$ARGO_PORT" >> debug.log
        echo "AUTO_ACCESS=$AUTO_ACCESS" >> debug.log
        echo "PROJECT_URL=$PROJECT_URL" >> debug.log
        echo "===== 配置信息结束 =====" >> debug.log

        # 启动Node.js应用（不依赖环境变量，因为配置已经写入文件）
        print_info "启动Node.js应用..."
        nohup node argows.js > argo.log 2>&1 &
        echo $! > argo.pid
        print_success "Argo代理服务已启动，PID: $(cat argo.pid)"

        # 等待服务启动
        print_info "等待服务启动..."
        sleep 5

        # 检查进程状态
        check_processes
        if [ "$XRAY_RUNNING" = true ] && [ "$ARGO_RUNNING" = true ]; then
            print_success "Argo代理服务和隧道已成功启动！"

            # 显示订阅地址
            if [ -n "$ARGO_DOMAIN" ]; then
                echo -e "${GREEN}您的订阅地址是：${NC}https://${ARGO_DOMAIN}/sub"
            else
                print_info "临时隧道启动中，请稍后查看argo.log获取隧道域名"
                print_info "或者使用命令: curl -s http://localhost:$PORT/sub 获取订阅链接"
            fi
        else
            print_warning "服务可能未正常启动，请检查argo.log日志文件"
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

        # 检查是否需要TLS
        NEZHA_TLS_PARAM=""
        if [[ "$NEZHA_SERVER" == *":443"* ]] || [[ "$NEZHA_SERVER" == *":8443"* ]] || [[ "$NEZHA_SERVER" == *":2096"* ]] || [[ "$NEZHA_SERVER" == *":2087"* ]] || [[ "$NEZHA_SERVER" == *":2083"* ]] || [[ "$NEZHA_SERVER" == *":2053"* ]]; then
            NEZHA_TLS_PARAM="--tls"
        fi

        env NZ_SERVER="$NEZHA_SERVER" NZ_PORT="$NEZHA_PORT" NZ_KEY="$NEZHA_KEY" NZ_TLS="$NEZHA_TLS_PARAM" ./agent.sh > /dev/null 2>&1 &
    else
        # 使用哪吒v1
        print_info "使用哪吒v1..."

        # 检查是否需要TLS
        NEZHA_TLS="false"
        if [[ "$NEZHA_SERVER" == *":443"* ]] || [[ "$NEZHA_SERVER" == *":8443"* ]] || [[ "$NEZHA_SERVER" == *":2096"* ]] || [[ "$NEZHA_SERVER" == *":2087"* ]] || [[ "$NEZHA_SERVER" == *":2083"* ]] || [[ "$NEZHA_SERVER" == *":2053"* ]]; then
            NEZHA_TLS="true"
        fi

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
    if [ "$XRAY_RUNNING" = true ]; then
        print_info "停止Xray代理服务进程..."
        kill $XRAY_PID
    fi

    if [ "$ARGO_RUNNING" = true ]; then
        print_info "停止Argo隧道进程..."
        kill $ARGO_PID
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
        rm -f "$DOMAIN_DIR/argows.js" "$DOMAIN_DIR/package.json" "$DOMAIN_DIR/argo.pid" "$DOMAIN_DIR/argo.log"
        rm -rf "$DOMAIN_DIR/node_modules" "$DOMAIN_DIR/tmp"
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

        # 检查并启动Argo代理服务
        if [ -n "$DOMAIN" ] && [ -n "$DOMAIN_DIR" ]; then
            # 检查Xray和Argo进程
            check_processes

            # 如果Xray或Argo未运行，尝试启动Node.js应用
            if [ "$XRAY_RUNNING" = false ] || [ "$ARGO_RUNNING" = false ]; then
                # 检查Node.js环境
                NODE_ENV_PATH="/home/$username/nodevenv/domains/$DOMAIN/public_html"
                if [ -d "$NODE_ENV_PATH" ]; then
                    NODE_VERSIONS=( $(ls -d "$NODE_ENV_PATH"/* 2>/dev/null | grep -o '[0-9]*$' | sort -nr) )
                    if [ ${#NODE_VERSIONS[@]} -gt 0 ]; then
                        SELECTED_VERSION="${NODE_VERSIONS[0]}"
                        NODE_ENV_ACTIVATE="$NODE_ENV_PATH/$SELECTED_VERSION/bin/activate"

                        # 激活Node.js环境并启动服务
                        cd "$DOMAIN_DIR"
                        source "$NODE_ENV_ACTIVATE"

                        # 直接启动Node.js应用（不依赖环境变量，因为配置已经写入文件）
                        nohup node argows.js > argo.log 2>&1 &
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试直接启动Node.js应用" >> "$LOG_FILE"
                    fi
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 未找到Node.js环境，无法启动服务" >> "$LOG_FILE"
                fi

                # 尝试通过访问订阅地址来启动服务（作为备用方法）
                if [ -n "$ARGO_DOMAIN" ]; then
                    curl -s -o /dev/null "https://$ARGO_DOMAIN/sub"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试通过访问固定隧道订阅地址启动服务" >> "$LOG_FILE"
                else
                    # 否则尝试访问本地端口
                    curl -s -o /dev/null "http://localhost:$PORT/sub"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试通过访问本地端口启动服务" >> "$LOG_FILE"
                fi
            fi
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 配置文件不存在，无法启动服务" >> "$LOG_FILE"
    fi
}

# 主菜单
show_menu() {
    clear
    echo "========================================"
    echo "    WebSocket服务器部署工具-Argo版 v$VERSION    "
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
    echo "2. 部署Argo代理服务"
    echo "3. 启动哪吒探针"
    echo "4. 退出脚本"
    echo "5. 强制重新安装（清除现有安装）"
    echo ""

    read -p "请输入选项 [1-5]: " option

    case $option in
        1)
            modify_config
            ;;
        2)
            deploy_argo_service
            ;;
        3)
            start_nezha
            ;;
        4)
            print_info "退出脚本。"
            exit 0
            ;;
        5)
            force_reinstall
            ;;
        *)
            print_error "无效选项，请重新选择。"
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
    echo "    WebSocket服务器部署工具-Argo版 v$VERSION    "
    echo "========================================"
    echo -e "${CYAN}今日运行: ${YELLOW}${TODAY}次   ${CYAN}累计运行: ${YELLOW}${TOTAL}次${NC}"
    echo -e "----------By mqiancheng----------"
    echo -e "项目地址: https://github.com/mqiancheng/host-node-ws"
    echo ""
    print_info "欢迎使用WebSocket服务器部署工具-Argo版！"
    print_info "此工具可以帮助您快速部署Argo隧道代理服务和哪吒探针。"
    echo ""

    # 显示主菜单
    show_menu
}

# 处理命令行参数
if [ "$1" = "check_and_start_all" ]; then
    check_and_start_all
    exit 0
fi

# 执行主函数
main