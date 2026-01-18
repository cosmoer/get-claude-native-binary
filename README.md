# Claude Code 原生二进制文件下载器

这是一个用于下载 Claude Code 原生二进制文件的脚本集合，支持 Windows 和 Linux 平台。

## 功能特性

- 支持 Windows 和 Linux 平台的原生二进制文件下载
- 自动从官方 Google Cloud Storage 获取最新版本
- SHA256 校验和验证，确保下载文件完整性
- 支持 HTTP 代理配置
- 提供本地脚本和 GitHub Actions 自动化工作流

## 文件说明

### 安装脚本

- **[bootstrap.ps1](bootstrap.ps1)** - Windows 平台安装脚本
  - 自动检测系统架构（x64）
  - 下载并验证 Claude Code 安装程序
  - 自动执行安装并清理临时文件

- **[bootstrap.sh](bootstrap.sh)** - Linux/macOS 平台安装脚本
  - 自动检测操作系统和架构（x64/arm64）
  - 检测 musl libc 环境
  - 支持 curl 和 wget 下载工具
  - 可选 jq 工具用于 JSON 解析

### 下载脚本

- **[download-claude.sh](download-claude.sh)** - 跨平台下载脚本
  - 支持下载 Windows 和 Linux 二进制文件
  - 支持 HTTP 代理配置
  - 自动校验和验证
  - 中文界面和详细的进度提示

### 自动化工作流

- **[.github/workflows/download-claude.yml](.github/workflows/download-claude.yml)** - GitHub Actions 工作流
  - 手动触发下载任务
  - 自动下载所有平台的二进制文件
  - 上传下载的文件为制品

## 使用方法

### Windows 平台

在 PowerShell 中运行：

```powershell
# 安装最新版本
.\bootstrap.ps1

# 安装稳定版本
.\bootstrap.ps1 stable

# 安装特定版本
.\bootstrap.ps1 1.0.0
```

### Linux/macOS 平台

在终端中运行：

```bash
# 安装最新版本
./bootstrap.sh

# 安装稳定版本
./bootstrap.sh stable

# 安装特定版本
./bootstrap.sh 1.0.0
```

### 使用下载脚本

```bash
# 下载所有平台的最新版本
./download-claude.sh

# 只下载 Linux 版本
./download-claude.sh linux

# 使用代理端口 8080 下载
./download-claude.sh both 8080

# 下载特定版本
./download-claude.sh windows '' 1.0.0
```

### GitHub Actions

1. 进入 GitHub 仓库的 Actions 页面
2. 选择 "Download claude-code binaries" 工作流
3. 点击 "Run workflow" 手动触发
4. 下载完成后在工作流运行结果中下载制品

## 系统要求

### Windows
- 64-bit Windows（不支持 32-bit）
- PowerShell

### Linux
- 64-bit x86_64 或 ARM64 架构
- curl 或 wget
- sha256sum 或 shasum（用于校验和验证）

### macOS
- 64-bit Intel 或 Apple Silicon
- curl 或 wget
- shasum（用于校验和验证）

## 代理配置

如果需要使用 HTTP 代理，可以设置环境变量或在下载脚本中指定：

```bash
# 设置环境变量
export HTTP_PROXY=http://127.0.0.1:7899
export HTTPS_PROXY=http://127.0.0.1:7899

# 或在下载脚本中指定
./download-claude.sh both 7899
```

## 下载目录

- **安装脚本**：下载到 `~/.claude/downloads/`（用户主目录）
- **下载脚本**：下载到当前目录的 `downloads/` 文件夹

## 安全说明

- 所有二进制文件都经过 SHA256 校验和验证
- 文件直接从官方 Google Cloud Storage 下载
- 下载完成后会自动验证完整性
- 校验失败会自动删除损坏的文件

## 故障排除

### 下载失败
- 检查网络连接
- 如果使用代理，确认代理配置正确
- 尝试使用不同的下载工具（curl/wget）

### 校验和验证失败
- 重新运行下载脚本
- 检查是否有足够的磁盘空间
- 确认下载过程没有被中断

### 权限问题
- Linux/macOS：确保脚本有执行权限 `chmod +x script.sh`
- Windows：可能需要以管理员身份运行 PowerShell

## 许可证

本脚本集合用于从官方源下载 Claude Code。请遵守 Claude Code 的使用条款和许可证。

## 相关链接

- [Claude Code 官方文档](https://docs.anthropic.com)
- [Claude API 文档](https://docs.anthropic.com/api)
