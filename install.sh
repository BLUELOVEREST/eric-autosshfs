#!/usr/bin/env bash

set -euo pipefail

APP_NAME="autosshfs"
OFFICIAL_REPO_BASE_URL="https://raw.githubusercontent.com/BLUELOVEREST/eric-autosshfs/main"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/$APP_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
INSTALL_DEPS=0
ACTION="install"
REPO_BASE_URL="${AUTOSSHFS_REPO_BASE_URL:-$OFFICIAL_REPO_BASE_URL}"
AUTH_HEADER="${AUTOSSHFS_AUTH_HEADER:-}"
BINARY_SOURCE=""
CONFIG_SOURCE=""

usage() {
    cat <<EOF
用法: ./install.sh [install|update|check|help] [--install-deps] [--prefix PATH] [--repo-base URL]

命令:
  install         安装 autosshfs
  update          更新 autosshfs
  check           检查依赖和安装状态
  help            显示帮助

选项:
  --install-deps  尝试安装系统依赖
  --prefix PATH   指定安装前缀，默认: $HOME/.local
  --repo-base URL 指定远程 raw 基础地址，默认官方 GitHub 仓库
  --auth-header H 指定下载时附带的 HTTP Header，适用于私有仓库
EOF
}

log() {
    printf '[install] %s\n' "$*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

curl_fetch() {
    local url="$1"

    if ! command_exists curl; then
        log "未找到 curl，无法下载远程安装文件"
        exit 1
    fi

    if [ -n "$AUTH_HEADER" ]; then
        curl -fsSL -H "$AUTH_HEADER" "$url"
    else
        curl -fsSL "$url"
    fi
}

resolve_sources() {
    local local_bin="$SCRIPT_DIR/bin/$APP_NAME"
    local local_config="$SCRIPT_DIR/share/$APP_NAME/config.sh.example"

    if [ -f "$local_bin" ] && [ -f "$local_config" ]; then
        BINARY_SOURCE="$local_bin"
        CONFIG_SOURCE="$local_config"
        return 0
    fi

    REPO_BASE_URL="${REPO_BASE_URL%/}"
    BINARY_SOURCE="${REPO_BASE_URL}/bin/${APP_NAME}"
    CONFIG_SOURCE="${REPO_BASE_URL}/share/${APP_NAME}/config.sh.example"
}

install_deps_macos() {
    command_exists brew || {
        log "未找到 brew，请先安装 Homebrew"
        exit 1
    }

    log "安装 macFUSE"
    brew install --cask macfuse

    if ! brew list --formula 2>/dev/null | grep -qx 'sshfs-mac'; then
        log "安装 sshfs-mac"
        brew install gromgit/fuse/sshfs-mac
    else
        log "sshfs-mac 已安装"
    fi
}

install_deps_linux() {
    command_exists apt-get || {
        log "未找到 apt-get，请手动安装 sshfs"
        exit 1
    }

    log "安装 sshfs"
    sudo apt-get update
    sudo apt-get install -y sshfs
}

install_files() {
    mkdir -p "$BIN_DIR" "$SHARE_DIR"

    if [ -f "$BINARY_SOURCE" ]; then
        sed "s|__INSTALL_PREFIX__|$PREFIX|g" "$BINARY_SOURCE" >"$BIN_DIR/$APP_NAME"
    else
        curl_fetch "$BINARY_SOURCE" | sed "s|__INSTALL_PREFIX__|$PREFIX|g" >"$BIN_DIR/$APP_NAME"
    fi
    chmod +x "$BIN_DIR/$APP_NAME"

    if [ -f "$CONFIG_SOURCE" ]; then
        cp "$CONFIG_SOURCE" "$SHARE_DIR/config.sh.example"
    else
        curl_fetch "$CONFIG_SOURCE" >"$SHARE_DIR/config.sh.example"
    fi

    log "已安装到 $BIN_DIR/$APP_NAME"
}

print_next_steps() {
    cat <<EOF

后续步骤:
1. 确认 $BIN_DIR 已在 PATH 中
2. 执行: $APP_NAME init-config
3. 编辑: ~/.config/$APP_NAME/config.sh
4. 执行: $APP_NAME mount-all

EOF
}

print_check() {
    printf '[check] %s\n' "$*"
}

check_deps_macos() {
    local failed=0

    if command_exists brew; then
        print_check "Homebrew: ok"
    else
        print_check "Homebrew: missing"
        failed=1
    fi

    if command_exists sshfs; then
        print_check "sshfs: ok"
    else
        print_check "sshfs: missing"
        failed=1
    fi

    if [ -e /Library/Filesystems/macfuse.fs ] || [ -e /Library/Extensions/macfuse.kext ]; then
        print_check "macFUSE: detected"
    else
        print_check "macFUSE: missing"
        failed=1
    fi

    return "$failed"
}

check_deps_linux() {
    local failed=0

    if command_exists apt-get; then
        print_check "apt-get: ok"
    else
        print_check "apt-get: missing"
        failed=1
    fi

    if command_exists sshfs; then
        print_check "sshfs: ok"
    else
        print_check "sshfs: missing"
        failed=1
    fi

    if command_exists fusermount || command_exists fusermount3; then
        print_check "fusermount: ok"
    else
        print_check "fusermount: missing"
        failed=1
    fi

    return "$failed"
}

check_installation() {
    local failed=0

    case "$OS" in
        Darwin) check_deps_macos || failed=1 ;;
        Linux) check_deps_linux || failed=1 ;;
        *)
            print_check "unsupported OS: $OS"
            failed=1
            ;;
    esac

    if [ -x "$BIN_DIR/$APP_NAME" ]; then
        print_check "binary: $BIN_DIR/$APP_NAME"
    else
        print_check "binary missing: $BIN_DIR/$APP_NAME"
        failed=1
    fi

    if [ -f "$SHARE_DIR/config.sh.example" ]; then
        print_check "config example: $SHARE_DIR/config.sh.example"
    else
        print_check "config example missing: $SHARE_DIR/config.sh.example"
        failed=1
    fi

    return "$failed"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            install|update|check|help)
                ACTION="$1"
                ;;
            --install-deps)
                INSTALL_DEPS=1
                ;;
            --prefix)
                shift
                [ $# -gt 0 ] || {
                    log "--prefix 需要路径参数"
                    exit 1
                }
                PREFIX="$1"
                BIN_DIR="$PREFIX/bin"
                SHARE_DIR="$PREFIX/share/$APP_NAME"
                ;;
            --repo-base)
                shift
                [ $# -gt 0 ] || {
                    log "--repo-base 需要 URL 参数"
                    exit 1
                }
                REPO_BASE_URL="$1"
                ;;
            --auth-header)
                shift
                [ $# -gt 0 ] || {
                    log "--auth-header 需要 Header 参数"
                    exit 1
                }
                AUTH_HEADER="$1"
                ;;
            -h|--help)
                ACTION="help"
                ;;
            *)
                log "未知参数: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

run_install_or_update() {
    resolve_sources

    if [ "$INSTALL_DEPS" -eq 1 ]; then
        case "$OS" in
            Darwin) install_deps_macos ;;
            Linux) install_deps_linux ;;
            *)
                log "不支持的系统: $OS"
                exit 1
                ;;
        esac
    else
        log "默认只安装脚本文件，不自动安装系统依赖"
    fi

    install_files
    print_next_steps
}

main() {
    parse_args "$@"

    case "$ACTION" in
        install|update)
            run_install_or_update
            ;;
        check)
            check_installation
            ;;
        help)
            usage
            ;;
        *)
            log "未知操作: $ACTION"
            usage
            exit 1
            ;;
    esac
}

main "$@"
