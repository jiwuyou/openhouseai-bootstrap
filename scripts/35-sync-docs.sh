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

TERMUX_HOME="${HOME:-/data/data/com.termux/files/home}"
if is_current_ubuntu; then
  TERMUX_HOME="/data/data/com.termux/files/home"
fi

DOC_ROOT="$TERMUX_HOME/openhouseai-docs"
OFFICIAL_DOC_DIR="$DOC_ROOT/official"
AGENT_NOTES_DIR="$DOC_ROOT/agent-notes"

log "正在同步 OpenHouseAI 文档到 $OFFICIAL_DOC_DIR"
mkdir -p "$OFFICIAL_DOC_DIR" "$AGENT_NOTES_DIR"

cat > "$OFFICIAL_DOC_DIR/START_HERE.md" <<'EOF'
# 从这里开始

OpenHouseAI 文档分为两部分：

1. `ENVIRONMENT.md`：说明当前 Android、Termux、Ubuntu、路径和安装范围。
2. `MODEL_API_SETUP.md`：说明 Codex 和 Claude Code 如何登录，或如何配置大模型 API。

建议顺序：
- 先读 `ENVIRONMENT.md`，确认当前运行在哪里。
- 如果要使用 Codex 或 Claude Code，再读 `MODEL_API_SETUP.md`。
EOF

cat > "$OFFICIAL_DOC_DIR/ENVIRONMENT.md" <<'EOF'
# 运行环境说明

OpenHouseAI 运行在 Android 手机上，结构如下：

- Android 是宿主系统。
- Termux 提供终端环境和包管理。
- Ubuntu 通过 `proot-distro` 安装在 Termux 内。
- OpenCode、Codex CLI、Claude Code 安装在 Ubuntu 内。

## 安装范围

OpenHouseAI 只负责安装和检测：

- Ubuntu proot
- OpenCode
- Codex CLI
- Claude Code

Node.js 不作为单独可见阶段。Codex 和 Claude Code 安装阶段会在内部检测并按需安装 Node.js。

## 阶段顺序

维护中心的一键阶段顺序是：

1. 准备 Termux 路径、配置和文档。
2. 安装 Termux 基础包。
3. 测速并选择 Ubuntu rootfs 镜像源，然后安装 Ubuntu rootfs。
4. 同步 OpenHouseAI 文档。
5. 安装 Ubuntu 基础包。
6. 设置打开 Termux 后默认进入 Ubuntu。
7. 安装 OpenCode。
8. 安装 Codex CLI。
9. 安装 Claude Code。

默认进入 Ubuntu 必须在安装 OpenCode、Codex CLI 和 Claude Code 之前完成。

Ubuntu rootfs 安装不会使用代理。安装脚本会先测试内置的 Ubuntu cloud image 镜像源，选择当前可达且较快的 rootfs URL，再执行 `proot-distro install -n ubuntu <rootfs-url>`。如需指定源，可在执行前设置 `OPENHOUSEAI_UBUNTU_ROOTFS_URL`。

## 路径

- Termux 主目录：`/data/data/com.termux/files/home`
- 工作区：`/data/data/com.termux/files/home/workspace`
- 官方文档：`/data/data/com.termux/files/home/openhouseai-docs/official`
- Agent 笔记：`/data/data/com.termux/files/home/openhouseai-docs/agent-notes`
- 启动入口配置：`/data/data/com.termux/files/home/.openhouseai`

Ubuntu 中如果存在以下短路径，优先使用短路径：

- `~/openhouseai-docs/official`
- `~/openhouseai-docs/agent-notes`
- `~/openhouseai-links/docs-path.txt`
- `~/openhouseai-links/workspace-path.txt`

## 环境检测

每个安装阶段都会先检测当前终端环境。

预期探测命令：

- Termux：`openhouseai-env-probe`
- Ubuntu：`~/bin/openhouseai-env-probe`
EOF

cat > "$OFFICIAL_DOC_DIR/MODEL_API_SETUP.md" <<'EOF'
# Codex 和 Claude Code 登录/API 配置

本文件说明安装完成后，如何让 Codex CLI 和 Claude Code 连接大模型服务。

不要把 API key 写入 git 仓库、共享文档、APK 资源、日志或截图。优先使用工具自带登录流程，或只在本机 shell 配置环境变量。

## Codex CLI

Codex CLI 通常有两种使用方式：

1. 使用官方登录流程。
2. 使用 OpenAI API key。

### 官方登录

在 Ubuntu 终端中运行：

```bash
codex login
```

按终端提示完成浏览器登录或设备授权。登录完成后，再运行：

```bash
codex --version
codex
```

### 使用 OpenAI API key

如果你使用 API key，可以在 Ubuntu 的 shell 配置中设置：

```bash
export OPENAI_API_KEY="你的 OpenAI API key"
```

如果需要长期保存，只写入本机的 `~/.bashrc` 或 `~/.profile`，不要写入项目仓库。

如果使用 OpenAI 兼容网关，先查看 Codex CLI 当前版本文档或 `codex --help`，确认支持的 base URL 环境变量后再配置。

## Claude Code

Claude Code 通常有两种使用方式：

1. 使用官方登录流程。
2. 使用 Anthropic API key。

### 官方登录

在 Ubuntu 终端中运行：

```bash
claude login
```

按终端提示完成登录。登录完成后检查：

```bash
claude --version
claude
```

### 使用 Anthropic API key

如果你使用 API key，可以在 Ubuntu 的 shell 配置中设置：

```bash
export ANTHROPIC_API_KEY="你的 Anthropic API key"
```

如果需要长期保存，只写入本机的 `~/.bashrc` 或 `~/.profile`。

### 一键配置 Claude Code 使用 DeepSeek

如果要让 Claude Code 使用 DeepSeek 的 Anthropic 兼容接口，可以在 Ubuntu 终端中创建一个本机配置工具：

```bash
mkdir -p "$HOME/bin"
cat > "$HOME/bin/openhouseai-configure-claude-deepseek" <<'CONFIG_TOOL'
#!/usr/bin/env bash
set -euo pipefail

read -r -p "请输入 DeepSeek API Key: " deepseek_key
if [ -z "$deepseek_key" ]; then
  echo "API Key 不能为空。" >&2
  exit 1
fi

config_file="$HOME/.bashrc"
start_marker="# >>> OpenHouseAI Claude Code DeepSeek >>>"
end_marker="# <<< OpenHouseAI Claude Code DeepSeek <<<"
tmp_file="$(mktemp)"

awk -v start="$start_marker" -v end="$end_marker" '
  $0 == start { skip=1; next }
  $0 == end { skip=0; next }
  skip != 1 { print }
' "$config_file" 2>/dev/null > "$tmp_file" || true

cat >> "$tmp_file" <<CONFIG
$start_marker
export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
export ANTHROPIC_AUTH_TOKEN=$deepseek_key
export ANTHROPIC_MODEL=deepseek-v4-pro
export ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro
export ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro
export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
export CLAUDE_CODE_EFFORT_LEVEL=max
$end_marker
CONFIG

mv "$tmp_file" "$config_file"
chmod 600 "$config_file"
echo "Claude Code DeepSeek 配置已写入 $config_file。请执行：source ~/.bashrc"
CONFIG_TOOL
chmod +x "$HOME/bin/openhouseai-configure-claude-deepseek"
```

之后运行：

```bash
openhouseai-configure-claude-deepseek
source ~/.bashrc
claude
```

## OpenCode 使用 DeepSeek

DeepSeek API Key 获取地址：

```text
https://platform.deepseek.com/api_keys
```

在 OpenCode 网页启动后：

1. 在 OpenCode 输入框执行 `/connect`。
2. 选择 `DeepSeek`。
3. 粘贴 DeepSeek API Key。
4. 再执行 `/models`，选择要使用的 DeepSeek 模型。

如果还没有 API Key，先打开 DeepSeek 控制台，登录后创建 API Key。不要把 API Key 粘贴到聊天内容、日志、截图或仓库中。

## 配置检查

重新打开 Termux 后会默认进入 Ubuntu。进入后检查：

```bash
command -v codex
command -v claude
codex --version
claude --version
```

检查环境变量是否存在：

```bash
printenv OPENAI_API_KEY
printenv ANTHROPIC_API_KEY
```
EOF

cat > "$OFFICIAL_DOC_DIR/README.md" <<'EOF'
# OpenHouseAI 文档

本目录只保留两类说明：

1. 运行环境说明：见 `ENVIRONMENT.md`。
2. Codex 和 Claude Code 的登录/API 配置：见 `MODEL_API_SETUP.md`。
EOF

run_ubuntu_logged bash -lc 'set -euo pipefail; mkdir -p "$HOME/openhouseai-docs"; ln -sfn /data/data/com.termux/files/home/openhouseai-docs/official "$HOME/openhouseai-docs/official"; ln -sfn /data/data/com.termux/files/home/openhouseai-docs/agent-notes "$HOME/openhouseai-docs/agent-notes"; printf "%s\n" "$HOME/openhouseai-docs/official"'

log "OpenHouseAI 文档同步阶段完成。"
