#!/bin/bash
set -euo pipefail

CONTAINER_NAME=agent-sandbox
WORKSPACE_DIR="${1:-$(pwd)}"

GITCONFIG="$HOME/.gitconfig"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
AGENTS_DIR="$HOME/.agents"
COPILOT_DIR="$HOME/.copilot"
CURSOR_DIR="$HOME/.cursor"

[ -f "$GITCONFIG" ] || { echo "Datei $GITCONFIG nicht vorhanden"; exit 1; }
mkdir -p "$CLAUDE_DIR" "$CODEX_DIR" "$AGENTS_DIR" "$COPILOT_DIR" "$CURSOR_DIR"

docker run -it \
    --rm \
    --entrypoint "" \
    --user "$(id -u):$(id -g)" \
    -e CLAUDE_SKIP_AUTOUPDATER=1 \
    -e GIT_CONFIG_GLOBAL=/tmp/host.gitconfig \
    -e HOME=/workspace \
    -e LOGNAME="$(id -un)" \
    -e NPM_CONFIG_CACHE=/tmp/npm-cache \
    -e NPM_CONFIG_LOGS_DIR=/tmp/npm-logs \
    -e TZ="Europe/Berlin" \
    -e USER="$(id -un)" \
    -v "$WORKSPACE_DIR":/workspace \
    -v "$GITCONFIG":/tmp/host.gitconfig:ro \
    -v "$CLAUDE_DIR":/workspace/.claude \
    -v "$CODEX_DIR":/workspace/.codex \
    -v "$AGENTS_DIR":/workspace/.agents \
    -v "$COPILOT_DIR":/workspace/.copilot \
    -v "$CURSOR_DIR":/workspace/.cursor \
    -w /workspace \
    --name="$CONTAINER_NAME" \
    agent-sandbox \
    bash
