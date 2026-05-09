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
    -e CLAUDE_SKIP_AUTOUPDATER=1 \
    -e HOME=/workspace \
    -e TZ="Europe/Berlin" \
    -v "$WORKSPACE_DIR":/workspace \
    -v "$GITCONFIG":/workspace/.gitconfig:ro \
    -v "$CLAUDE_DIR":/workspace/.claude \
    -v "$CODEX_DIR":/workspace/.codex \
    -v "$AGENTS_DIR":/workspace/.agents \
    -v "$COPILOT_DIR":/workspace/.copilot \
    -v "$CURSOR_DIR":/workspace/.cursor \
    -w /workspace \
    --name="$CONTAINER_NAME" \
    agent-sandbox \
    bash
