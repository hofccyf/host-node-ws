#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 创建日志目录
LOG_DIR="$HOME/tmp/ws_setup_logs"
mkdir -p "$LOG_DIR"

# 创建日志文件
LOG_FILE="$LOG_DIR/ws_setup_$(date +%Y%m%d%H%M%S).log"
touch "$LOG_FILE"
echo "=== 安装日志开始 $(date) ===" > "$LOG_FILE"

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

# 记录调试信息到日志
log_debug() {
    echo "[DEBUG] $(date +%H:%M:%S) $1" >> "$LOG_FILE"
}

# 获取用户名
username=$(whoami)
print_info "检测到用户名: $username"
log_debug "用户名: $username"

# 询问用户是否已创建Node.js应用程序
read -p "您是否已经在控制面板中创建了Node.js应用程序? (y/N, 默认: N): " created_app
created_app=${created_app:-"N"}
log_debug "用户是否已创建Node.js应用: $created_app"

if [[ ! $created_app =~ ^[Yy]$ ]]; then
    print_info "请按照以下步骤在控制面板中创建Node.js应用程序:"
    echo "1. 进入控制面板 -> Node.js APP"
    echo "2. 点击\"创建应用程序\""
    echo "3. Node.js版本: 选择最新版本"

    # 检查domains目录
    domains_dir="/home/$username/domains"
    if [ ! -d "$domains_dir" ]; then
        print_error "未找到domains目录: $domains_dir"
        log_debug "domains目录不存在: $domains_dir"
        exit 1
    fi

    # 列出所有域名目录
    print_info "正在扫描域名目录..."
    domains=()
    for dir in "$domains_dir"/*; do
        if [ -d "$dir" ]; then
            domain_name=$(basename "$dir")
            domains+=("$domain_name")
            log_debug "找到域名目录: $domain_name"
        fi
    done

    # 显示域名列表
    if [ ${#domains[@]} -eq 0 ]; then
        print_warning "未找到任何域名目录，请手动输入域名"
        log_debug "未找到任何域名目录"
        read -p "请输入您的域名 (例如: example.com): " domain
        log_debug "用户输入域名: $domain"
    else
        echo "检测到以下域名:"
        for i in "${!domains[@]}"; do
            echo "[$i] ${domains[$i]}"
        done

        echo "[m] 手动输入其他域名"
        read -p "请选择域名 [0-$((${#domains[@]}-1))/m]: " domain_choice
        log_debug "用户选择: $domain_choice"

        if [[ "$domain_choice" == "m" ]]; then
            read -p "请输入您的域名 (例如: example.com): " domain
            log_debug "用户手动输入域名: $domain"
        elif [[ "$domain_choice" =~ ^[0-9]+$ ]] && [ "$domain_choice" -ge 0 ] && [ "$domain_choice" -lt ${#domains[@]} ]; then
            domain="${domains[$domain_choice]}"
            print_info "已选择域名: $domain"
            log_debug "用户从列表选择域名: $domain"
        else
            print_error "无效选择！"
            log_debug "用户输入了无效选择: $domain_choice"
            exit 1
        fi
    fi

    # 确认域名目录是否存在
    domain_dir="/home/$username/domains/$domain/public_html"
    if [ ! -d "$domain_dir" ]; then
        print_error "域名目录 $domain_dir 不存在！"
        print_info "请检查您的域名是否正确，或者域名是否已经在控制面板中创建。"
        log_debug "域名目录不存在: $domain_dir"
        exit 1
    fi

    print_info "域名目录: $domain_dir"
    log_debug "确认域名目录: $domain_dir"

    echo "4. Application root: domains/$domain/public_html"
    echo "5. Application startup file: index.js"
    echo "6. 点击\"创建\"按钮"
    echo ""
    print_info "创建完成后，请重新运行此脚本并选择 'Y'"
    exit 0
fi

# 继续执行脚本，用户已创建Node.js应用程序
# 检查domains目录
domains_dir="/home/$username/domains"
if [ ! -d "$domains_dir" ]; then
    print_error "未找到domains目录: $domains_dir"
    log_debug "domains目录不存在: $domains_dir"
    exit 1
fi

# 列出所有域名目录
print_info "正在扫描域名目录..."
domains=()
for dir in "$domains_dir"/*; do
    if [ -d "$dir" ]; then
        domain_name=$(basename "$dir")
        domains+=("$domain_name")
        log_debug "找到域名目录: $domain_name"
    fi
done

# 显示域名列表
if [ ${#domains[@]} -eq 0 ]; then
    print_warning "未找到任何域名目录，请手动输入域名"
    log_debug "未找到任何域名目录"
    read -p "请输入您的域名 (例如: example.com): " domain
    log_debug "用户输入域名: $domain"
else
    echo "检测到以下域名:"
    for i in "${!domains[@]}"; do
        echo "[$i] ${domains[$i]}"
    done

    echo "[m] 手动输入其他域名"
    read -p "请选择域名 [0-$((${#domains[@]}-1))/m]: " domain_choice
    log_debug "用户选择: $domain_choice"

    if [[ "$domain_choice" == "m" ]]; then
        read -p "请输入您的域名 (例如: example.com): " domain
        log_debug "用户手动输入域名: $domain"
    elif [[ "$domain_choice" =~ ^[0-9]+$ ]] && [ "$domain_choice" -ge 0 ] && [ "$domain_choice" -lt ${#domains[@]} ]; then
        domain="${domains[$domain_choice]}"
        print_info "已选择域名: $domain"
        log_debug "用户从列表选择域名: $domain"
    else
        print_error "无效选择！"
        log_debug "用户输入了无效选择: $domain_choice"
        exit 1
    fi
fi

# 确认域名目录是否存在
domain_dir="/home/$username/domains/$domain/public_html"
if [ ! -d "$domain_dir" ]; then
    print_error "域名目录 $domain_dir 不存在！"
    print_info "请检查您的域名是否正确，或者域名是否已经在控制面板中创建。"
    log_debug "域名目录不存在: $domain_dir"
    exit 1
fi

print_info "域名目录: $domain_dir"
log_debug "确认域名目录: $domain_dir"

# 检查必要组件
INSTALLED=true
MISSING_COMPONENTS=()

# 检查index.js
if [ ! -f "$domain_dir/index.js" ]; then
    INSTALLED=false
    MISSING_COMPONENTS+=("index.js")
    log_debug "未检测到 index.js 文件"
fi

# 检查package.json
if [ ! -f "$domain_dir/package.json" ]; then
    INSTALLED=false
    MISSING_COMPONENTS+=("package.json")
    log_debug "未检测到 package.json 文件"
fi

# 检查哪吒探针配置
NEZHA_CONFIG_PATH="$HOME/nezha/agent/config.yml"
if [ ! -f "$NEZHA_CONFIG_PATH" ]; then
    INSTALLED=false
    MISSING_COMPONENTS+=("哪吒探针配置")
    log_debug "未检测到哪吒探针配置: $NEZHA_CONFIG_PATH"
fi

# 检查进程
NODE_RUNNING=false
NEZHA_RUNNING=false

# 检查lsnode进程
LSNODE_PATTERN="lsnode:$domain_dir"
LSNODE_PID=$(ps aux | grep "$LSNODE_PATTERN" | grep -v grep | awk '{print $2}')
if [ -n "$LSNODE_PID" ]; then
    NODE_RUNNING=true
    log_debug "检测到正在运行的lsnode进程，PID: $LSNODE_PID"
else
    # 备用检查：检查node.pid文件
    if [ -f "$domain_dir/node.pid" ]; then
        NODE_PID=$(cat "$domain_dir/node.pid")
        if ps -p $NODE_PID > /dev/null; then
            NODE_RUNNING=true
            log_debug "检测到正在运行的Node.js进程，PID: $NODE_PID"
        else
            log_debug "node.pid文件存在但进程不存在，PID: $NODE_PID"
        fi
    fi

    # 再次尝试检查node进程
    NODE_PROCESS_PID=$(ps aux | grep "node $domain_dir/index.js" | grep -v grep | awk '{print $2}')
    if [ -n "$NODE_PROCESS_PID" ]; then
        NODE_RUNNING=true
        log_debug "检测到正在运行的node进程，PID: $NODE_PROCESS_PID"
    fi
fi

# 检查哪吒探针进程
NEZHA_PID=$(pgrep -u "$USER" -f "nezha-agent")
if [ -n "$NEZHA_PID" ]; then
    NEZHA_RUNNING=true
    log_debug "检测到正在运行的哪吒探针进程，PID: $NEZHA_PID"
fi

# 显示检测结果
if [ "$INSTALLED" = false ]; then
    print_warning "缺少以下组件:"
    for component in "${MISSING_COMPONENTS[@]}"; do
        echo "- $component"
    done

    # 询问是否继续安装
    read -p "是否继续安装缺失组件? (Y/n, 默认: Y): " continue_install
    continue_install=${continue_install:-"Y"}
    log_debug "用户选择是否继续安装: $continue_install"

    if [[ ! $continue_install =~ ^[Yy]$ ]]; then
        print_info "已取消安装。"
        log_debug "用户取消安装"
        exit 0
    fi

    # 安装缺失组件
    if [[ " ${MISSING_COMPONENTS[@]} " =~ " index.js " ]] || [[ " ${MISSING_COMPONENTS[@]} " =~ " package.json " ]]; then
        print_info "正在安装Node.js应用组件..."

        # 询问UUID
        read -p "是否自动生成UUID? (Y/n, 默认: Y): " auto_uuid
        auto_uuid=${auto_uuid:-"Y"}
        log_debug "用户选择UUID生成方式: $auto_uuid"

        if [[ $auto_uuid =~ ^[Yy]$ ]]; then
            # 生成UUID
            if command -v uuidgen > /dev/null; then
                uuid=$(uuidgen)
            else
                # 如果没有uuidgen，使用其他方式生成UUID
                uuid=$(cat /proc/sys/kernel/random/uuid)
            fi
            print_info "自动生成的UUID: $uuid"
            log_debug "自动生成UUID: $uuid"
        else
            read -p "请输入UUID: " uuid
            if [ -z "$uuid" ]; then
                print_error "UUID不能为空！"
                log_debug "用户未提供UUID，退出脚本"
                exit 1
            fi
            log_debug "用户输入UUID: $uuid"
        fi

        # 下载index.js
        if [[ " ${MISSING_COMPONENTS[@]} " =~ " index.js " ]]; then
            print_info "下载index.js..."
            curl -s -o "$domain_dir/index.js" "https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/index.js"
            if [ $? -ne 0 ]; then
                print_error "下载脚本 index.js 失败！"
                log_debug "下载index.js失败"
                exit 1
            fi
            log_debug "成功下载index.js"

            # 修改index.js中的配置
            print_info "更新index.js配置..."
            sed -i "s/const UUID = process.env.UUID || '';/const UUID = process.env.UUID || '$uuid';/" "$domain_dir/index.js"
            log_debug "成功更新index.js配置"
        fi

        # 创建package.json
        if [[ " ${MISSING_COMPONENTS[@]} " =~ " package.json " ]]; then
            print_info "创建package.json..."
            cat > "$domain_dir/package.json" << EOF
{
  "name": "node-ws",
  "version": "1.0.0",
  "description": "Node.js Server",
  "main": "index.js",
  "author": "eoovve",
  "repository": "https://github.com/eoovve/node-ws",
  "license": "MIT",
  "private": false,
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "ws": "^8.14.2",
    "axios": "^1.6.2"
  },
  "engines": {
    "node": ">=14"
  }
}
EOF
            log_debug "成功创建package.json"
        fi
    fi

    # 安装哪吒探针
    if [[ " ${MISSING_COMPONENTS[@]} " =~ " 哪吒探针配置 " ]]; then
        print_info "正在安装哪吒探针..."

        # 询问哪吒探针信息
        read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
        if [ -z "$nezha_server" ]; then
            print_error "哪吒服务器地址不能为空！"
            log_debug "用户未提供哪吒服务器地址，退出脚本"
            exit 1
        fi
        log_debug "用户输入哪吒服务器地址: $nezha_server"

        read -p "请输入哪吒客户端密钥: " nezha_key
        if [ -z "$nezha_key" ]; then
            print_error "哪吒客户端密钥不能为空！"
            log_debug "用户未提供哪吒客户端密钥，退出脚本"
            exit 1
        fi
        log_debug "用户输入哪吒客户端密钥"

        # 保存配置到文件
        mkdir -p "$HOME/tmp"
        cat > "$HOME/tmp/nezha_config.conf" << EOF
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
EOF
        chmod 600 "$HOME/tmp/nezha_config.conf"
        log_debug "已保存哪吒探针配置到 $HOME/tmp/nezha_config.conf"

        # 下载并安装哪吒探针
        print_info "下载哪吒探针安装脚本..."
        cd "$HOME"
        curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/refs/heads/main/agent.sh -o agent.sh && chmod +x agent.sh
        log_debug "成功下载agent.sh并设置执行权限"

        # 启动哪吒探针
        print_info "启动哪吒探针..."
        env NZ_SERVER="$nezha_server" NZ_TLS=true NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
        log_debug "已启动哪吒探针"

        print_success "哪吒探针安装完成！"
    fi

    # 安装完成后，更新状态
    INSTALLED=true
    MISSING_COMPONENTS=()

    # 重新检查进程
    NEZHA_PID=$(pgrep -u "$USER" -f "nezha-agent")
    if [ -n "$NEZHA_PID" ]; then
        NEZHA_RUNNING=true
        log_debug "检测到正在运行的哪吒探针进程，PID: $NEZHA_PID"
    fi
fi

# 显示进程状态
print_info "进程状态："
if [ "$NODE_RUNNING" = true ]; then
    if [ -n "$LSNODE_PID" ]; then
        echo "- WebSocket服务: 运行中 (lsnode进程, PID: $LSNODE_PID)"
    elif [ -n "$NODE_PROCESS_PID" ]; then
        echo "- WebSocket服务: 运行中 (node进程, PID: $NODE_PROCESS_PID)"
    else
        echo "- WebSocket服务: 运行中 (PID: $NODE_PID)"
    fi
else
    echo "- WebSocket服务: 未运行"
fi

if [ "$NEZHA_RUNNING" = true ]; then
    echo "- 哪吒探针: 运行中 (PID: $NEZHA_PID)"
else
    echo "- 哪吒探针: 未运行"
fi

# 显示菜单
echo ""
echo "请选择操作："
echo "1. 修改配置文件"
echo "2. 重启探针"
echo "3. 退出脚本"
echo "4. 强制重新安装（清除现有安装）"

read -p "请输入选项 [1-4]: " option
log_debug "用户选择操作: $option"

case $option in
    1)
        # 修改配置文件
        print_info "修改配置文件..."
        log_debug "用户选择: 修改配置文件"

        # 检查index.js是否存在
        if [ -f "$domain_dir/index.js" ]; then
            # 询问UUID
            read -p "是否自动生成UUID? (Y/n, 默认: Y): " auto_uuid
            auto_uuid=${auto_uuid:-"Y"}
            log_debug "用户选择UUID生成方式: $auto_uuid"

            if [[ $auto_uuid =~ ^[Yy]$ ]]; then
                # 生成UUID
                if command -v uuidgen > /dev/null; then
                    uuid=$(uuidgen)
                else
                    # 如果没有uuidgen，使用其他方式生成UUID
                    uuid=$(cat /proc/sys/kernel/random/uuid)
                fi
                print_info "自动生成的UUID: $uuid"
                log_debug "自动生成UUID: $uuid"
            else
                read -p "请输入UUID: " uuid
                if [ -z "$uuid" ]; then
                    print_error "UUID不能为空！"
                    log_debug "用户未提供UUID，退出脚本"
                    exit 1
                fi
                log_debug "用户输入UUID: $uuid"
            fi

            # 修改index.js中的配置
            print_info "更新index.js配置..."
            sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$uuid';/" "$domain_dir/index.js"
            log_debug "成功更新index.js配置"

            print_success "配置文件已更新！"
        else
            print_error "未找到index.js文件！"
            log_debug "未找到index.js文件，无法修改配置"
        fi
        ;;
    2)
        # 重启探针
        print_info "正在重启哪吒探针..."
        log_debug "用户选择: 重启探针"

        # 停止现有哪吒探针进程
        pids=$(pgrep -u "$USER" -f "nezha-agent")
        if [ -n "$pids" ]; then
            kill $pids
            print_info "已停止哪吒探针进程"
            log_debug "已停止哪吒探针进程，PID: $pids"
        else
            log_debug "未检测到运行中的哪吒探针进程"
        fi

        # 检查配置文件
        if [ -f "$HOME/tmp/nezha_config.conf" ]; then
            print_info "检测到已保存的哪吒探针配置，正在读取..."
            source "$HOME/tmp/nezha_config.conf"
            print_info "已读取配置: 服务器=$NEZHA_SERVER"
            log_debug "从配置文件读取: 服务器=$NEZHA_SERVER, 密钥=$NEZHA_KEY"
            nezha_server=$NEZHA_SERVER
            nezha_key=$NEZHA_KEY
        else
            # 询问哪吒探针信息
            read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
            if [ -z "$nezha_server" ]; then
                print_error "哪吒服务器地址不能为空！"
                log_debug "用户未提供哪吒服务器地址，退出脚本"
                exit 1
            fi
            log_debug "用户输入哪吒服务器地址: $nezha_server"

            read -p "请输入哪吒客户端密钥: " nezha_key
            if [ -z "$nezha_key" ]; then
                print_error "哪吒客户端密钥不能为空！"
                log_debug "用户未提供哪吒客户端密钥，退出脚本"
                exit 1
            fi
            log_debug "用户输入哪吒客户端密钥"

            # 保存配置到文件
            mkdir -p "$HOME/tmp"
            cat > "$HOME/tmp/nezha_config.conf" << EOF
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
EOF
            chmod 600 "$HOME/tmp/nezha_config.conf"
            log_debug "已保存哪吒探针配置到 $HOME/tmp/nezha_config.conf"
        fi

        # 下载agent.sh（如果不存在）
        if [ ! -f "$HOME/agent.sh" ]; then
            print_info "下载哪吒探针安装脚本..."
            cd "$HOME"
            curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/refs/heads/main/agent.sh -o agent.sh && chmod +x agent.sh
            log_debug "成功下载agent.sh并设置执行权限"
        fi

        # 启动哪吒探针
        print_info "启动哪吒探针..."
        cd "$HOME"
        env NZ_SERVER="$nezha_server" NZ_TLS=true NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
        log_debug "已启动哪吒探针"

        print_success "哪吒探针已重启！"
        ;;
    3)
        # 退出脚本
        print_info "已取消操作，退出脚本。"
        log_debug "用户选择退出脚本"
        exit 0
        ;;
    4)
        # 强制重新安装
        print_info "准备强制重新安装..."
        log_debug "用户选择强制重新安装"

        read -p "此操作将删除所有现有文件和进程，确定继续? (y/N, 默认: N): " confirm_reinstall
        confirm_reinstall=${confirm_reinstall:-"N"}
        log_debug "用户确认重新安装: $confirm_reinstall"

        if [[ ! $confirm_reinstall =~ ^[Yy]$ ]]; then
            print_info "已取消重新安装。"
            log_debug "用户取消重新安装"
            exit 0
        fi

        # 停止并清理现有安装
        print_info "正在清理现有安装..."

        # 停止WebSocket服务进程
        # 首先检查lsnode进程
        LSNODE_PATTERN="lsnode:$domain_dir"
        LSNODE_PID=$(ps aux | grep "$LSNODE_PATTERN" | grep -v grep | awk '{print $2}')
        if [ -n "$LSNODE_PID" ]; then
            kill $LSNODE_PID
            print_info "已停止lsnode进程 (PID: $LSNODE_PID)"
            log_debug "已停止lsnode进程 PID: $LSNODE_PID"
        fi

        # 然后检查node.pid文件
        if [ -f "$domain_dir/node.pid" ]; then
            NODE_PID=$(cat "$domain_dir/node.pid")
            if ps -p $NODE_PID > /dev/null; then
                kill $NODE_PID
                print_info "已停止Node.js进程 (PID: $NODE_PID)"
                log_debug "已停止Node.js进程 PID: $NODE_PID"
            fi
        fi

        # 最后尝试使用pkill停止所有相关进程
        pkill -f "node $domain_dir/index.js" 2>/dev/null
        log_debug "尝试使用pkill停止Node.js进程"

        # 停止哪吒探针
        pids=$(pgrep -u "$USER" -f "nezha-agent")
        if [ -n "$pids" ]; then
            kill $pids
            print_info "已停止哪吒探针进程"
            log_debug "已停止哪吒探针进程，PID: $pids"
        fi

        # 卸载哪吒探针
        if [ -f "$HOME/agent.sh" ]; then
            cd "$HOME"
            ./agent.sh uninstall
            print_info "已卸载哪吒探针"
            log_debug "执行agent.sh uninstall卸载哪吒探针"
        fi

        # 删除文件
        print_info "删除现有文件..."
        log_debug "开始删除文件"

        if [ -f "$domain_dir/index.js" ]; then
            rm "$domain_dir/index.js"
            log_debug "已删除 index.js"
        fi

        if [ -f "$domain_dir/package.json" ]; then
            rm "$domain_dir/package.json"
            log_debug "已删除 package.json"
        fi

        if [ -f "$HOME/agent.sh" ]; then
            rm "$HOME/agent.sh"
            log_debug "已删除 agent.sh"
        fi

        if [ -f "$domain_dir/node.pid" ]; then
            rm "$domain_dir/node.pid"
            log_debug "已删除 node.pid"
        fi

        if [ -f "$HOME/tmp/nezha_config.conf" ]; then
            rm "$HOME/tmp/nezha_config.conf"
            log_debug "已删除 nezha_config.conf"
        fi

        if [ -d "$HOME/nezha" ]; then
            rm -rf "$HOME/nezha"
            log_debug "已删除 nezha 目录"
        fi

        # 清理日志文件
        rm -f "$HOME/tmp/ws_setup_logs/*"
        log_debug "已清理日志文件"

        print_success "清理完成！请重新运行脚本进行安装。"
        exit 0
        ;;
    *)
        print_error "无效选项，退出脚本。"
        log_debug "用户输入了无效选项: $option"
        exit 1
        ;;
esac

print_info "操作完成！"
echo "日志文件保存在: $LOG_FILE"
log_debug "脚本执行完成"
