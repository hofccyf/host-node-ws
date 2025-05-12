#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取用户名和域名路径
username=$(whoami)
print_info "检测到用户名: $username"

# 询问域名
read -p "请输入您的域名 (例如: example.com): " domain
if [ -z "$domain" ]; then
    print_error "域名不能为空！"
    exit 1
fi

# 确认域名目录是否存在
domain_dir="/home/$username/domains/$domain/public_html"
if [ ! -d "$domain_dir" ]; then
    print_error "域名目录 $domain_dir 不存在！"
    print_info "请检查您的域名是否正确，或者域名是否已经在控制面板中创建。"
    exit 1
fi

print_info "域名目录: $domain_dir"

# 检查是否已安装
INSTALLED=false
# 检查文件是否存在
if [ -f "$domain_dir/index.js" ]; then
    INSTALLED=true
fi
if [ -f "$domain_dir/package.json" ]; then
    INSTALLED=true
fi
if [ -d "$domain_dir/node_modules" ]; then
    INSTALLED=true
fi
# 检查哪吒探针
NEZHA_PATH="$HOME/nezha"
if [ -d "$NEZHA_PATH" ]; then
    INSTALLED=true
fi
if [ -f "$domain_dir/agent.sh" ]; then
    INSTALLED=true
fi

# 如果检测到任何安装痕迹
if [ "$INSTALLED" = true ]; then
    print_warning "检测到系统中存在WebSocket服务或哪吒探针的安装痕迹！"
    echo ""
    echo "请选择操作："
    echo "1. 修改配置文件"
    echo "2. 重启服务和探针"
    echo "3. 退出脚本"
    echo ""
    read -p "请输入选项 [1-3]: " reinstall_option

    case $reinstall_option in
        1)
            print_info "继续修改配置文件..."
            ;;
        2)
            # 重启服务
            print_info "正在重启服务..."

            # 停止现有Node.js进程
            if [ -f "$domain_dir/node.pid" ]; then
                NODE_PID=$(cat "$domain_dir/node.pid")
                if ps -p $NODE_PID > /dev/null; then
                    kill $NODE_PID
                    print_info "已停止Node.js进程 (PID: $NODE_PID)"
                fi
            else
                pkill -f "node $domain_dir/index.js" 2>/dev/null
                print_info "已尝试停止所有相关Node.js进程"
            fi

            # 重启哪吒探针
            print_info "正在重启哪吒探针..."
            if [ -f "$domain_dir/agent.sh" ]; then
                cd "$domain_dir"
                pids=$(pgrep -u "$USER" -f "nezha-agent")
                if [ -n "$pids" ]; then
                    kill $pids
                    print_info "已停止哪吒探针进程"
                fi

                # 询问哪吒探针信息
                read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
                if [ -z "$nezha_server" ]; then
                    print_error "哪吒服务器地址不能为空！"
                    exit 1
                fi

                read -p "请输入哪吒客户端密钥: " nezha_key
                if [ -z "$nezha_key" ]; then
                    print_error "哪吒客户端密钥不能为空！"
                    exit 1
                fi

                # 创建一个后台运行哪吒探针的脚本
                cat > "$domain_dir/run_agent.sh" << EOF
#!/bin/bash
cd "$domain_dir"
env NZ_SERVER="$nezha_server" NZ_TLS=false NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
EOF
                chmod +x "$domain_dir/run_agent.sh"

                # 启动探针
                if [ -f "$domain_dir/run_agent.sh" ]; then
                    ./run_agent.sh
                    print_info "已重启哪吒探针"
                else
                    print_warning "未找到run_agent.sh，无法自动重启探针"
                fi
            else
                print_warning "未找到agent.sh，无法重启哪吒探针"
                # 下载agent.sh
                print_info "下载哪吒探针安装脚本..."
                curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/agent.sh -o "$domain_dir/agent.sh"
                chmod +x "$domain_dir/agent.sh"

                # 询问哪吒探针信息
                read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
                if [ -z "$nezha_server" ]; then
                    print_error "哪吒服务器地址不能为空！"
                    exit 1
                fi

                read -p "请输入哪吒客户端密钥: " nezha_key
                if [ -z "$nezha_key" ]; then
                    print_error "哪吒客户端密钥不能为空！"
                    exit 1
                fi

                # 创建一个后台运行哪吒探针的脚本
                cat > "$domain_dir/run_agent.sh" << EOF
#!/bin/bash
cd "$domain_dir"
env NZ_SERVER="$nezha_server" NZ_TLS=false NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
EOF
                chmod +x "$domain_dir/run_agent.sh"

                # 启动探针
                cd "$domain_dir"
                ./run_agent.sh
                print_info "已启动哪吒探针"
            fi

            # 重启Node.js应用
            print_info "正在重启Node.js应用..."
            NODE_ENV_PATH="/home/$username/nodevenv/domains/$domain/public_html"
            if [ -d "$NODE_ENV_PATH" ]; then
                # 查找激活脚本
                ACTIVATE_SCRIPT=$(find "$NODE_ENV_PATH" -name "activate" | head -n 1)
                if [ -n "$ACTIVATE_SCRIPT" ]; then
                    cd "$domain_dir"
                    source "$ACTIVATE_SCRIPT"
                    nohup node index.js > node.log 2>&1 &
                    echo $! > node.pid
                    print_success "Node.js应用已重启，PID: $(cat node.pid)"
                else
                    cd "$domain_dir"
                    nohup node index.js > node.log 2>&1 &
                    echo $! > node.pid
                    print_success "Node.js应用已重启，PID: $(cat node.pid)"
                fi
            else
                cd "$domain_dir"
                nohup node index.js > node.log 2>&1 &
                echo $! > node.pid
                print_success "Node.js应用已重启，PID: $(cat node.pid)"
            fi

            print_success "服务和探针已重启完成！"
            exit 0
            ;;
        3)
            print_info "已取消操作，退出脚本。"
            exit 0
            ;;
        *)
            print_error "无效选项，继续执行安装流程..."
            ;;
    esac
fi

# 询问端口号
read -p "请输入监听端口 (默认: 3000): " port
port=${port:-3000}

# 询问节点名称
read -p "请输入节点名称 (默认: NodeWS): " node_name
node_name=${node_name:-"NodeWS"}

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
        exit 1
    fi
fi

# 询问哪吒探针信息
read -p "请输入哪吒服务器地址 (例如: nz.example.com:5555): " nezha_server
if [ -z "$nezha_server" ]; then
    print_error "哪吒服务器地址不能为空！"
    exit 1
fi

read -p "请输入哪吒客户端密钥: " nezha_key
if [ -z "$nezha_key" ]; then
    print_error "哪吒客户端密钥不能为空！"
    exit 1
fi

# 确认信息
echo ""
print_info "=== 配置信息确认 ==="
echo "域名: $domain"
echo "端口: $port"
echo "节点名称: $node_name"
echo "UUID: $uuid"
echo "哪吒服务器: $nezha_server"
echo "哪吒密钥: $nezha_key"
echo "========================="

read -p "确认以上信息正确? (Y/n, 默认: Y): " confirm
confirm=${confirm:-"Y"}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_info "已取消安装。"
    exit 0
fi

# 开始安装
print_info "开始安装..."

# 下载index.js
print_info "下载index.js..."
curl -s -o "$domain_dir/index.js" "https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/index.js"
if [ $? -ne 0 ]; then
    print_error "下载脚本 index.js 失败！"
    exit 1
fi

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

# 修改index.js中的配置
print_info "更新index.js配置..."
sed -i "s/const UUID = process.env.UUID || '';/const UUID = process.env.UUID || '$uuid';/" "$domain_dir/index.js"
sed -i "s/const NEZHA_SERVER = process.env.NEZHA_SERVER || '';/const NEZHA_SERVER = process.env.NEZHA_SERVER || '$nezha_server';/" "$domain_dir/index.js"
sed -i "s/const NEZHA_KEY = process.env.NEZHA_KEY || '';/const NEZHA_KEY = process.env.NEZHA_KEY || '$nezha_key';/" "$domain_dir/index.js"
sed -i "s/const DOMAIN = process.env.DOMAIN || '';/const DOMAIN = process.env.DOMAIN || '$domain';/" "$domain_dir/index.js"
sed -i "s/const NAME = process.env.NAME || '';/const NAME = process.env.NAME || '$node_name';/" "$domain_dir/index.js"
sed -i "s/const PORT = process.env.PORT || 3000;/const PORT = process.env.PORT || $port;/" "$domain_dir/index.js"

# 下载修改版的agent.sh（解决卡死问题）
print_info "下载哪吒探针安装脚本..."
curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/agent.sh -o "$domain_dir/agent.sh"
chmod +x "$domain_dir/agent.sh"

# 创建一个后台运行哪吒探针的脚本
cat > "$domain_dir/run_agent.sh" << EOF
#!/bin/bash
cd "$domain_dir"
env NZ_SERVER="$nezha_server" NZ_TLS=false NZ_UUID="$uuid" NZ_CLIENT_SECRET="$nezha_key" ./agent.sh > /dev/null 2>&1 &
EOF
chmod +x "$domain_dir/run_agent.sh"

# 运行哪吒探针
print_info "启动哪吒探针..."
cd "$domain_dir"
./run_agent.sh

# 检测Node.js环境
print_info "检测Node.js环境..."
NODE_ENV_PATH="/home/$username/nodevenv/domains/$domain/public_html"

# 检查是否存在Node.js虚拟环境
if [ -d "$NODE_ENV_PATH" ]; then
    # 列出可用的Node.js版本
    NODE_VERSIONS=( $(ls -d "$NODE_ENV_PATH"/* 2>/dev/null | grep -o '[0-9]*$' | sort -nr) )

    if [ ${#NODE_VERSIONS[@]} -gt 0 ]; then
        print_info "检测到以下Node.js版本:"
        for i in "${!NODE_VERSIONS[@]}"; do
            echo "[$i] ${NODE_VERSIONS[$i]}"
        done

        read -p "请选择Node.js版本 [0-$((${#NODE_VERSIONS[@]}-1))], 默认为0: " node_version_index
        node_version_index=${node_version_index:-0}

        if [ $node_version_index -ge 0 ] && [ $node_version_index -lt ${#NODE_VERSIONS[@]} ]; then
            SELECTED_VERSION="${NODE_VERSIONS[$node_version_index]}"
            NODE_ENV_ACTIVATE="$NODE_ENV_PATH/$SELECTED_VERSION/bin/activate"

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

            # 创建后台运行脚本
            cat > "$domain_dir/run_node.sh" << EOF
#!/bin/bash
cd "$domain_dir"
nohup ./start_node.sh > /dev/null 2>&1 &
echo \$! > node.pid
EOF
            chmod +x "$domain_dir/run_node.sh"

            # 启动Node.js应用
            print_info "启动Node.js应用..."
            cd "$domain_dir"
            ./run_node.sh

            # 等待PID文件生成
            sleep 3
            if [ -f "$domain_dir/node.pid" ]; then
                NODE_PID=$(cat "$domain_dir/node.pid")
                print_success "Node.js应用已启动，PID: $NODE_PID"
            else
                print_warning "无法获取Node.js应用PID，但应用可能已在后台运行"
            fi
        else
            print_error "无效的选择！"
            exit 1
        fi
    else
        print_warning "未找到Node.js虚拟环境版本"
        USE_SYSTEM_NODE=true
    fi
else
    print_warning "未找到Node.js虚拟环境，将尝试使用系统Node.js"
    USE_SYSTEM_NODE=true
fi

# 如果没有找到虚拟环境或用户选择使用系统Node.js
if [ "$USE_SYSTEM_NODE" = true ]; then
    # 检查系统Node.js
    if command -v node > /dev/null; then
        NODE_VERSION=$(node -v)
        print_info "使用系统Node.js版本: $NODE_VERSION"

        # 安装依赖
        print_info "安装Node.js依赖..."
        cd "$domain_dir"
        npm install

        # 启动Node.js应用
        print_info "启动Node.js应用..."
        cd "$domain_dir"
        nohup node index.js > node.log 2>&1 &
        NODE_PID=$!
        echo $NODE_PID > node.pid

        # 检查Node.js应用是否成功启动
        sleep 3
        if ps -p $NODE_PID > /dev/null; then
            print_success "Node.js应用已成功启动，PID: $NODE_PID"
        else
            print_error "Node.js应用启动失败，请检查日志: $domain_dir/node.log"
            print_warning "您可能需要通过控制面板的Node.js APP功能来启动应用"
        fi
    else
        print_error "未找到可用的Node.js！"
        print_info "请通过控制面板的Node.js APP功能来启动应用"

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
