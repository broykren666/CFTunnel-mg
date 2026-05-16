#!/bin/bash

# Cloudflare Tunnel (cloudflared) 管理脚本
# Designed for Linux

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
SCRIPT_PATH=$(readlink -f "$0")
if [[ "$SCRIPT_PATH" != "/usr/local/bin/cft" && -f "$SCRIPT_PATH" ]]; then
    if $SUDO cp -f "$SCRIPT_PATH" /usr/local/bin/cft 2>/dev/null; then
        $SUDO chmod +x /usr/local/bin/cft
        echo -e "${GREEN}✅ 已为您创建全局快捷命令！下次可在终端任意位置直接输入 ${BLUE}cft${GREEN} 打开本面板。${NC}"
        sleep 2
    fi
fi

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
    echo -e "${BLUE}正在安装 cloudflared...${NC}"
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        FILE="cloudflared-linux-amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        FILE="cloudflared-linux-arm64"
    else
        FILE="cloudflared-linux-386"
    fi
    if ! curl -L -o cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/$FILE"; then
        echo -e "${RED}下载失败！请检查服务器网络能否访问 Github。${NC}"
        return
    fi
    chmod +x cloudflared
    if [[ -n "$SUDO" ]]; then
        $SUDO mv cloudflared /usr/local/bin/
    else
        mv cloudflared $HOME/bin/ 2>/dev/null || mv cloudflared /usr/local/bin/
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
        read -n 1 -s -r -p "按任意键继续..."
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
    
    if [[ -n "$SUDO" ]]; then
        $SUDO rm -f /usr/local/bin/cloudflared
        $SUDO rm -rf /etc/cloudflared
    else
        rm -f /usr/local/bin/cloudflared
        rm -rf /etc/cloudflared
    fi
    echo -e "${GREEN}卸载完成！程序和相关配置已清理。${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 配置并启动隧道服务 (Token 输入加密)
configure_token() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}错误：请先安装 cloudflared (选项 1)${NC}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi

    if command -v systemctl &> /dev/null && systemctl list-unit-files | grep -q cloudflared.service; then
        echo -e "${YELLOW}警告：检测到系统已配置了 Cloudflare Tunnel 服务。${NC}"
        read -p "继续操作将覆盖现有配置并重启服务。是否确认继续？[y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}已取消操作。${NC}"
            read -n 1 -s -r -p "按任意键继续..."
            return
        fi
    fi

    echo -e "${BLUE}请输入您的 Cloudflare Tunnel Token (输入时不会显示字符):${NC}"
    read -s -p "> " token
    echo "" # 换行
    if [[ -z "$token" ]]; then
        echo -e "${RED}Token 不能为空！${NC}"
    else
        echo -e "${BLUE}正在配置隧道服务...${NC}"
        if command -v systemctl &> /dev/null && systemctl list-unit-files | grep -q cloudflared.service; then
            $SUDO cloudflared service uninstall 2>/dev/null
        fi
        $SUDO cloudflared service install "$token"
        echo -e "${GREEN}配置完成！请检查上方输出。${NC}"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 服务管理 (启动/停止/重启)
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

    case $s_choice in
        1)
            $SUDO systemctl start cloudflared
            ;;
        2)
            $SUDO systemctl stop cloudflared
            ;;
        3)
            $SUDO systemctl restart cloudflared
            ;;
        *) return ;;
    esac
    echo -e "${GREEN}操作已执行。${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 查看运行日志
view_logs() {
    echo -e "${BLUE}正在调取实时日志 (按 Ctrl+C 退出)...${NC}"
    if command -v journalctl &> /dev/null; then
        $SUDO journalctl -u cloudflared -f -n 50
    else
        # 兼容 NAT VPS (如 OpenVZ/LXC) 等没有 systemd/journalctl 的情况
        LOG_FILES=("/var/log/cloudflared.log" "/var/log/cloudflared.err" "/var/log/daemon.log" "/var/log/syslog" "/var/log/messages")
        FOUND_LOG=""
        for log in "${LOG_FILES[@]}"; do
            if [[ -f "$log" ]]; then
                FOUND_LOG="$log"
                break
            fi
        done
        
        if [[ -n "$FOUND_LOG" ]]; then
            echo -e "${YELLOW}未找到 journalctl，正在降级查看 $FOUND_LOG ...${NC}"
            if [[ "$FOUND_LOG" == "/var/log/cloudflared."* ]]; then
                $SUDO tail -f "$FOUND_LOG"
            else
                # 系统混合日志，需要过滤 cloudflared 关键词
                $SUDO tail -f -n 50 "$FOUND_LOG" | grep --line-buffered -i "cloudflared"
            fi
        else
            echo -e "${RED}未找到 journalctl，也未找到默认的系统日志文件。${NC}"
            echo -e "${YELLOW}若一直连不上，可手动执行尝试：cloudflared tunnel --no-autoupdate run --token <您的Token>${NC}"
            read -n 1 -s -r -p "按任意键继续..."
        fi
    fi
}

# 更新管理脚本
update_script() {
    echo -e "${BLUE}正在从 GitHub 获取最新版管理脚本...${NC}"
    SCRIPT_URL="https://raw.githubusercontent.com/broykren666/CFTunnel-mg/refs/heads/main/cft.sh"
    
    TMP_FILE=$(mktemp)
    if ! curl -sL -o "$TMP_FILE" "$SCRIPT_URL"; then
        echo -e "${RED}下载失败！请检查服务器网络能否访问 Github。${NC}"
        rm -f "$TMP_FILE"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    SCRIPT_PATH=$(readlink -f "$0")
    $SUDO cp -f "$TMP_FILE" "$SCRIPT_PATH"
    $SUDO chmod +x "$SCRIPT_PATH"
    rm -f "$TMP_FILE"
    
    if [[ -f "/usr/local/bin/cft" && "$SCRIPT_PATH" != "/usr/local/bin/cft" ]]; then
        $SUDO cp -f "$SCRIPT_PATH" /usr/local/bin/cft
        $SUDO chmod +x /usr/local/bin/cft
    fi
    
    echo -e "${GREEN}✅ 管理脚本已成功更新到最新版本！${NC}"
    echo -e "${YELLOW}自动重启生效...${NC}"
    sleep 1
    exec "$SCRIPT_PATH"
}

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
    case $choice in
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
