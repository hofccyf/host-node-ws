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

# 检查脚本是否存在
check_scripts() {
    local missing_scripts=()

    if [ ! -f "setup-ws.sh" ]; then
        missing_scripts+=("setup-ws.sh")
    fi

    if [ ! -f "setup-argo.sh" ]; then
        missing_scripts+=("setup-argo.sh")
    fi

    if [ ${#missing_scripts[@]} -gt 0 ]; then
        print_error "缺少以下脚本文件:"
        for script in "${missing_scripts[@]}"; do
            echo "- $script"
        done

        print_info "正在尝试下载缺失的脚本..."

        for script in "${missing_scripts[@]}"; do
            if [ "$script" = "setup-ws.sh" ]; then
                curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup-ws.sh -o setup-ws.sh
                if [ $? -eq 0 ]; then
                    chmod +x setup-ws.sh
                    print_success "成功下载 setup-ws.sh"
                else
                    print_error "下载 setup-ws.sh 失败"
                    return 1
                fi
            elif [ "$script" = "setup-argo.sh" ]; then
                curl -L https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup-argo.sh -o setup-argo.sh
                if [ $? -eq 0 ]; then
                    chmod +x setup-argo.sh
                    print_success "成功下载 setup-argo.sh"
                else
                    print_error "下载 setup-argo.sh 失败"
                    return 1
                fi
            fi
        done
    fi

    # 确保脚本有执行权限
    chmod +x setup-ws.sh setup-argo.sh

    return 0
}

# 统计用户选择
record_choice() {
    local choice=$1
    curl -s -m 3 "https://visit.okyes.filegear-sg.me/?url=https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup.sh&choice=$choice" 2>/dev/null &
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

    # 检查脚本文件
    if ! check_scripts; then
        print_error "无法继续，请手动下载所需脚本文件"
        exit 1
    fi

    # 显示选择菜单
    echo "请选择要部署的服务类型："
    echo "1. 基础WebSocket代理服务"
    echo "   - 简单易用，适合基本代理需求"
    echo "   - 直接使用域名提供WebSocket服务"
    echo ""
    echo "2. Argo隧道WebSocket代理服务"
    echo "   - 提供Cloudflare Argo隧道功能"
    echo "   - 支持临时隧道和固定隧道"
    echo "   - 提供多协议支持(VLESS/VMess/Trojan)"
    echo ""

    read -p "请输入选项 [1-2]: " choice

    case $choice in
        1)
            # 统计用户选择了WebSocket版本
            record_choice "ws"
            print_info "正在启动WebSocket部署工具..."
            sleep 1
            exec ./setup-ws.sh
            ;;
        2)
            # 统计用户选择了Argo版本
            record_choice "argo"
            print_info "正在启动Argo隧道部署工具..."
            sleep 1
            exec ./setup-argo.sh
            ;;
        *)
            print_error "无效选项，请重新运行脚本并选择1或2"
            exit 1
            ;;
    esac
}

# 执行主函数
main