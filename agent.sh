#!/bin/sh

NZ_BASE_PATH="$HOME/nezha"
NZ_AGENT_PATH="${NZ_BASE_PATH}/agent"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

err() {
    printf "${red}%s${plain}\n" "$*" >&2
}

success() {
    printf "${green}%s${plain}\n" "$*"
}

warn() {
    printf "${red}%s${plain}\n" "$*"
}

info() {
    printf "${yellow}%s${plain}\n" "$*"
}

deps_check() {
    deps="wget unzip grep"
    set -- "$api_list"
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            err "$dep not found, please install it first."
            exit 1
        fi
    done
}

geo_check() {
    api_list="https://blog.cloudflare.com/cdn-cgi/trace https://developers.cloudflare.com/cdn-cgi/trace"
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    set -- "$api_list"
    for url in $api_list; do
        text="$(curl -A "$ua" -m 10 -s "$url")"
        endpoint="$(echo "$text" | sed -n 's/.*h=\([^ ]*\).*/\1/p')"
        if echo "$text" | grep -qw 'CN'; then
            isCN=true
            break
        elif echo "$url" | grep -q "$endpoint"; then
            break
        fi
    done
}

env_check() {
    mach=$(uname -m)
    case "$mach" in
        amd64|x86_64)
            os_arch="amd64"
            ;;
        i386|i686)
            os_arch="386"
            ;;
        aarch64|arm64)
            os_arch="arm64"
            ;;
        *arm*)
            os_arch="arm"
            ;;
        s390x)
            os_arch="s390x"
            ;;
        riscv64)
            os_arch="riscv64"
            ;;
        mips)
            os_arch="mips"
            ;;
        mipsel|mipsle)
            os_arch="mipsle"
            ;;
        *)
            err "Unknown architecture: $uname"
            exit 1
            ;;
    esac

    system=$(uname)
    case "$system" in
        *Linux*)
            os="linux"
            ;;
        *Darwin*)
            os="darwin"
            ;;
        *FreeBSD*)
            os="freebsd"
            ;;
        *)
            err "Unknown architecture: $system"
            exit 1
            ;;
    esac
}

init() {
    deps_check
    env_check

    ## China_IP
    if [ -z "$CN" ]; then
        geo_check
        if [ -n "$isCN" ]; then
            CN=true
        fi
    fi

    if [ -z "$CN" ]; then
        GITHUB_URL="github.com"
    else
        GITHUB_URL="gitee.com"
    fi
}

install() {
    echo "Installing..."

    # 使用用户目录而不是/tmp目录
    TEMP_DIR="$HOME/nezha_temp"
    mkdir -p "$TEMP_DIR"

    # 检查是否已经下载了文件
    if [ -f "nezha-agent_linux_amd64.zip" ] && [ "$os" = "linux" ] && [ "$os_arch" = "amd64" ]; then
        echo "Using existing file in current directory: nezha-agent_linux_amd64.zip"
        cp "nezha-agent_linux_amd64.zip" "$TEMP_DIR/nezha-agent_${os}_${os_arch}.zip"
        if [ $? -ne 0 ]; then
            err "Failed to copy file to $TEMP_DIR"
            exit 1
        fi
    else
        # 使用固定的GitHub URL，避免重定向问题
        NZ_AGENT_URL="https://github.com/nezhahq/agent/releases/download/v1.12.2/nezha-agent_${os}_${os_arch}.zip"

        echo "Downloading from: $NZ_AGENT_URL"

        # 直接使用wget命令，不使用eval，并显示下载进度
        if ! wget -T 60 -O "$TEMP_DIR/nezha-agent_${os}_${os_arch}.zip" "$NZ_AGENT_URL"; then
            err "Download nezha-agent release failed, check your network connectivity"
            err "Please download the file manually and place it in the current directory"
            exit 1
        fi
    fi

    # 验证文件是否存在
    if [ ! -f "$TEMP_DIR/nezha-agent_${os}_${os_arch}.zip" ]; then
        err "File not found: $TEMP_DIR/nezha-agent_${os}_${os_arch}.zip"
        exit 1
    fi

    # 创建agent目录
    mkdir -p "$NZ_AGENT_PATH"
    if [ $? -ne 0 ]; then
        err "Failed to create directory: $NZ_AGENT_PATH"
        exit 1
    fi

    # 解压文件
    echo "Extracting file to $NZ_AGENT_PATH..."
    unzip -o "$TEMP_DIR/nezha-agent_${os}_${os_arch}.zip" -d "$NZ_AGENT_PATH"
    if [ $? -ne 0 ]; then
        err "Failed to extract file"
        exit 1
    fi
    
    # 检查解压后的文件是否存在
    if [ ! -f "$NZ_AGENT_PATH/nezha-agent" ]; then
        err "Extracted file not found: $NZ_AGENT_PATH/nezha-agent"
        # 尝试直接复制已下载的文件到目标位置
        if [ -f "nezha-agent" ]; then
            echo "Found nezha-agent in current directory, copying..."
            cp "nezha-agent" "$NZ_AGENT_PATH/nezha-agent"
            chmod +x "$NZ_AGENT_PATH/nezha-agent"
        else
            exit 1
        fi
    fi
    
    # 设置执行权限
    chmod +x "$NZ_AGENT_PATH/nezha-agent"
    
    # 清理临时文件
    rm -f "$TEMP_DIR/nezha-agent_${os}_${os_arch}.zip"

    path="$NZ_AGENT_PATH/config.yml"
    if [ -f "$path" ]; then
        random=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 5)
        path=$(printf "%s" "$NZ_AGENT_PATH/config-$random.yml")
    fi

    if [ -z "$NZ_SERVER" ]; then
        err "NZ_SERVER should not be empty"
        exit 1
    fi

    if [ -z "$NZ_CLIENT_SECRET" ]; then
        err "NZ_CLIENT_SECRET should not be empty"
        exit 1
    fi

    env="NZ_UUID=$NZ_UUID NZ_SERVER=$NZ_SERVER NZ_CLIENT_SECRET=$NZ_CLIENT_SECRET NZ_TLS=$NZ_TLS NZ_DISABLE_AUTO_UPDATE=$NZ_DISABLE_AUTO_UPDATE NZ_DISABLE_FORCE_UPDATE=$DISABLE_FORCE_UPDATE NZ_DISABLE_COMMAND_EXECUTE=$NZ_DISABLE_COMMAND_EXECUTE NZ_SKIP_CONNECTION_COUNT=$NZ_SKIP_CONNECTION_COUNT"

    # 保活循环，确保 nezha-agent 退出后自动重启
    echo "Starting nezha-agent with keep-alive..."
    while true; do
        echo "nezha-agent started at $(date)"
        env $env $NZ_AGENT_PATH/nezha-agent $path
        echo "nezha-agent exited with code $?. Restarting in 5 seconds..."
        sleep 5
    done &
    success "nezha-agent successfully installed with keep-alive"
    warn "To stop nezha-agent, kill the process: pgrep -u $USER nezha-agent"
    warn "To manage the keep-alive process, find the parent shell: ps aux | grep 'sh.*agent.sh'"
}

uninstall() {
    find "$NZ_AGENT_PATH" -type f -name "*config*.yml" | while read -r file; do
        rm  "$NZ_AGENT_PATH/nezha-agent"
        rm "$file"
        pids=$(pgrep -u "$USER" nezha-agent)
        if [ -n "$pids" ]; then
            kill $pids
            info "Terminated nezha-agent processes: nezha-agent"
        else
            warn "No nezha-agent processes found to terminate."
        fi
    done
    # 终止保活脚本进程
    pids=$(pgrep -u "$USER" -f "sh.*agent.sh")
    if [ -n "$pids" ]; then
        kill $pids
        info "Terminated keep-alive shell processes"
    else
        warn "No keep-alive shell processes found to terminate."
    fi
    info "Uninstallation completed."
}

if [ "$1" = "uninstall" ]; then
    uninstall
    exit
fi

init
install