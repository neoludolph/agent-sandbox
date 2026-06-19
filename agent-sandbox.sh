#!/bin/bash
set -euo pipefail

script_path="${BASH_SOURCE[0]}"
while [[ -L "$script_path" ]]; do
    script_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
    script_path="$(readlink "$script_path")"
    [[ "$script_path" != /* ]] && script_path="$script_dir/$script_path"
done
SCRIPT_DIR="$(cd -P "$(dirname "$script_path")" && pwd)"
CONTAINER_NAME="agent-sandbox-$$"
WORKSPACE_DIR="${1:-$(pwd)}"
HOST_AGENT_HOME="$HOME/.agent-sandbox/home"
CLIPBOARD_DIR="${AGENT_SANDBOX_CLIPBOARD_DIR:-$HOME/tools/clipboard-images}"
CLIPBOARD_MONITOR_PID=""
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
GEMINI_ANTIGRAVITY_CLI_DIR="$HOME/.gemini/antigravity-cli"
GEMINI_CONFIG_DIR="$HOME/.gemini/config"

[ -f "$GITCONFIG" ] || { echo "Datei $GITCONFIG nicht vorhanden"; exit 1; }
mkdir -p "$HOST_AGENT_HOME" "$CLIPBOARD_DIR" "$CLAUDE_DIR" "$CODEX_DIR" "$AGENTS_DIR" "$COPILOT_DIR" "$CURSOR_DIR" \
    "$GEMINI_ANTIGRAVITY_CLI_DIR" "$GEMINI_CONFIG_DIR"

HOST_GEMINI_FILES="/host-gemini"
GEMINI_AUTH_MOUNTS=()
for gemini_file in settings.json oauth_creds.json google_accounts.json; do
    gemini_path="$HOME/.gemini/$gemini_file"
    if [ -f "$gemini_path" ]; then
        GEMINI_AUTH_MOUNTS+=( -v "$gemini_path":"$HOST_GEMINI_FILES/$gemini_file":ro )
    fi
done

PASSWD_FILE="$(mktemp)"
GROUP_FILE="$(mktemp)"
cleanup() {
    if [[ -n "${CLIPBOARD_MONITOR_PID:-}" ]] && kill -0 "$CLIPBOARD_MONITOR_PID" 2>/dev/null; then
        kill "$CLIPBOARD_MONITOR_PID" 2>/dev/null || true
        wait "$CLIPBOARD_MONITOR_PID" 2>/dev/null || true
    fi
    rm -f "$PASSWD_FILE" "$GROUP_FILE"
}
trap cleanup EXIT

if [[ "$(uname -s)" == "Darwin" ]]; then
    export AGENT_SANDBOX_CLIPBOARD_DIR="$CLIPBOARD_DIR"
    export AGENT_SANDBOX_CLIPBOARD_CONTAINER_PATH="$AGENT_HOME/clipboard"
    CLIPBOARD_LOG="$HOST_AGENT_HOME/clipboard-monitor.log"
    "$SCRIPT_DIR/clipboard-monitor.sh" >>"$CLIPBOARD_LOG" 2>&1 &
    CLIPBOARD_MONITOR_PID=$!
    echo "Clipboard-Monitor aktiv: $CLIPBOARD_DIR → $AGENT_HOME/clipboard"
fi

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
    -e GIT_CONFIG_GLOBAL="$AGENT_HOME/.gitconfig" \
    -e HISTFILE="$AGENT_HOME/.bash_history.$$" \
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
    -v "$GEMINI_ANTIGRAVITY_CLI_DIR":"$AGENT_HOME/.gemini/antigravity-cli" \
    -v "$GEMINI_CONFIG_DIR":"$AGENT_HOME/.gemini/config" \
    -v "$CLIPBOARD_DIR":"$AGENT_HOME/clipboard" \
    "${GEMINI_AUTH_MOUNTS[@]}" \
    -w /workspace \
    --name="$CONTAINER_NAME" \
    agent-sandbox \
    bash -lc 'mkdir -p "$HOME" "$HOME/.gemini" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$(dirname "$HISTFILE")"
for f in settings.json oauth_creds.json google_accounts.json; do
  [ -f "/host-gemini/$f" ] && ln -sfn "/host-gemini/$f" "$HOME/.gemini/$f"
done
HOST_GITCONFIG=/tmp/host.gitconfig
if [ ! -f "$HOME/.gitconfig" ]; then
  printf "%s\n" "[include]" "    path = $HOST_GITCONFIG" > "$HOME/.gitconfig"
elif ! grep -qF "$HOST_GITCONFIG" "$HOME/.gitconfig"; then
  tmp="$(mktemp)"
  { printf "%s\n" "[include]" "    path = $HOST_GITCONFIG" ""; cat "$HOME/.gitconfig"; } > "$tmp"
  mv "$tmp" "$HOME/.gitconfig"
fi
exec bash -i'
