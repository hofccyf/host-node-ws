#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取用户名
username=$(whoami)

# 创建日志文件
LOG_FILE="$HOME/ws_setup_$(date +%Y%m%d%H%M%S).log"
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

print_info "检测到用户名: $username"

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

# 检查是否已安装
INSTALLED=false
INSTALLED_COMPONENTS=()

log_debug "开始检测安装状态..."

# 检查文件是否存在
if [ -f "$domain_dir/index.js" ]; then
    INSTALLED=true
    INSTALLED_COMPONENTS+=("index.js")
    log_debug "检测到 index.js 文件"
fi

if [ -f "$domain_dir/package.json" ]; then
    INSTALLED=true
    INSTALLED_COMPONENTS+=("package.json")
    log_debug "检测到 package.json 文件"
fi

if [ -d "$domain_dir/node_modules" ]; then
    INSTALLED=true
    INSTALLED_COMPONENTS+=("node_modules目录")
    log_debug "检测到 node_modules 目录"
fi

# 检查哪吒探针
NEZHA_PATH="$HOME/nezha"
if [ -d "$NEZHA_PATH" ]; then
    INSTALLED=true
    INSTALLED_COMPONENTS+=("哪吒探针目录")
    log_debug "检测到哪吒探针目录: $NEZHA_PATH"
fi

if [ -f "$domain_dir/agent.sh" ]; then
    INSTALLED=true
    INSTALLED_COMPONENTS+=("agent.sh")
    log_debug "检测到 agent.sh 文件"
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

# 记录检测结果
if [ "$INSTALLED" = true ]; then
    log_debug "检测到已安装组件: ${INSTALLED_COMPONENTS[*]}"
    if [ "$NODE_RUNNING" = true ]; then
        log_debug "Node.js进程正在运行"
    fi
    if [ "$NEZHA_RUNNING" = true ]; then
        log_debug "哪吒探针进程正在运行"
    fi
else
    log_debug "未检测到任何已安装组件"
fi

# 如果检测到任何安装痕迹
if [ "$INSTALLED" = true ]; then
    print_warning "检测到系统中存在WebSocket服务或哪吒探针的安装痕迹！"
    echo ""
    echo "检测到以下组件："
    for component in "${INSTALLED_COMPONENTS[@]}"; do
        echo "- $component"
    done
    echo ""

    # 显示进程状态
    echo "进程状态："
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
    echo ""

    echo "请选择操作："
    echo "1. 修改配置文件"
    echo "2. 重启服务和探针"
    echo "3. 退出脚本"
    echo "4. 强制重新安装（清除现有安装）"
    echo ""
    read -p "请输入选项 [1-4]: " reinstall_option
    log_debug "用户选择操作: $reinstall_option"

    case $reinstall_option in
        1)
            print_info "继续修改配置文件..."
            log_debug "用户选择: 修改配置文件"
            ;;
        2)
            # 重启服务
            print_info "正在重启服务..."
            log_debug "用户选择: 重启服务和探针"

            # 停止现有WebSocket服务进程
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
                else
                    log_debug "node.pid文件存在但进程不存在，PID: $NODE_PID"
                fi
            fi

            # 最后尝试使用pkill停止所有相关进程
            pkill -f "node $domain_dir/index.js" 2>/dev/null
            print_info "已尝试停止所有相关Node.js进程"
            log_debug "尝试使用pkill停止Node.js进程"

            # 重启哪吒探针
            print_info "正在重启哪吒探针..."
            if [ -f "$domain_dir/agent.sh" ]; then
                cd "$domain_dir"
                pids=$(pgrep -u "$USER" -f "nezha-agent")
                if [ -n "$pids" ]; then
                    kill $pids
                    print_info "已停止哪吒探针进程"
                    log_debug "已停止哪吒探针进程，PID: $pids"
                else
                    log_debug "未检测到运行中的哪吒探针进程"
                fi

                # 检查是否有保存的配置文件
                if [ -f "$domain_dir/nezha_config.conf" ]; then
                    print_info "检测到已保存的哪吒探针配置，正在读取..."
                    source "$domain_dir/nezha_config.conf"
                    print_info "已读取配置: 服务器=$NEZHA_SERVER, TLS=$NEZHA_TLS"
                    log_debug "从配置文件读取: 服务器=$NEZHA_SERVER, 密钥=$NEZHA_KEY, TLS=$NEZHA_TLS"
                    nezha_server=$NEZHA_SERVER
                    nezha_key=$NEZHA_KEY
                    nezha_tls=$NEZHA_TLS
                else
                    # 询问哪吒探针信息
                    read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
                    if [ -z "$nezha_server" ]; then
                        print_error "哪吒服务器地址不能为空！"
                        log_debug "用户未提供哪吒服务器地址，退出脚本"
                        exit 1
                    fi
                    log_debug "用户输入的哪吒服务器地址: $nezha_server"

                    read -p "请输入哪吒客户端密钥: " nezha_key
                    if [ -z "$nezha_key" ]; then
                        print_error "哪吒客户端密钥不能为空！"
                        log_debug "用户未提供哪吒客户端密钥，退出脚本"
                        exit 1
                    fi
                    log_debug "用户已输入哪吒客户端密钥"

                    # 询问是否使用TLS
                    read -p "是否使用TLS连接哪吒服务器? (Y/n, 默认: Y): " use_tls
                    use_tls=${use_tls:-"Y"}
                    if [[ $use_tls =~ ^[Yy]$ ]]; then
                        nezha_tls=true
                        log_debug "用户选择使用TLS连接"
                    else
                        nezha_tls=false
                        log_debug "用户选择不使用TLS连接"
                    fi

                    # 保存配置到文件，方便下次使用
                    cat > "$domain_dir/nezha_config.conf" << EOF
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
NEZHA_TLS="$nezha_tls"
EOF
                    chmod 600 "$domain_dir/nezha_config.conf"
                    log_debug "已保存哪吒探针配置到 $domain_dir/nezha_config.conf"
                fi

                # 创建一个后台运行哪吒探针的脚本
                cat > "$domain_dir/run_agent.sh" << EOF
#!/bin/bash
cd "$domain_dir"
env NZ_SERVER="$nezha_server" NZ_TLS=$nezha_tls NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
EOF
                chmod +x "$domain_dir/run_agent.sh"
                log_debug "已创建run_agent.sh脚本"

                # 启动探针
                if [ -f "$domain_dir/run_agent.sh" ]; then
                    ./run_agent.sh
                    print_info "已重启哪吒探针"
                    log_debug "已执行run_agent.sh启动哪吒探针"
                else
                    print_warning "未找到run_agent.sh，无法自动重启探针"
                    log_debug "run_agent.sh文件不存在，无法启动探针"
                fi
            else
                print_warning "未找到agent.sh，无法重启哪吒探针"
                log_debug "agent.sh文件不存在，尝试下载"

                # 下载agent.sh
                print_info "下载哪吒探针安装脚本..."
                curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/agent.sh -o "$domain_dir/agent.sh"
                chmod +x "$domain_dir/agent.sh"
                log_debug "已下载agent.sh并设置执行权限"

                # 检查是否有保存的配置文件
                if [ -f "$domain_dir/nezha_config.conf" ]; then
                    print_info "检测到已保存的哪吒探针配置，正在读取..."
                    source "$domain_dir/nezha_config.conf"
                    print_info "已读取配置: 服务器=$NEZHA_SERVER, TLS=$NEZHA_TLS"
                    log_debug "从配置文件读取: 服务器=$NEZHA_SERVER, 密钥=$NEZHA_KEY, TLS=$NEZHA_TLS"
                    nezha_server=$NEZHA_SERVER
                    nezha_key=$NEZHA_KEY
                    nezha_tls=$NEZHA_TLS
                else
                    # 询问哪吒探针信息
                    read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
                    if [ -z "$nezha_server" ]; then
                        print_error "哪吒服务器地址不能为空！"
                        log_debug "用户未提供哪吒服务器地址，退出脚本"
                        exit 1
                    fi
                    log_debug "用户输入的哪吒服务器地址: $nezha_server"

                    read -p "请输入哪吒客户端密钥: " nezha_key
                    if [ -z "$nezha_key" ]; then
                        print_error "哪吒客户端密钥不能为空！"
                        log_debug "用户未提供哪吒客户端密钥，退出脚本"
                        exit 1
                    fi
                    log_debug "用户已输入哪吒客户端密钥"

                    # 询问是否使用TLS
                    read -p "是否使用TLS连接哪吒服务器? (Y/n, 默认: Y): " use_tls
                    use_tls=${use_tls:-"Y"}
                    if [[ $use_tls =~ ^[Yy]$ ]]; then
                        nezha_tls=true
                        log_debug "用户选择使用TLS连接"
                    else
                        nezha_tls=false
                        log_debug "用户选择不使用TLS连接"
                    fi

                    # 保存配置到文件，方便下次使用
                    cat > "$domain_dir/nezha_config.conf" << EOF
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
NEZHA_TLS="$nezha_tls"
EOF
                    chmod 600 "$domain_dir/nezha_config.conf"
                    log_debug "已保存哪吒探针配置到 $domain_dir/nezha_config.conf"
                fi

                # 创建一个后台运行哪吒探针的脚本
                cat > "$domain_dir/run_agent.sh" << EOF
#!/bin/bash
cd "$domain_dir"
env NZ_SERVER="$nezha_server" NZ_TLS=$nezha_tls NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
EOF
                chmod +x "$domain_dir/run_agent.sh"
                log_debug "已创建run_agent.sh脚本"

                # 启动探针
                cd "$domain_dir"
                ./run_agent.sh
                print_info "已启动哪吒探针"
                log_debug "已执行run_agent.sh启动哪吒探针"
            fi

            # 重启Node.js应用
            print_info "正在重启Node.js应用..."
            NODE_ENV_PATH="/home/$username/nodevenv/domains/$domain/public_html"
            if [ -d "$NODE_ENV_PATH" ]; then
                log_debug "检测到Node.js虚拟环境: $NODE_ENV_PATH"
                # 查找激活脚本
                ACTIVATE_SCRIPT=$(find "$NODE_ENV_PATH" -name "activate" | head -n 1)
                if [ -n "$ACTIVATE_SCRIPT" ]; then
                    log_debug "找到激活脚本: $ACTIVATE_SCRIPT"
                    cd "$domain_dir"
                    source "$ACTIVATE_SCRIPT"
                    nohup node index.js > node.log 2>&1 &
                    echo $! > node.pid
                    print_success "Node.js应用已重启，PID: $(cat node.pid)"
                    log_debug "已使用虚拟环境启动Node.js应用，PID: $(cat node.pid)"
                else
                    log_debug "未找到激活脚本，使用普通方式启动"
                    cd "$domain_dir"
                    nohup node index.js > node.log 2>&1 &
                    echo $! > node.pid
                    print_success "Node.js应用已重启，PID: $(cat node.pid)"
                    log_debug "已启动Node.js应用，PID: $(cat node.pid)"
                fi
            else
                log_debug "未检测到Node.js虚拟环境，使用系统Node.js"
                cd "$domain_dir"
                nohup node index.js > node.log 2>&1 &
                echo $! > node.pid
                print_success "Node.js应用已重启，PID: $(cat node.pid)"
                log_debug "已使用系统Node.js启动应用，PID: $(cat node.pid)"
            fi

            print_success "服务和探针已重启完成！"
            log_debug "重启服务和探针完成"
            exit 0
            ;;
        3)
            print_info "已取消操作，退出脚本。"
            log_debug "用户选择退出脚本"
            exit 0
            ;;
        4)
            print_info "准备强制重新安装..."
            log_debug "用户选择强制重新安装"

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

            if [ -f "$domain_dir/agent.sh" ]; then
                rm "$domain_dir/agent.sh"
                log_debug "已删除 agent.sh"
            fi

            if [ -f "$domain_dir/run_agent.sh" ]; then
                rm "$domain_dir/run_agent.sh"
                log_debug "已删除 run_agent.sh"
            fi

            if [ -f "$domain_dir/node.pid" ]; then
                rm "$domain_dir/node.pid"
                log_debug "已删除 node.pid"
            fi

            if [ -f "$domain_dir/start_node.sh" ]; then
                rm "$domain_dir/start_node.sh"
                log_debug "已删除 start_node.sh"
            fi

            if [ -f "$domain_dir/run_node.sh" ]; then
                rm "$domain_dir/run_node.sh"
                log_debug "已删除 run_node.sh"
            fi

            if [ -f "$domain_dir/nezha_config.conf" ]; then
                rm "$domain_dir/nezha_config.conf"
                log_debug "已删除 nezha_config.conf"
            fi

            print_success "清理完成，继续执行安装流程..."
            log_debug "清理完成，设置INSTALLED=false继续安装"
            INSTALLED=false
            ;;
        *)
            print_error "无效选项，继续执行安装流程..."
            log_debug "用户输入了无效选项: $reinstall_option"
            ;;
    esac
fi

# 询问端口号
read -p "请输入监听端口 (默认: 3000): " port
port=${port:-3000}
log_debug "用户设置端口: $port"

# 询问节点名称
read -p "请输入节点名称 (默认: NodeWS): " node_name
node_name=${node_name:-"NodeWS"}
log_debug "用户设置节点名称: $node_name"

# UUID处理
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

# 询问是否使用TLS
read -p "是否使用TLS连接哪吒服务器? (Y/n, 默认: Y): " use_tls
use_tls=${use_tls:-"Y"}
if [[ $use_tls =~ ^[Yy]$ ]]; then
    nezha_tls=true
    log_debug "用户选择使用TLS连接"
else
    nezha_tls=false
    log_debug "用户选择不使用TLS连接"
fi

# 保存配置到文件，方便重启时使用
cat > "$domain_dir/nezha_config.conf" << EOF
NEZHA_SERVER="$nezha_server"
NEZHA_KEY="$nezha_key"
NEZHA_TLS="$nezha_tls"
EOF
chmod 600 "$domain_dir/nezha_config.conf"
log_debug "已保存哪吒探针配置到 $domain_dir/nezha_config.conf"

# 确认信息
echo ""
print_info "=== 配置信息确认 ==="
echo "域名: $domain"
echo "端口: $port"
echo "节点名称: $node_name"
echo "UUID: $uuid"
echo "哪吒服务器: $nezha_server"
echo "哪吒密钥: $nezha_key"
echo "使用TLS连接: $nezha_tls"
echo "========================="

read -p "确认以上信息正确? (Y/n, 默认: Y): " confirm
confirm=${confirm:-"Y"}
log_debug "用户确认信息: $confirm"

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_info "已取消安装。"
    log_debug "用户取消安装"
    exit 0
fi

# 开始安装
print_info "开始安装..."
log_debug "开始安装过程"

# 下载index.js
print_info "下载index.js..."
curl -s -o "$domain_dir/index.js" "https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/index.js"
if [ $? -ne 0 ]; then
    print_error "下载脚本 index.js 失败！"
    log_debug "下载index.js失败"
    exit 1
fi
log_debug "成功下载index.js"

# 创建package.json
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

# 修改index.js中的配置
print_info "更新index.js配置..."
sed -i "s/const UUID = process.env.UUID || '';/const UUID = process.env.UUID || '$uuid';/" "$domain_dir/index.js"
sed -i "s/const NEZHA_SERVER = process.env.NEZHA_SERVER || '';/const NEZHA_SERVER = process.env.NEZHA_SERVER || '$nezha_server';/" "$domain_dir/index.js"
sed -i "s/const NEZHA_KEY = process.env.NEZHA_KEY || '';/const NEZHA_KEY = process.env.NEZHA_KEY || '$nezha_key';/" "$domain_dir/index.js"
sed -i "s/const DOMAIN = process.env.DOMAIN || '';/const DOMAIN = process.env.DOMAIN || '$domain';/" "$domain_dir/index.js"
sed -i "s/const NAME = process.env.NAME || '';/const NAME = process.env.NAME || '$node_name';/" "$domain_dir/index.js"
sed -i "s/const PORT = process.env.PORT || 3000;/const PORT = process.env.PORT || $port;/" "$domain_dir/index.js"
log_debug "成功更新index.js配置"

# 下载修改版的agent.sh（解决卡死问题）
print_info "下载哪吒探针安装脚本..."
curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/agent.sh -o "$domain_dir/agent.sh"
chmod +x "$domain_dir/agent.sh"
log_debug "成功下载agent.sh并设置执行权限"

# 创建一个后台运行哪吒探针的脚本
cat > "$domain_dir/run_agent.sh" << EOF
#!/bin/bash
cd "$domain_dir"
env NZ_SERVER="$nezha_server" NZ_TLS=$nezha_tls NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
EOF
chmod +x "$domain_dir/run_agent.sh"
log_debug "成功创建run_agent.sh脚本，TLS设置为: $nezha_tls"

# 运行哪吒探针
print_info "启动哪吒探针..."
cd "$domain_dir"
./run_agent.sh
log_debug "已启动哪吒探针"

# 检测Node.js环境
print_info "检测Node.js环境..."
NODE_ENV_PATH="/home/$username/nodevenv/domains/$domain/public_html"
log_debug "检查Node.js虚拟环境路径: $NODE_ENV_PATH"

# 检查是否存在Node.js虚拟环境
if [ -d "$NODE_ENV_PATH" ]; then
    log_debug "找到Node.js虚拟环境目录"
    # 列出可用的Node.js版本
    NODE_VERSIONS=( $(ls -d "$NODE_ENV_PATH"/* 2>/dev/null | grep -o '[0-9]*$' | sort -nr) )
    log_debug "检测到Node.js版本: ${NODE_VERSIONS[*]}"

    if [ ${#NODE_VERSIONS[@]} -gt 0 ]; then
        print_info "检测到以下Node.js版本:"
        for i in "${!NODE_VERSIONS[@]}"; do
            echo "[$i] ${NODE_VERSIONS[$i]}"
        done

        read -p "请选择Node.js版本 [0-$((${#NODE_VERSIONS[@]}-1))], 默认为0: " node_version_index
        node_version_index=${node_version_index:-0}
        log_debug "用户选择Node.js版本索引: $node_version_index"

        if [ $node_version_index -ge 0 ] && [ $node_version_index -lt ${#NODE_VERSIONS[@]} ]; then
            SELECTED_VERSION="${NODE_VERSIONS[$node_version_index]}"
            NODE_ENV_ACTIVATE="$NODE_ENV_PATH/$SELECTED_VERSION/bin/activate"
            log_debug "选择的Node.js版本: $SELECTED_VERSION, 激活脚本: $NODE_ENV_ACTIVATE"

            print_info "使用Node.js版本: $SELECTED_VERSION"

            # 创建启动脚本
            cat > "$domain_dir/start_node.sh" << EOF
#!/bin/bash
cd "$domain_dir"
source "$NODE_ENV_ACTIVATE"
npm install
node index.js > node.log 2>&1
EOF
            chmod +x "$domain_dir/start_node.sh"
            log_debug "创建start_node.sh脚本"

            # 创建后台运行脚本
            cat > "$domain_dir/run_node.sh" << EOF
#!/bin/bash
cd "$domain_dir"
nohup ./start_node.sh > /dev/null 2>&1 &
echo \$! > node.pid
EOF
            chmod +x "$domain_dir/run_node.sh"
            log_debug "创建run_node.sh脚本"

            # 启动Node.js应用
            print_info "启动Node.js应用..."
            cd "$domain_dir"
            ./run_node.sh
            log_debug "执行run_node.sh启动Node.js应用"

            # 等待PID文件生成
            sleep 3
            if [ -f "$domain_dir/node.pid" ]; then
                NODE_PID=$(cat "$domain_dir/node.pid")
                print_success "Node.js应用已启动，PID: $NODE_PID"
                log_debug "Node.js应用已启动，PID: $NODE_PID"
            else
                print_warning "无法获取Node.js应用PID，但应用可能已在后台运行"
                log_debug "无法获取Node.js应用PID"
            fi
        else
            print_error "无效的选择！"
            log_debug "用户选择了无效的Node.js版本索引: $node_version_index"
            exit 1
        fi
    else
        print_warning "未找到Node.js虚拟环境版本"
        log_debug "Node.js虚拟环境目录存在但未找到版本"
        USE_SYSTEM_NODE=true
    fi
else
    print_warning "未找到Node.js虚拟环境，将尝试使用系统Node.js"
    log_debug "未找到Node.js虚拟环境目录"
    USE_SYSTEM_NODE=true
fi

# 如果没有找到虚拟环境或用户选择使用系统Node.js
if [ "$USE_SYSTEM_NODE" = true ]; then
    log_debug "尝试使用系统Node.js"
    # 检查系统Node.js
    if command -v node > /dev/null; then
        NODE_VERSION=$(node -v)
        print_info "使用系统Node.js版本: $NODE_VERSION"
        log_debug "检测到系统Node.js版本: $NODE_VERSION"

        # 安装依赖
        print_info "安装Node.js依赖..."
        cd "$domain_dir"
        npm install
        log_debug "执行npm install安装依赖"

        # 启动Node.js应用
        print_info "启动Node.js应用..."
        cd "$domain_dir"
        nohup node index.js > node.log 2>&1 &
        NODE_PID=$!
        echo $NODE_PID > node.pid
        log_debug "启动Node.js应用，PID: $NODE_PID"

        # 检查Node.js应用是否成功启动
        sleep 3
        if ps -p $NODE_PID > /dev/null; then
            print_success "Node.js应用已成功启动，PID: $NODE_PID"
            log_debug "确认Node.js应用正在运行，PID: $NODE_PID"
        else
            print_error "Node.js应用启动失败，请检查日志: $domain_dir/node.log"
            print_warning "您可能需要通过控制面板的Node.js APP功能来启动应用"
            log_debug "Node.js应用启动失败，进程不存在"
        fi
    else
        print_error "未找到可用的Node.js！"
        print_info "请通过控制面板的Node.js APP功能来启动应用"
        log_debug "系统中未找到Node.js命令"

        # 创建说明文件
        cat > "$domain_dir/README.txt" << EOF
您的Node.js应用已配置完成，但未能自动启动。

请按照以下步骤在控制面板中启动应用：
1. 进入控制面板 -> Node.js APP
2. 点击"创建应用程序"
3. 选择Node.js版本（推荐20.x或更高版本）
4. 应用程序根目录设置为: $domain_dir
5. 应用程序URL设置为您的域名
6. 应用程序启动文件设置为: index.js
7. 点击"创建"按钮

所有配置已经完成，您只需通过控制面板启动应用即可。
EOF
        log_debug "创建README.txt说明文件"
        print_info "已创建说明文件: $domain_dir/README.txt"
    fi
fi

# 显示访问信息
print_success "配置完成！您可以通过以下地址访问您的服务："
print_success "http://$domain:$port"
print_success "订阅地址: http://$domain:$port/sub"

print_info "安装完成！"
print_info "如需停止服务，请使用: kill $NODE_PID"
print_info "如需卸载哪吒探针，请执行: cd $domain_dir && ./agent.sh uninstall"

# 记录安装完成信息
log_debug "安装过程完成"
log_debug "Node.js PID: $NODE_PID"
log_debug "域名目录: $domain_dir"
log_debug "端口: $port"
log_debug "UUID: $uuid"
log_debug "节点名称: $node_name"
log_debug "哪吒服务器: $nezha_server"

# 显示日志文件位置
echo ""
print_info "安装日志已保存到: $LOG_FILE"
echo "如果遇到问题，请查看日志文件以获取详细信息。"
