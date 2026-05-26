# OpenHouseAI Bootstrap

Minimal Termux/Ubuntu bootstrap installer for OpenCode, Codex, and Claude Code.

## Commands

```bash
bash bootstrap.sh full
bash bootstrap.sh check
bash bootstrap.sh prepare
bash bootstrap.sh ubuntu
bash bootstrap.sh ubuntu-packages
bash bootstrap.sh opencode
bash bootstrap.sh codex
bash bootstrap.sh claude-code
```

`full` runs every stage in product order:

```text
check -> prepare -> ubuntu -> ubuntu-packages -> opencode -> codex -> claude-code
```

## Scope

This repository intentionally does not install OpenHouse runtime components,
SmallPhone, service-manager, cc-connect, cc-proxy, guide sites, or docs sites.

