# OpenHouseAI Bootstrap

这是 OpenHouseAI 的在线 bootstrap 仓库，用于在 Termux/Ubuntu 环境中安装最小 Agent CLI 环境。

安装范围只包括：
- Ubuntu proot
- OpenCode
- Codex CLI
- Claude Code

## 命令

```bash
bash bootstrap.sh full
bash bootstrap.sh check
bash bootstrap.sh prepare
bash bootstrap.sh ubuntu
bash bootstrap.sh sync-docs
bash bootstrap.sh ubuntu-packages
bash bootstrap.sh entry-ubuntu
bash bootstrap.sh opencode
bash bootstrap.sh codex
bash bootstrap.sh claude-code
```

`full` 按产品顺序执行：

```text
check -> prepare -> ubuntu -> sync-docs -> ubuntu-packages -> entry-ubuntu -> opencode -> codex -> claude-code
```

## 范围

本仓库不安装上述范围之外的运行时服务或产品组件。Node.js 不作为单独可见阶段，Codex 和 Claude Code 阶段会在内部检测并按需安装。

## 维护清单

Android app 可以从下面地址加载在线维护清单：

```text
https://raw.githubusercontent.com/jiwuyou/openhouseai-bootstrap/main/openhouseai-manifest.json
```
