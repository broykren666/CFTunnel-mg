# Cloudflare Tunnel (cloudflared) 管理脚本

这是一个用于快速安装、管理和更新 Cloudflare Tunnel (`cloudflared`) 的交互式 Bash 脚本。它支持 Windows (Git Bash)、Linux 和 macOS。

## 🚀 核心功能

- **多平台支持**：自动识别 Windows、Linux 和 macOS 系统。
- **自动安装/更新**：一键从 GitHub 获取最新版本的官方二进制文件。
- **状态监控**：实时查看隧道服务的运行状态（支持 Windows 服务和 Linux systemd）。
- **快捷访问**：支持添加 `cft` 命令，以后直接在终端输入即可启动管理菜单。
- **中文界面**：所有交互和提示信息均为中文，友好易用。

## 📂 文件说明

- `cft.sh`: 核心管理脚本。

## 🛠️ 快速上手

### 1. 准备工作 (Windows)
如果您使用的是 Windows，建议在 **Git Bash** 中运行此脚本。

### 2. 赋予执行权限
在终端中进入该目录，运行：
```bash
chmod +x cft.sh

chmod +x cft.sh && ./cft.sh
```

### 3. 运行脚本
```bash
bash cft.sh
```

### 4. 设置快捷命令 (推荐)
运行脚本后，选择选项 `4. 添加 'cft' 快捷命令`。
完成后，**重启终端**或运行 `source ~/.bash_profile`。
之后，您只需在任何地方输入以下命令即可打开管理菜单：
```bash
cft
```

## 📖 菜单功能详解

1. **安装 cloudflared**：根据系统架构自动下载并配置最新版的 `cloudflared`。
2. **更新 cloudflared**：检查并升级现有的 `cloudflared` 到最新版本。
3. **卸载 cloudflared**：从系统中移除 `cloudflared` 二进制文件。
4. **添加 'cft' 快捷命令**：将此脚本关联到别名 `cft`，方便快速调用。
0. **退出脚本**：关闭管理界面。

## ⚠️ 注意事项

- **管理员权限**：在 Linux/macOS 上执行安装或更新时，可能需要输入密码以获取 `sudo` 权限。在 Windows 上，建议以管理员身份运行 Git Bash。
- **换行符**：此脚本已配置为使用 LF 换行符，请勿使用 Windows 记事本等可能更改换行符的编辑器修改脚本内容。

---
*由 Gemini CLI 生成*
