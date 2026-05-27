#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouseAI] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
}

is_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ] && [ -d "/data/data/com.termux/files" ]
}

is_current_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release
}

detect_openhouseai_runtime() {
  if is_current_ubuntu; then
    printf 'ubuntu'
    return 0
  fi

  if [ -x "${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouseai-env-probe" ]; then
    "${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouseai-env-probe" 2>/dev/null \
      | awk -F= '$1=="OPENHOUSEAI_RUNTIME"{print $2; found=1} END{if(!found) exit 1}' \
      && return 0
  fi

  if is_termux; then
    printf 'termux'
    return 0
  fi

  printf 'unknown'
}

run_environment_probe() {
  local probe="${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouseai-env-probe"
  if [ -x "$probe" ]; then
    log "正在执行环境探测命令：$probe"
    run_logged "$probe" || true
  else
    log "环境探测命令不存在，使用内置探测逻辑。"
  fi
  log "当前运行环境：$(detect_openhouseai_runtime)"
}

run_environment_probe

if ! is_termux; then
  log "Termux 基础包阶段只能在 Termux 外层运行。当前运行环境：$(detect_openhouseai_runtime)"
  exit 2
fi

log "正在执行 pkg update -y"
run_logged pkg update -y

log "正在执行 pkg install -y proot-distro curl libcurl libngtcp2 libnghttp2 openssl ca-certificates git"
run_logged pkg install -y proot-distro curl libcurl libngtcp2 libnghttp2 openssl ca-certificates git

if ! curl --version >/dev/null 2>&1; then
  log "curl 仍不可用，尝试完整升级 Termux 依赖。"
  run_logged pkg upgrade -y
  run_logged pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates
fi

if ! curl --version >/dev/null 2>&1; then
  log "curl 修复失败，请手动执行：pkg upgrade -y && pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates"
  exit 1
fi

log "Termux 软件包阶段已完成。"
