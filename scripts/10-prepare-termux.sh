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
  log "Termux 准备阶段只能在 Termux 外层运行。当前运行环境：$(detect_openhouseai_runtime)"
  exit 2
fi

TERMUX_HOME="${HOME:-/data/data/com.termux/files/home}"
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TERMUX_BIN_DIR="$TERMUX_PREFIX/bin"
ENV_PROBE_COMMAND="$TERMUX_BIN_DIR/openhouseai-env-probe"
DOC_DIR="$TERMUX_HOME/openhouseai-docs"
WORKSPACE_DIR="$TERMUX_HOME/workspace"
TERMUX_CONFIG_DIR="$TERMUX_HOME/.termux"
TERMUX_PROPERTIES_FILE="$TERMUX_CONFIG_DIR/termux.properties"

install_env_probe_cli() {
  if [ -x "$ENV_PROBE_COMMAND" ]; then
    log "环境探测 CLI 已存在：$ENV_PROBE_COMMAND"
    return 0
  fi

  mkdir -p "$TERMUX_BIN_DIR"
  cat > "$ENV_PROBE_COMMAND" <<'EOF'
#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

INSTALL_SIDE="termux"

detect_runtime() {
  if [ -r /etc/os-release ] && grep -qi 'ubuntu' /etc/os-release; then
    printf 'ubuntu'
    return 0
  fi

  if [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = "/data/data/com.termux/files/usr" ]; then
    printf 'termux'
    return 0
  fi

  printf 'unknown'
}

detect_ubuntu_rootfs() {
  case "$(detect_runtime)" in
    ubuntu)
      printf 'installed'
      ;;
    termux)
      if command -v proot-distro >/dev/null 2>&1 && proot-distro login ubuntu -- true >/dev/null 2>&1; then
        printf 'installed'
      else
        printf 'missing'
      fi
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

main() {
  printf 'OPENHOUSEAI_INSTALL_SIDE=%s\n' "$INSTALL_SIDE"
  printf 'OPENHOUSEAI_RUNTIME=%s\n' "$(detect_runtime)"
  printf 'OPENHOUSEAI_UBUNTU_ROOTFS=%s\n' "$(detect_ubuntu_rootfs)"
}

main "$@"
EOF
  chmod 755 "$ENV_PROBE_COMMAND"
  log "已注入环境探测 CLI：$ENV_PROBE_COMMAND"
}

log "正在确保基础目录存在。"
mkdir -p "$DOC_DIR" "$WORKSPACE_DIR" "$TERMUX_CONFIG_DIR"
chmod 700 "$DOC_DIR" "$WORKSPACE_DIR" "$TERMUX_CONFIG_DIR" || true

log "正在启用 allow-external-apps。"
touch "$TERMUX_PROPERTIES_FILE"
if grep -q '^[[:space:]]*allow-external-apps' "$TERMUX_PROPERTIES_FILE"; then
  sed -i 's/^[[:space:]]*allow-external-apps[[:space:]]*=.*/allow-external-apps = true/' "$TERMUX_PROPERTIES_FILE"
else
  printf '\nallow-external-apps = true\n' >> "$TERMUX_PROPERTIES_FILE"
fi

log "正在安装 Termux 基础包。"
run_logged pkg update -y
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

cat > "$DOC_DIR/README.md" <<'EOF'
# OpenHouseAI Docs

This directory is visible to OpenCode. Put stable product notes here.
EOF

cat > "$DOC_DIR/USER_GUIDE.md" <<'EOF'
# User Guide

1. Open the browser page served by OpenCode.
2. Ask the agent to read AI_GUIDE.md before starting work.
3. Keep your projects under ~/workspace.
EOF

cat > "$DOC_DIR/AI_GUIDE.md" <<'EOF'
# AI Guide

You are operating inside a local Termux + Ubuntu proot workspace.

Rules:
- Read README.md and this AI_GUIDE.md before making changes.
- Treat ~/workspace as the writable area for user projects.
- Keep generated artifacts organized and explain what was changed.
- Do not write provider API keys into tracked files or shared docs.
EOF

install_env_probe_cli

log "文档路径：$DOC_DIR"
log "工作区路径：$WORKSPACE_DIR"
log "Termux 配置：$TERMUX_PROPERTIES_FILE"
log "Termux 准备阶段完成。"
