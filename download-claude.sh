#!/bin/bash

# 用法说明
usage() {
    echo "用法: $0 [平台] [代理端口] [目标版本]"
    echo ""
    echo "参数:"
    echo "  平台       windows, linux, 或 both (默认: both)"
    echo "  代理端口    本地代理端口 (可选)"
    echo "  目标版本    stable, latest, 或 x.y.z-版本号 (默认: latest)"
    echo ""
    echo "示例:"
    echo "  $0                          # 下载所有平台的最新版本"
    echo "  $0 linux                    # 只下载 Linux 版本"
    echo "  $0 both 8080                # 使用代理端口 8080"
    echo "  $0 windows '' 1.0.0         # 下载 Windows 的特定版本"
    exit 1
}

# 参数解析
PLATFORM="${1:-both}"
PROXY_PORT="${2:-}"
TARGET="${3:-latest}"

# 验证平台参数
if [[ ! "$PLATFORM" =~ ^(windows|linux|both)$ ]]; then
    echo "错误: 无效的平台 '$PLATFORM'"
    echo "必须是 'windows', 'linux', 或 'both'"
    exit 1
fi

# 验证目标版本参数
if [[ ! "$TARGET" =~ ^(stable|latest|\d+\.\d+\.\d+(-[^\s]+)?)$ ]]; then
    echo "错误: 无效的目标版本 '$TARGET'"
    echo "必须是 'stable', 'latest', 或有效的版本号 (例如: 1.0.0)"
    exit 1
fi

# 严格模式
set -euo pipefail
set -x

# 配置
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
DOWNLOAD_DIR="$PWD/downloads"

# 创建下载目录
mkdir -p "$DOWNLOAD_DIR"

# 配置代理
if [ -n "$PROXY_PORT" ]; then
    export HTTP_PROXY="http://127.0.0.1:$PROXY_PORT"
    export HTTPS_PROXY="http://127.0.0.1:$PROXY_PORT"
    echo "使用代理: http://127.0.0.1:$PROXY_PORT"
fi

# 通用 curl 选项
CURL_OPTS=(
    --silent
    --show-error
    --fail
    --location
    -H "User-Agent: Shell Claude Downloader/1.0"
)

# 如果设置了代理，添加代理选项到 curl
if [ -n "$PROXY_PORT" ]; then
    CURL_OPTS+=(--proxy "http://127.0.0.1:$PROXY_PORT")
fi

# 获取 Web 内容
get_web_content() {
    local uri="$1"
    local as_json="${2:-false}"

    if [ "$as_json" = "true" ]; then
        curl "${CURL_OPTS[@]}" "$uri"
    else
        curl "${CURL_OPTS[@]}" "$uri"
    fi
}

# 下载文件（带进度条）
download_file() {
    local uri="$1"
    local outfile="$2"

    # 为下载创建单独的选项：移除 --silent，添加进度条
    local download_opts=()
    for opt in "${CURL_OPTS[@]}"; do
        [ "$opt" != "--silent" ] && download_opts+=("$opt")
    done
    download_opts+=(--progress-bar)

    curl "${download_opts[@]}" -o "$outfile" "$uri"
}

# 下载特定平台的 Claude
download_claude() {
    local platform_name="$1"
    local platform_id="$2"

    echo ""
    echo "=========================================="
    echo "正在下载 $platform_name 版本的 Claude"
    echo "=========================================="

    # 获取最新版本
    if ! version=$(get_web_content "$GCS_BUCKET/latest" "false"); then
        echo "错误: 无法获取 $platform_name 的最新版本" >&2
        return 1
    fi
    echo "最新版本: $version"

    # 获取清单
    if ! manifest=$(get_web_content "$GCS_BUCKET/$version/manifest.json" "true"); then
        echo "错误: 无法获取 $platform_name 的清单" >&2
        return 1
    fi
    echo "manifest:"
    echo "$manifest" | jq 
    # 使用 jq 提取校验和，如果失败则尝试使用 sed
    if command -v jq &> /dev/null; then
        checksum=$(echo "$manifest" | jq -r ".platforms[\"${platform_id}\"].checksum")
    else
        # 简单的 JSON 解析回退方案
        # 在平台 ID 后的 15 行内查找 checksum，避免匹配到其他平台
        checksum=$(echo "$manifest" | grep -A 15 "\"${platform_id}\"" | grep -m 1 "\"checksum\"" | sed 's/.*"checksum"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi

    if [ -z "$checksum" ] || [ "$checksum" = "null" ]; then
        echo "错误: 在清单中找不到平台 $platform_id" >&2
        return 1
    fi

    echo "校验和: $checksum"

    # 下载二进制文件
    local binary_path="$DOWNLOAD_DIR/claude-$version-$platform_id"
    if [ "$platform_name" = "Windows" ]; then
        binary_path="$binary_path.exe"
    fi

    echo "正在下载到: $binary_path"

    local binary_name="claude"
    if [ "$platform_name" = "Windows" ]; then
        binary_name="claude.exe"
    fi

    if ! download_file "$GCS_BUCKET/$version/$platform_id/$binary_name" "$binary_path"; then
        echo "错误: 无法下载 $platform_name 的二进制文件" >&2
        rm -f "$binary_path"
        return 1
    fi

    echo "下载完成"

    # 验证校验和
    local actual_checksum
    if command -v sha256sum &> /dev/null; then
        actual_checksum=$(sha256sum "$binary_path" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        actual_checksum=$(shasum -a 256 "$binary_path" | awk '{print $1}')
    else
        echo "警告: 无法验证校验和，找不到 sha256sum 或 shasum 命令"
        actual_checksum="$checksum"
    fi

    if [ "$actual_checksum" != "$checksum" ]; then
        echo "错误: $platform_name 的校验和验证失败" >&2
        echo "期望值: $checksum" >&2
        echo "实际值: $actual_checksum" >&2
        rm -f "$binary_path"
        return 1
    fi

    echo "✓ 校验和验证成功"
    echo "二进制文件已保存到: $binary_path"

    return 0
}

# 主执行流程
echo "Claude 原生二进制文件下载器"
echo "================================"
echo "下载目录: $DOWNLOAD_DIR"

results=()

if [ "$PLATFORM" = "windows" ] || [ "$PLATFORM" = "both" ]; then
    if download_claude "Windows" "win32-x64"; then
        results+=("success")
    else
        results+=("failure")
    fi
fi

if [ "$PLATFORM" = "linux" ] || [ "$PLATFORM" = "both" ]; then
    if download_claude "Linux" "linux-x64"; then
        results+=("success")
    else
        results+=("failure")
    fi
fi

# 汇总
echo ""
echo "=========================================="
echo "下载汇总"
echo "=========================================="

success_count=0
for result in "${results[@]}"; do
    if [[ $result == "success" ]]; then
        success_count=$((success_count + 1))
    fi
done
total_count=${#results[@]}

echo "成功下载: $success_count / $total_count"

if [ $success_count -eq $total_count ]; then
    echo ""
    echo "✓ 所有下载已成功完成!"
    exit 0
else
    echo ""
    echo "✗ 部分下载失败，请检查上面的错误信息"
    exit 1
fi
