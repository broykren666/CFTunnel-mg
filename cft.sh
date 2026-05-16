#!/bin/bash

# Cloudflare Tunnel (cloudflared) Management Script
# Designed for Windows (Git Bash), Linux, and macOS

# Ensure we are using LF line endings
# Set colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect System
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

# Detect sudo availability
SUDO=""
if command -v sudo &> /dev/null && [[ "$CURRENT_OS" != "Windows" ]]; then
    SUDO="sudo"
fi

# Get Tunnel Status
get_status() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}Not Installed${NC}"
        return
    fi

    if [[ "$CURRENT_OS" == "Windows" ]]; then
        # Check Windows Service status using sc.exe
        if sc.exe query cloudflared 2>/dev/null | grep -q "RUNNING"; then
            echo -e "${GREEN}Running (Service)${NC}"
        else
            echo -e "${YELLOW}Stopped / No Service${NC}"
        fi
    elif [[ "$CURRENT_OS" == "Linux" ]]; then
        if command -v systemctl &> /dev/null && systemctl is-active --quiet cloudflared 2>/dev/null; then
            echo -e "${GREEN}Running (Service)${NC}"
        elif pgrep -x "cloudflared" > /dev/null; then
            echo -e "${GREEN}Running (Process)${NC}"
        else
            echo -e "${YELLOW}Stopped${NC}"
        fi
    else
        # For macOS or others
        if pgrep -x "cloudflared" > /dev/null; then
            echo -e "${GREEN}Running${NC}"
        else
            echo -e "${YELLOW}Stopped${NC}"
        fi
    fi
}

# Install cloudflared
install_cloudflared() {
    echo -e "${BLUE}Installing cloudflared...${NC}"
    case "$CURRENT_OS" in
        Windows)
            if command -v winget &> /dev/null; then
                winget install --id Cloudflare.cloudflared
            else
                echo -e "${YELLOW}winget not found. Downloading binary...${NC}"
                curl -L -o cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
                # Move to a directory in PATH if possible, or keep it local
                echo -e "${YELLOW}Downloaded cloudflared.exe to current directory.${NC}"
                echo -e "${YELLOW}Please move it to a folder in your PATH manually if winget is unavailable.${NC}"
            fi
            ;;
        Linux)
            # Detect architecture
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
                echo -e "${YELLOW}Homebrew not found. Downloading binary...${NC}"
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
    echo -e "${GREEN}Installation attempt complete!${NC}"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Update cloudflared
update_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}cloudflared is not installed.${NC}"
    else
        echo -e "${BLUE}Updating cloudflared...${NC}"
        if [[ "$CURRENT_OS" == "Windows" ]]; then
            cloudflared update
        else
            $SUDO cloudflared update
        fi
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

# Uninstall cloudflared
uninstall_cloudflared() {
    echo -e "${RED}Uninstalling cloudflared...${NC}"
    case "$CURRENT_OS" in
        Windows)
            if command -v winget &> /dev/null; then
                winget uninstall --id Cloudflare.cloudflared
            else
                echo -e "${YELLOW}Please uninstall Cloudflare Tunnel via Control Panel or delete the binary.${NC}"
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
    echo -e "${GREEN}Uninstallation complete!${NC}"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Add Shortcut Command 'cft'
add_shortcut() {
    # Get absolute path of the script
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    SHELL_RC=""
    
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        if [[ "$CURRENT_OS" == "Windows" ]]; then
            # Check for common bash config files in Git Bash
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
        # Check if alias already exists
        if grep -q "alias cft=" "$SHELL_RC" 2>/dev/null; then
            # Update existing alias
            sed -i "s|alias cft=.*|alias cft='bash $SCRIPT_PATH'|" "$SHELL_RC"
            echo -e "${GREEN}Shortcut 'cft' updated in $SHELL_RC${NC}"
        else
            echo "" >> "$SHELL_RC"
            echo "alias cft='bash $SCRIPT_PATH'" >> "$SHELL_RC"
            echo -e "${GREEN}Shortcut 'cft' added to $SHELL_RC${NC}"
        fi
        echo -e "${BLUE}Please restart your shell or run: source $SHELL_RC${NC}"
    else
        echo -e "${RED}Could not detect shell configuration file. Please add this manually:${NC}"
        echo -e "${YELLOW}alias cft='bash $SCRIPT_PATH'${NC}"
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

# Main Menu
while true; do
    clear
    STATUS=$(get_status)
    echo "======================================================"
    echo "      Cloudflare Tunnel Management Script"
    echo "------------------------------------------------------"
    echo -e " System: ${BLUE}$CURRENT_OS${NC} | Status: $STATUS"
    echo "======================================================"
    echo " 1. Install cloudflared"
    echo " 2. Update cloudflared"
    echo " 3. Uninstall cloudflared"
    echo " 4. Add 'cft' shortcut command"
    echo " 0. Exit"
    echo "------------------------------------------------------"
    read -p " Select an option [0-4]: " choice

    case $choice in
        1) install_cloudflared ;;
        2) update_cloudflared ;;
        3) uninstall_cloudflared ;;
        4) add_shortcut ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
    esac
done
