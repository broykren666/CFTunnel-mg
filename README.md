# Cloudflare Tunnel 管理脚本

这是一个用于快速安装、管理和更新 Cloudflare Tunnel (`cloudflared`) 的交互式 Bash 脚本。它专为 Linux 系统深度优化设计。

## 🚀 快速开始 (一键运行)

在终端中直接执行以下命令即可下载并运行（推荐）：

**使用 curl:**

```bash
curl -L https://raw.githubusercontent.com/broykren666/CFTunnel-mg/refs/heads/main/cft.sh -o cft.sh && chmod +x cft.sh && ./cft.sh
```

**或者使用 wget:**

```bash
wget https://raw.githubusercontent.com/broykren666/CFTunnel-mg/refs/heads/main/cft.sh -O cft.sh && chmod +x cft.sh && ./cft.sh
```

## ✨ 核心功能

- **自动化部署**：自动识别系统架构并安装/更新官方最新版。
- **配置便捷**：内置 Token 配置功能，一键将隧道安装为系统服务。
- **运维管理**：支持服务的启动、停止、重启以及实时日志查看。
- **全局命令**：首次运行自动注册 `cft` 快捷命令，随时随地一键呼出管理面板。

## 🛠️ 使用说明

### 1. 运行环境

- **Linux**: 标准终端即可，执行安装/卸载服务等操作时可能需要 sudo 或 root 权限。

### 2. 菜单详解

1. **安装 cloudflared**：下载并部署环境。
2. **更新 cloudflared**：平滑升级到官方最新版本。
3. **卸载 cloudflared**：从系统中彻底移除程序。
4. **配置 Token 并启动服务**：绑定您的隧道 Token 并设为开机自启。
5. **服务控制**：管理隧道的运行、停止与重启。
6. **查看实时运行日志**：排查 502/TLS 等连接问题的必备工具。
7. **退出脚本**：安全关闭管理界面。

---
由 Gemini CLI 生成
