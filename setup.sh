#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本版本
VERSION="1.1.0"

# 全局变量
HAS_UPDATES=false
UPDATE_LIST=""
WS_UPDATE_INFO=""
ARGO_UPDATE_INFO=""

# 获取运行统计
get_run_stats() {
    # 使用curl获取统计数据，超时设置为3秒，但不显示输出
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

# 获取脚本的版本号
get_script_version() {
    local script_file=$1
    if [ -f "$script_file" ]; then
        local version=$(grep -o 'VERSION="[0-9.]*"' "$script_file" | grep -o '[0-9.]*')
        echo "$version"
    else
        echo "0.0.0"
    fi
}

# 获取GitHub上脚本的最新版本号
get_github_version() {
    local script_file=$1
    # 使用-s参数静默下载，不显示进度条或错误信息
    local github_content=$(curl -s "https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/$script_file" 2>/dev/null)
    if [ -n "$github_content" ]; then
        local version=$(echo "$github_content" | grep -o 'VERSION="[0-9.]*"' | grep -o '[0-9.]*')
        echo "$version"
    else
        echo "0.0.0"
    fi
}

# 比较版本号，如果版本2大于版本1，返回1，否则返回0
compare_versions() {
    local version1=$1
    local version2=$2

    if [ "$version1" = "$version2" ]; then
        return 0
    fi

    local IFS=.
    local i ver1=($version1) ver2=($version2)

    # 填充短版本号
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done

    # 比较版本号
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            # 如果ver2短，则ver1大
            return 0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done

    return 0
}

# 下载脚本
download_script() {
    local script_file=$1
    print_info "下载 $script_file..."
    # 使用-s参数静默下载，不显示进度条
    curl -s -L "https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/$script_file" -o "$script_file"
    if [ $? -eq 0 ]; then
        chmod +x "$script_file"
        print_success "成功下载 $script_file"
        return 0
    else
        print_error "下载 $script_file 失败"
        return 1
    fi
}

# 下载指定的脚本
download_specific_script() {
    local script_name=$1

    if [ ! -f "$script_name" ]; then
        print_info "正在下载 $script_name..."
        download_script "$script_name" || return 1
    fi

    # 确保脚本有执行权限
    chmod +x "$script_name"

    return 0
}

# 检查脚本更新
check_script_updates() {
    # 使用已经检测到的更新信息
    if [ "$HAS_UPDATES" = true ]; then
        print_info "发现以下脚本有更新:"
        echo -e "$UPDATE_LIST"

        read -p "是否更新这些脚本? (Y/n): " update_choice
        update_choice=${update_choice:-Y}

        if [[ $update_choice =~ ^[Yy]$ ]]; then
            # 更新脚本
            if [ -f "setup-ws.sh" ] && [ -n "$WS_UPDATE_INFO" ]; then
                download_script "setup-ws.sh"
            fi

            if [ -f "setup-argo.sh" ] && [ -n "$ARGO_UPDATE_INFO" ]; then
                download_script "setup-argo.sh"
            fi

            print_success "脚本更新完成"
        else
            print_info "跳过脚本更新"
        fi
    else
        print_success "所有脚本已是最新版本"
    fi
}

# 统计用户选择
record_choice() {
    local choice=$1
    # 使用>/dev/null屏蔽所有输出
    curl -s -m 3 "https://visit.okyes.filegear-sg.me/?url=https://raw.githubusercontent.com/mqiancheng/host-node-ws/main/setup.sh&choice=$choice" >/dev/null 2>&1 &
}

# 检查脚本更新状态
check_update_status() {
    local has_updates=false
    local update_list=""

    # 检查setup-ws.sh
    if [ -f "setup-ws.sh" ]; then
        local local_version=$(get_script_version "setup-ws.sh")
        local github_version=$(get_github_version "setup-ws.sh")

        compare_versions "$local_version" "$github_version"
        if [ $? -eq 1 ]; then
            has_updates=true
            WS_UPDATE_INFO="setup-ws.sh: $local_version -> $github_version"
            update_list="$update_list\n- $WS_UPDATE_INFO"
        fi
    fi

    # 检查setup-argo.sh
    if [ -f "setup-argo.sh" ]; then
        local local_version=$(get_script_version "setup-argo.sh")
        local github_version=$(get_github_version "setup-argo.sh")

        compare_versions "$local_version" "$github_version"
        if [ $? -eq 1 ]; then
            has_updates=true
            ARGO_UPDATE_INFO="setup-argo.sh: $local_version -> $github_version"
            update_list="$update_list\n- $ARGO_UPDATE_INFO"
        fi
    fi

    # 设置全局更新状态
    if [ "$has_updates" = true ]; then
        HAS_UPDATES=true
        UPDATE_LIST="$update_list"
    else
        HAS_UPDATES=false
        UPDATE_LIST=""
    fi
}

# 主函数
main() {
    # 获取运行统计
    get_run_stats

    # 检查脚本更新状态
    HAS_UPDATES=false
    UPDATE_LIST=""
    check_update_status

    # 显示欢迎信息
    clear
    echo "========================================"
    echo "      WebSocket服务器部署工具 v$VERSION      "
    echo "========================================"
    echo -e "${CYAN}今日运行: ${YELLOW}${TODAY}次   ${CYAN}累计运行: ${YELLOW}${TOTAL}次${NC}"
    echo -e "----------By mqiancheng----------"
    echo -e "项目地址: https://github.com/mqiancheng/host-node-ws"
    echo ""

    # 显示选择菜单
    echo "请选择要部署的服务类型："
    echo "1. 基础WebSocket代理服务"
    echo "   - 简单易用，适合基本代理需求"
    echo "   - 仅支持哪吒V1面板"
    echo "   - 仅支持VLESS协议"
    echo ""
    echo "2. Argo隧道WebSocket代理服务"
    echo "   - 使用Cloudflare Argo隧道"
    echo "   - 支持临时隧道和固定隧道"
    echo "   - 支持VLESS/VMess/Trojan协议"
    echo ""

    # 根据是否有更新显示不同的选项3
    if [ "$HAS_UPDATES" = true ]; then
        echo -e "3. ${GREEN}检查脚本更新 [有可用更新!]${NC}"
        echo "   - 发现以下脚本有更新:"
        echo -e "$UPDATE_LIST"
    else
        echo "3. 检查脚本更新"
        echo "   - 检查并更新已下载的脚本"
    fi
    echo ""
    echo "0. 退出脚本"
    echo ""

    read -p "请输入选项 [1]: " choice
    choice=${choice:-1}

    case $choice in
        0)
            # 用户选择退出
            print_info "退出脚本..."
            exit 0
            ;;
        1)
            # 统计用户选择了WebSocket版本
            record_choice "ws"
            print_info "正在准备WebSocket部署工具..."

            # 下载所需脚本
            if download_specific_script "setup-ws.sh"; then
                print_info "正在启动WebSocket部署工具..."
                sleep 1
                exec ./setup-ws.sh
            else
                print_error "无法下载所需脚本，请检查网络连接或手动下载"
                exit 1
            fi
            ;;
        2)
            # 统计用户选择了Argo版本
            record_choice "argo"
            print_info "正在准备Argo隧道WebSocket部署工具..."

            # 下载所需脚本
            if download_specific_script "setup-argo.sh"; then
                print_info "正在启动Argo隧道WebSocket部署工具..."
                sleep 1
                exec ./setup-argo.sh
            else
                print_error "无法下载所需脚本，请检查网络连接或手动下载"
                exit 1
            fi
            ;;
        3)
            # 统计用户选择了检查更新
            record_choice "update"
            print_info "正在检查脚本更新..."
            check_script_updates

            # 更新完成后，重新显示主菜单
            read -p "按Enter键返回主菜单..." dummy
            exec $0
            ;;
        *)
            print_error "无效选项，请选择0-3之间的数字"
            exit 1
            ;;
    esac
}

# 执行主函数
main