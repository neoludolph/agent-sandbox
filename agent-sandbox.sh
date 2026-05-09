#!/bin/bash
set -euo pipefail

CONTAINER_NAME=agent-sandbox
WORKSPACE_DIR="${1:-$(pwd)}"
HOST_AGENT_HOME="$HOME/.agent-sandbox/home"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
HOST_USER="$(id -un)"
HOST_GROUP="$(id -gn)"
AGENT_HOME="/home/$HOST_USER"

GITCONFIG="$HOME/.gitconfig"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
AGENTS_DIR="$HOME/.agents"
COPILOT_DIR="$HOME/.copilot"
CURSOR_DIR="$HOME/.cursor"

[ -f "$GITCONFIG" ] || { echo "Datei $GITCONFIG nicht vorhanden"; exit 1; }
mkdir -p "$HOST_AGENT_HOME" "$CLAUDE_DIR" "$CODEX_DIR" "$AGENTS_DIR" "$COPILOT_DIR" "$CURSOR_DIR"

PASSWD_FILE="$(mktemp)"
GROUP_FILE="$(mktemp)"
cleanup() {
    rm -f "$PASSWD_FILE" "$GROUP_FILE"
}
trap cleanup EXIT

printf '%s\n' \
    'root:x:0:0:root:/root:/bin/bash' \
    "${HOST_USER}:x:${HOST_UID}:${HOST_GID}:${HOST_USER}:${AGENT_HOME}:/bin/bash" \
    'nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin' \
    > "$PASSWD_FILE"
printf '%s\n' \
    'root:x:0:' \
    "${HOST_GROUP}:x:${HOST_GID}:${HOST_USER}" \
    'nogroup:x:65534:' \
    > "$GROUP_FILE"

docker run -it \
    --rm \
    --entrypoint "" \
    --user "$HOST_UID:$HOST_GID" \
    -e CLAUDE_SKIP_AUTOUPDATER=1 \
    -e GIT_CONFIG_GLOBAL=/tmp/host.gitconfig \
    -e HISTFILE="$AGENT_HOME/.bash_history" \
    -e HOME="$AGENT_HOME" \
    -e LOGNAME="$HOST_USER" \
    -e NPM_CONFIG_CACHE=/tmp/npm-cache \
    -e NPM_CONFIG_LOGS_DIR=/tmp/npm-logs \
    -e NPM_CONFIG_PREFIX="$AGENT_HOME/.local" \
    -e TZ="Europe/Berlin" \
    -e USER="$HOST_USER" \
    -e XDG_CACHE_HOME="$AGENT_HOME/.cache" \
    -e XDG_CONFIG_HOME="$AGENT_HOME/.config" \
    -e XDG_DATA_HOME="$AGENT_HOME/.local/share" \
    -e XDG_STATE_HOME="$AGENT_HOME/.local/state" \
    -v "$WORKSPACE_DIR":/workspace \
    -v "$PASSWD_FILE":/etc/passwd:ro \
    -v "$GROUP_FILE":/etc/group:ro \
    -v "$GITCONFIG":/tmp/host.gitconfig:ro \
    -v "$HOST_AGENT_HOME":"$AGENT_HOME" \
    -v "$CLAUDE_DIR":"$AGENT_HOME/.claude" \
    -v "$CODEX_DIR":"$AGENT_HOME/.codex" \
    -v "$AGENTS_DIR":"$AGENT_HOME/.agents" \
    -v "$COPILOT_DIR":"$AGENT_HOME/.copilot" \
    -v "$CURSOR_DIR":"$AGENT_HOME/.cursor" \
    -w /workspace \
    --name="$CONTAINER_NAME" \
    agent-sandbox \
    bash -lc 'mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$(dirname "$HISTFILE")" && exec bash -i'
