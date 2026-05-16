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
    curl -L -o cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/$FILE
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
    echo -e "${RED}正在卸载 cloudflared...${NC}"
    if [[ -n "$SUDO" ]]; then
        $SUDO rm /usr/local/bin/cloudflared
    else
        rm /usr/local/bin/cloudflared
    fi
    echo -e "${GREEN}卸载完成！${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 配置并启动隧道服务 (Token 输入加密)
configure_token() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}错误：请先安装 cloudflared (选项 1)${NC}"
    else
        echo -e "${BLUE}请输入您的 Cloudflare Tunnel Token (输入时不会显示字符):${NC}"
        read -s -p "> " token
        echo "" # 换行
        if [[ -z "$token" ]]; then
            echo -e "${RED}Token 不能为空！${NC}"
        else
            echo -e "${BLUE}正在配置隧道服务...${NC}"
            $SUDO cloudflared service install "$token"
            echo -e "${GREEN}配置完成！请检查上方输出。${NC}"
        fi
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
        echo -e "${RED}未找到 journalctl，请手动查看 /var/log/syslog 或相关日志。${NC}"
        read -n 1 -s -r -p "按任意键继续..."
    fi
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
    echo " 0. 退出脚本"
    echo "------------------------------------------------------"
    read -p " 请选择一个选项 [0-6]: " choice
    case $choice in
        1) install_cloudflared ;;
        2) update_cloudflared ;;
        3) uninstall_cloudflared ;;
        4) configure_token ;;
        5) manage_service ;;
        6) view_logs ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}无效选项！${NC}"; sleep 1 ;;
    esac
done
