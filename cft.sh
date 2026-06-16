#!/bin/bash

# Cloudflare Tunnel (cloudflared) 管理脚本
# Designed for Linux

# 脚本配置
SCRIPT_URL="https://raw.githubusercontent.com/broykren666/CFTunnel-mg/refs/heads/main/cft.sh"

# 颜色设置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 检测 sudo 可用性
SUDO=""
if command -v sudo &> /dev/null; then
    SUDO="sudo"
fi

# 检测权限
if [[ "$EUID" -ne 0 && -z "$SUDO" ]]; then
    echo -e "${RED}错误：请使用 root 用户运行此脚本，或确保已安装 sudo。${NC}"
    exit 1
fi

# 检测必需工具
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误：未找到 curl，请先执行相应的包管理器命令 (如 apt/yum install curl) 安装。${NC}"
    exit 1
fi

# ==========================================
# 自动添加全局快捷命令
# ==========================================
install_shortcut() {
    local script_path
    script_path=$(readlink -f "$0")
    if [[ "$script_path" != "/usr/local/bin/cft" && -f "$script_path" ]]; then
        if $SUDO cp -f "$script_path" /usr/local/bin/cft 2>/dev/null; then
            $SUDO chmod +x /usr/local/bin/cft
            echo -e "${GREEN}✅ 已为您创建全局快捷命令！下次可在终端任意位置直接输入 ${BLUE}cft${GREEN} 打开本面板。${NC}"
            sleep 1
        fi
    fi
}

# 获取隧道状态
get_status() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    if command -v systemctl &> /dev/null && systemctl is-active --quiet cloudflared 2>/dev/null; then
        echo -e "${GREEN}运行中 (服务)${NC}"
    elif pgrep -x "cloudflared" > /dev/null; then
        echo -e "${GREEN}运行中 (进程)${NC}"
    else
        echo -e "${YELLOW}已停止${NC}"
    fi
}

# 安装 cloudflared
install_cloudflared() {
    echo -e "${BLUE}正在识别系统架构...${NC}"
    local arch file
    arch=$(uname -m)
    case "$arch" in
        x86_64)          file="cloudflared-linux-amd64" ;;
        aarch64|arm64)   file="cloudflared-linux-arm64" ;;
        armv7l|armv6l)   file="cloudflared-linux-arm" ;;
        i386|i686)       file="cloudflared-linux-386" ;;
        *)
            echo -e "${RED}错误：暂不支持的架构 $arch。请手动下载对应版本。${NC}"
            read -n 1 -s -r -p "按任意键继续..."
            return
            ;;
    esac

    echo -e "${BLUE}正在下载 cloudflared ($arch)...${NC}"
    if ! curl -L -o cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/$file"; then
        echo -e "${RED}下载失败！请检查服务器网络能否访问 Github。${NC}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi

    chmod +x cloudflared
    if [[ -n "$SUDO" ]]; then
        $SUDO mv -f cloudflared /usr/local/bin/
    else
        # 尝试安装到用户 bin 目录并提醒
        mkdir -p "$HOME/bin"
        mv -f cloudflared "$HOME/bin/"
        if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
            echo -e "${YELLOW}警告：$HOME/bin 不在 PATH 中，您可能无法直接运行 cloudflared。${NC}"
        fi
    fi

    echo -e "${GREEN}安装尝试完成！${NC}"
    echo -e "${YELLOW}提示：软件已安装。接下来请执行菜单 [选项 4] 来配置您的 Token 并启用隧道服务。${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 更新 cloudflared
update_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}未安装 cloudflared。${NC}"
    else
        echo -e "${BLUE}正在更新 cloudflared...${NC}"
        $SUDO cloudflared update
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 卸载 cloudflared
uninstall_cloudflared() {
    echo -e "${RED}警告：您即将完全卸载 Cloudflare Tunnel 程序并清除所有配置！${NC}"
    read -p "是否确认执行卸载操作？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}已取消卸载操作。${NC}"
        read -n 1 -s -r -p "按任意键 continue..."
        return
    fi

    echo -e "${RED}正在卸载 cloudflared...${NC}"
    if command -v cloudflared &> /dev/null; then
        echo -e "${YELLOW}正在注销系统服务...${NC}"
        $SUDO cloudflared service uninstall 2>/dev/null
        if command -v systemctl &> /dev/null; then
            $SUDO systemctl daemon-reload
        fi
    fi
    
    # 彻底清理进程
    if command -v pkill &> /dev/null; then
        $SUDO pkill -9 -x cloudflared 2>/dev/null
    else
        $SUDO kill -9 $(pgrep -x cloudflared) 2>/dev/null
    fi

    # 清理程序和所有可能的配置目录
    $SUDO rm -f /usr/local/bin/cloudflared
    $SUDO rm -rf /etc/cloudflared
    rm -rf "$HOME/.cloudflared" # 增加用户家目录清理
    
    echo -e "${GREEN}卸载完成！程序和相关配置已清理。${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 配置并启动隧道服务
configure_token() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}错误：请先安装 cloudflared (选项 1)${NC}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi

    # 兼容检查
    local service_exists=false
    if command -v systemctl &> /dev/null && systemctl list-unit-files | grep -q cloudflared.service; then
        service_exists=true
    elif [[ -f "/etc/init.d/cloudflared" ]] || pgrep -x "cloudflared" > /dev/null; then
        service_exists=true
    fi

    if [[ "$service_exists" == true ]]; then
        echo -e "${YELLOW}警告：检测到系统已配置了 Cloudflare Tunnel 服务或有正在运行的进程。${NC}"
        read -p "继续操作将覆盖现有配置并重启服务。是否确认继续？[y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}已取消操作。${NC}"
            read -n 1 -s -r -p "按任意键继续..."
            return
        fi
    fi

    echo -e "${BLUE}请输入您的 Cloudflare Tunnel Token (输入时不会显示字符):${NC}"
    read -s -p "> " token
    echo "" 
    if [[ -z "$token" ]]; then
        echo -e "${RED}Token 不能为空！${NC}"
    else
        echo -e "${BLUE}正在配置隧道服务...${NC}"
        # 先清理旧服务确保安装成功
        $SUDO cloudflared service uninstall 2>/dev/null
        if command -v pkill &> /dev/null; then
            $SUDO pkill -9 -x cloudflared 2>/dev/null
        else
            $SUDO kill -9 $(pgrep -x cloudflared) 2>/dev/null
        fi
        
        if $SUDO cloudflared service install "$token"; then
            echo -e "${GREEN}✅ 配置成功！服务已自动启动。${NC}"
        else
            echo -e "${RED}❌ 配置失败，请检查上方报错信息。${NC}"
        fi
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 服务管理
manage_service() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}错误：请先安装 cloudflared${NC}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi

    echo -e "${BLUE}--- 服务管理 ---${NC}"
    echo " 1. 启动服务"
    echo " 2. 停止服务"
    echo " 3. 重启服务"
    echo " 0. 返回主菜单"
    read -p " 请选择 [0-3]: " s_choice

    local cmd=""
    case $s_choice in
        1) cmd="start" ;;
        2) cmd="stop" ;;
        3) cmd="restart" ;;
        *) return ;;
    esac

    if command -v systemctl &> /dev/null; then
        $SUDO systemctl "$cmd" cloudflared
    elif command -v service &> /dev/null; then
        $SUDO service cloudflared "$cmd"
    else
        echo -e "${RED}错误：未找到 systemctl 或 service 命令，无法管理服务。${NC}"
    fi
    
    echo -e "${GREEN}操作已执行。${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 查看运行日志
view_logs() {
    echo -e "${BLUE}正在调取实时日志 (按 Ctrl+C 退出)...${NC}"
    if command -v journalctl &> /dev/null; then
        $SUDO journalctl -u cloudflared -f -n 50
    else
        local log_files=("/var/log/cloudflared.log" "/var/log/cloudflared.err" "/var/log/daemon.log" "/var/log/syslog" "/var/log/messages")
        local found_log=""
        for log in "${log_files[@]}"; do
            if [[ -f "$log" ]]; then
                found_log="$log"
                break
            fi
        done
        
        if [[ -n "$found_log" ]]; then
            echo -e "${YELLOW}未找到 journalctl，正在降级查看 $found_log ...${NC}"
            if [[ "$found_log" == "/var/log/cloudflared."* ]]; then
                $SUDO tail -f "$found_log"
            else
                $SUDO tail -f -n 50 "$found_log" | grep --line-buffered -i "cloudflared"
            fi
        else
            echo -e "${RED}未找到 journalctl，也未找到默认的系统日志文件。${NC}"
            echo -e "${YELLOW}提示：您可以尝试手动运行查看报错：cloudflared tunnel run --token <您的Token>${NC}"
            read -n 1 -s -r -p "按任意键继续..."
        fi
    fi
}

# 更新管理脚本
update_script() {
    echo -e "${BLUE}正在从 GitHub 获取最新版管理脚本...${NC}"
    local tmp_file
    tmp_file=$(mktemp)
    
    if ! curl -sL -o "$tmp_file" "$SCRIPT_URL"; then
        echo -e "${RED}下载失败！请检查服务器网络能否访问 Github。${NC}"
        rm -f "$tmp_file"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    local script_path
    script_path=$(readlink -f "$0")
    
    # 覆盖当前脚本
    if $SUDO cp -f "$tmp_file" "$script_path"; then
        $SUDO chmod +x "$script_path"
        
        # 同时更新全局命令
        if [[ -f "/usr/local/bin/cft" ]]; then
            $SUDO cp -f "$script_path" /usr/local/bin/cft
        fi
        
        echo -e "${GREEN}✅ 管理脚本已成功更新到最新版本！${NC}"
        echo -e "${YELLOW}自动重启生效...${NC}"
        sleep 1
        rm -f "$tmp_file"
        exec "$script_path"
    else
        echo -e "${RED}覆盖失败，请检查权限。${NC}"
        rm -f "$tmp_file"
        read -n 1 -s -r -p "按任意键继续..."
    fi
}

# 运行初始化
install_shortcut

# 主菜单
while true; do
    clear
    STATUS=$(get_status)
    echo "======================================================"
    echo "          Cloudflare Tunnel 隧道管理脚本"
    echo "------------------------------------------------------"
    echo -e " 服务状态: $STATUS"
    echo "======================================================"
    echo " 1. 安装 cloudflared"
    echo " 2. 更新 cloudflared"
    echo " 3. 卸载 cloudflared"
    echo " 4. 配置 Token 并启动服务"
    echo " 5. 服务控制 (启动/停止/重启)"
    echo " 6. 查看实时运行日志"
    echo " 7. 更新管理脚本"
    echo " 0. 退出脚本"
    echo "------------------------------------------------------"
    read -p " 请选择一个选项 [0-7]: " choice
    case "$choice" in
        1) install_cloudflared ;;
        2) update_cloudflared ;;
        3) uninstall_cloudflared ;;
        4) configure_token ;;
        5) manage_service ;;
        6) view_logs ;;
        7) update_script ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}无效选项！${NC}"; sleep 1 ;;
    esac
done
