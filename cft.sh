#!/bin/bash

# Cloudflare Tunnel (cloudflared) 管理脚本
# Designed for Windows (Git Bash), Linux, and macOS

# 颜色设置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 自动检测系统
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=macOS;;
        MINGW*)     OS=Windows;;
        MSYS*)      OS=Windows;;
        *)          OS="UNKNOWN:${unameOut}"
    esac
    echo $OS
}

CURRENT_OS=$(detect_os)

# 检测 sudo 可用性
SUDO=""
if command -v sudo &> /dev/null && [[ "$CURRENT_OS" != "Windows" ]]; then
    SUDO="sudo"
fi

# 获取隧道状态
get_status() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    if [[ "$CURRENT_OS" == "Windows" ]]; then
        if sc.exe query cloudflared 2>/dev/null | grep -q "RUNNING"; then
            echo -e "${GREEN}运行中 (服务)${NC}"
        else
            echo -e "${YELLOW}已停止 / 无服务${NC}"
        fi
    elif [[ "$CURRENT_OS" == "Linux" ]]; then
        if command -v systemctl &> /dev/null && systemctl is-active --quiet cloudflared 2>/dev/null; then
            echo -e "${GREEN}运行中 (服务)${NC}"
        elif pgrep -x "cloudflared" > /dev/null; then
            echo -e "${GREEN}运行中 (进程)${NC}"
        else
            echo -e "${YELLOW}已停止${NC}"
        fi
    else
        if pgrep -x "cloudflared" > /dev/null; then
            echo -e "${GREEN}运行中${NC}"
        else
            echo -e "${YELLOW}已停止${NC}"
        fi
    fi
}

# 安装 cloudflared
install_cloudflared() {
    echo -e "${BLUE}正在安装 cloudflared...${NC}"
    case "$CURRENT_OS" in
        Windows)
            if command -v winget &> /dev/null; then
                winget install --id Cloudflare.cloudflared
            else
                echo -e "${YELLOW}未找到 winget，正在下载二进制文件...${NC}"
                curl -L -o cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
                echo -e "${YELLOW}cloudflared.exe 已下载到当前目录。${NC}"
            fi
            ;;
        Linux)
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
            ;;
        macOS)
            if command -v brew &> /dev/null; then
                brew install cloudflare/cloudflare/cloudflared
            else
                echo -e "${YELLOW}未找到 Homebrew，正在下载二进制文件...${NC}"
                curl -L -o cloudflared.tgz https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz
                tar -xzf cloudflared.tgz
                chmod +x cloudflared
                if [[ -n "$SUDO" ]]; then
                    $SUDO mv cloudflared /usr/local/bin/
                else
                    mv cloudflared /usr/local/bin/
                fi
                rm cloudflared.tgz
            fi
            ;;
    esac
    echo -e "${GREEN}安装尝试完成！${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 更新 cloudflared
update_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}未安装 cloudflared。${NC}"
    else
        echo -e "${BLUE}正在更新 cloudflared...${NC}"
        if [[ "$CURRENT_OS" == "Windows" ]]; then
            cloudflared update
        else
            $SUDO cloudflared update
        fi
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 卸载 cloudflared
uninstall_cloudflared() {
    echo -e "${RED}正在卸载 cloudflared...${NC}"
    case "$CURRENT_OS" in
        Windows)
            if command -v winget &> /dev/null; then
                winget uninstall --id Cloudflare.cloudflared
            else
                echo -e "${YELLOW}请手动删除二进制文件。${NC}"
            fi
            ;;
        Linux|macOS)
            if [[ -n "$SUDO" ]]; then
                $SUDO rm /usr/local/bin/cloudflared
            else
                rm /usr/local/bin/cloudflared
            fi
            ;;
    esac
    echo -e "${GREEN}卸载完成！${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

# 添加快捷命令 'cft'
add_shortcut() {
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    SHELL_RC=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        if [[ "$CURRENT_OS" == "Windows" ]]; then
            if [[ -f "$HOME/.bash_profile" ]]; then
                SHELL_RC="$HOME/.bash_profile"
            elif [[ -f "$HOME/.bashrc" ]]; then
                SHELL_RC="$HOME/.bashrc"
            else
                SHELL_RC="$HOME/.bash_profile"
            fi
        else
            SHELL_RC="$HOME/.bashrc"
        fi
    fi
    if [[ -n "$SHELL_RC" ]]; then
        if grep -q "alias cft=" "$SHELL_RC" 2>/dev/null; then
            sed -i "s|alias cft=.*|alias cft='bash $SCRIPT_PATH'|" "$SHELL_RC"
            echo -e "${GREEN}快捷命令 'cft' 已在 $SHELL_RC 中更新${NC}"
        else
            echo "" >> "$SHELL_RC"
            echo "alias cft='bash $SCRIPT_PATH'" >> "$SHELL_RC"
            echo -e "${GREEN}快捷命令 'cft' 已添加到 $SHELL_RC${NC}"
        fi
        echo -e "${BLUE}请重启 Shell 或运行: source $SHELL_RC${NC}"
    else
        echo -e "${RED}未能检测到 Shell 配置文件。请手动添加：alias cft='bash $SCRIPT_PATH'${NC}"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 主菜单
while true; do
    clear
    STATUS=$(get_status)
    echo "======================================================"
    echo "          Cloudflare Tunnel 隧道管理脚本"
    echo "------------------------------------------------------"
    echo -e " 系统类型: ${BLUE}$CURRENT_OS${NC} | 当前状态: $STATUS"
    echo "======================================================"
    echo " 1. 安装 cloudflared"
    echo " 2. 更新 cloudflared"
    echo " 3. 卸载 cloudflared"
    echo " 4. 添加 'cft' 快捷命令"
    echo " 0. 退出脚本"
    echo "------------------------------------------------------"
    read -p " 请选择一个选项 [0-4]: " choice
    case $choice in
        1) install_cloudflared ;;
        2) update_cloudflared ;;
        3) uninstall_cloudflared ;;
        4) add_shortcut ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}无效选项！${NC}"; sleep 1 ;;
    esac
done
