#!/usr/bin/env bash
set -euo pipefail

OPENCODE_INSTALL_URL="${OPENCODE_INSTALL_URL:-https://opencode.ai/install}"

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

run_ubuntu_logged() {
  if is_current_ubuntu; then
    run_logged "$@"
  else
    run_logged proot-distro login ubuntu -- "$@"
  fi
}

run_environment_probe

if ! is_current_ubuntu && { ! command -v proot-distro >/dev/null 2>&1 || ! proot-distro login ubuntu -- true >/dev/null 2>&1; }; then
  log "Ubuntu 不可用，请先运行：bash bootstrap.sh ubuntu"
  exit 2
fi

log "正在 Ubuntu 内安装或检查 OpenCode。"
run_ubuntu_logged env OPENCODE_INSTALL_URL="$OPENCODE_INSTALL_URL" bash -lc 'set -euo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if command -v opencode >/dev/null 2>&1 || test -x "$HOME/.opencode/bin/opencode"; then
  echo "OpenCode 已安装。"
else
  curl -fsSL "$OPENCODE_INSTALL_URL" | bash
fi
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if command -v opencode >/dev/null 2>&1; then
  command -v opencode
elif test -x "$HOME/.opencode/bin/opencode"; then
  echo "$HOME/.opencode/bin/opencode"
else
  echo "OpenCode 安装后仍未找到可执行文件。" >&2
  exit 4
fi'

log "正在写入 Ubuntu 内的产品路径提示。"
run_ubuntu_logged bash -lc 'set -euo pipefail
mkdir -p "$HOME/openhouseai-links" "$HOME/workspace"
printf "%s\n" "/data/data/com.termux/files/home/openhouseai-docs" > "$HOME/openhouseai-links/docs-path.txt"
printf "%s\n" "/data/data/com.termux/files/home/workspace" > "$HOME/openhouseai-links/workspace-path.txt"
PATH_LINE="export PATH=\"\$HOME/.opencode/bin:\$HOME/.local/bin:\$HOME/.npm-global/bin:\$PATH\""
for PROFILE_FILE in "$HOME/.profile" "$HOME/.bashrc"; do
  touch "$PROFILE_FILE"
  if ! grep -Fq "$PATH_LINE" "$PROFILE_FILE"; then
    {
      printf "\n# OpenHouseAI agent tools\n"
      printf "%s\n" "$PATH_LINE"
    } >> "$PROFILE_FILE"
  fi
done
echo "文档路径：$(cat "$HOME/openhouseai-links/docs-path.txt")"
echo "工作区路径：$(cat "$HOME/openhouseai-links/workspace-path.txt")"'

log "OpenCode 安装阶段完成。"
