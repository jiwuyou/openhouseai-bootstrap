#!/usr/bin/env bash
set -euo pipefail

OPENHOUSEAI_DIR="${OPENHOUSEAI_DIR:-$HOME/.openhouseai-bootstrap}"
OPENHOUSEAI_RAW_BASE="${OPENHOUSEAI_RAW_BASE:-https://raw.githubusercontent.com/jiwuyou/openhouseai-bootstrap/main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[OpenHouseAI] %s\n' "$*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

run_logged() {
  log "+ $*"
  "$@"
}

download_file() {
  local url="$1"
  local output="$2"
  local attempt
  for attempt in 1 2 3 4 5; do
    log "下载：$url（第 $attempt 次）"
    if curl -fL --connect-timeout 20 --retry 3 --retry-delay 2 --retry-all-errors "$url" -o "$output"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

is_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ] && [ -d "/data/data/com.termux/files" ]
}

is_current_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release
}

ensure_supported_runtime() {
  is_termux || is_current_ubuntu || die "请在官方 Termux 内运行；Codex、Claude Code 等 agent 安装也可以在 Ubuntu 内运行。"
}

ensure_termux_curl() {
  if ! is_termux; then
    command -v curl >/dev/null 2>&1 && curl --version >/dev/null 2>&1 && return 0
    die "curl 不可用，且当前不是 Termux，无法自动修复。"
  fi

  command -v pkg >/dev/null 2>&1 || die "curl 不可用，且缺少 pkg，无法自动修复。"

  log "正在更新 Termux 包索引并修复 curl 网络依赖。"
  run_logged pkg update -y || true
  run_logged pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates || true

  curl --version >/dev/null 2>&1 || die "curl 修复失败，请先执行：pkg upgrade -y && pkg install -y curl libcurl libngtcp2 openssl ca-certificates"
}

ensure_local_layout() {
  mkdir -p "$OPENHOUSEAI_DIR/scripts"

  if [ -d "$SCRIPT_DIR/scripts" ]; then
    return 0
  fi

  ensure_termux_curl

  log "正在从 $OPENHOUSEAI_RAW_BASE 下载阶段脚本"
  for name in \
    00-check-termux.sh \
    10-prepare-termux.sh \
    20-install-ubuntu.sh \
    30-update-ubuntu-packages.sh \
    40-install-opencode.sh \
    42-install-codex.sh \
    44-install-claude-code.sh; do
    download_file "$OPENHOUSEAI_RAW_BASE/scripts/$name" "$OPENHOUSEAI_DIR/scripts/$name"
    chmod +x "$OPENHOUSEAI_DIR/scripts/$name"
  done
}

script_path() {
  local name="$1"
  if [ -f "$SCRIPT_DIR/scripts/$name" ]; then
    printf '%s/scripts/%s\n' "$SCRIPT_DIR" "$name"
  else
    printf '%s/scripts/%s\n' "$OPENHOUSEAI_DIR" "$name"
  fi
}

root_path() {
  if [ -d "$SCRIPT_DIR/scripts" ]; then
    printf '%s\n' "$SCRIPT_DIR"
  else
    printf '%s\n' "$OPENHOUSEAI_DIR"
  fi
}

run_stage() {
  local name="$1"
  local path
  local root
  path="$(script_path "$name")"
  root="$(root_path)"
  [ -f "$path" ] || die "缺少阶段脚本：$path"
  chmod +x "$path"
  log "开始：$name"
  OPENHOUSEAI_ROOT="$root" bash "$path"
  log "完成：$name"
}

run_full_install() {
  run_stage 00-check-termux.sh
  run_stage 10-prepare-termux.sh
  run_stage 20-install-ubuntu.sh
  run_stage 30-update-ubuntu-packages.sh
  run_stage 40-install-opencode.sh
  run_stage 42-install-codex.sh
  run_stage 44-install-claude-code.sh
}

show_menu() {
  cat <<EOF
OpenHouseAI Installer

1. 完整安装 OpenCode、Codex、Claude Code
2. 只检查 Termux 环境
3. 只准备 Termux 路径和基础包
4. 只安装 Ubuntu
5. 只更新 Ubuntu 软件包
6. 只安装 OpenCode
7. 只安装 Codex
8. 只安装 Claude Code
9. 退出
EOF
}

main() {
  ensure_supported_runtime
  ensure_local_layout

  case "${1:-}" in
    full)
      run_full_install
      return
      ;;
    check)
      run_stage 00-check-termux.sh
      return
      ;;
    prepare)
      run_stage 10-prepare-termux.sh
      return
      ;;
    ubuntu)
      run_stage 20-install-ubuntu.sh
      return
      ;;
    ubuntu-packages)
      run_stage 30-update-ubuntu-packages.sh
      return
      ;;
    opencode)
      run_stage 40-install-opencode.sh
      return
      ;;
    codex)
      run_stage 42-install-codex.sh
      return
      ;;
    claude-code)
      run_stage 44-install-claude-code.sh
      return
      ;;
    ""|menu)
      ;;
    *)
      die "未知命令：$1"
      ;;
  esac

  while true; do
    show_menu
    printf '请选择 [1-9]: '
    read -r choice
    case "$choice" in
      1) run_full_install ;;
      2) run_stage 00-check-termux.sh ;;
      3) run_stage 10-prepare-termux.sh ;;
      4) run_stage 20-install-ubuntu.sh ;;
      5) run_stage 30-update-ubuntu-packages.sh ;;
      6) run_stage 40-install-opencode.sh ;;
      7) run_stage 42-install-codex.sh ;;
      8) run_stage 44-install-claude-code.sh ;;
      9) exit 0 ;;
      *) log "请输入 1 到 9。" ;;
    esac
  done
}

main "$@"
