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
SANDBOX_DIR="$HOME/.agent-sandbox"
HOST_AGENT_HOME="$SANDBOX_DIR/home"
CURSOR_MCP_DIR="$SANDBOX_DIR/cursor"
CURSOR_MCP_FILE="$CURSOR_MCP_DIR/mcp.json"
CLAUDE_MCP_DIR="$SANDBOX_DIR/claude"
CLAUDE_MCP_FILE="$CLAUDE_MCP_DIR/mcp-servers.json"
CODEX_MCP_DIR="$SANDBOX_DIR/codex"
CODEX_MCP_FILE="$CODEX_MCP_DIR/mcp-servers.toml"
CODEX_CONFIG_FILE="$CODEX_MCP_DIR/config.toml"
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
mkdir -p "$HOST_AGENT_HOME" "$CURSOR_MCP_DIR" "$CLAUDE_MCP_DIR" "$CODEX_MCP_DIR" "$CLIPBOARD_DIR" "$CLAUDE_DIR" "$CODEX_DIR" "$AGENTS_DIR" "$COPILOT_DIR" "$CURSOR_DIR" \
    "$GEMINI_ANTIGRAVITY_CLI_DIR" "$GEMINI_CONFIG_DIR"

if [ ! -f "$CURSOR_MCP_FILE" ]; then
    cat > "$CURSOR_MCP_FILE" <<'EOF'
{
  "mcpServers": {
    "github": {
      "command": "/usr/local/bin/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${env:GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    }
  }
}
EOF
fi

if [ ! -f "$CLAUDE_MCP_FILE" ]; then
    cat > "$CLAUDE_MCP_FILE" <<'EOF'
{
  "mcpServers": {
    "github": {
      "type": "stdio",
      "command": "/usr/local/bin/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    }
  }
}
EOF
fi

if [ ! -f "$CODEX_MCP_FILE" ]; then
    cat > "$CODEX_MCP_FILE" <<'EOF'
[mcp_servers.github]
command = "/usr/local/bin/github-mcp-server"
args = ["stdio"]

[mcp_servers.github.env]
GITHUB_PERSONAL_ACCESS_TOKEN = "${GITHUB_PERSONAL_ACCESS_TOKEN}"
EOF
fi

merge_codex_mcp_servers() {
    if [ ! -f "$CODEX_CONFIG_FILE" ]; then
        cat > "$CODEX_CONFIG_FILE" <<'EOF'
[projects."/workspace"]
trust_level = "trusted"
EOF
    elif ! grep -qF '[projects."/workspace"]' "$CODEX_CONFIG_FILE"; then
        cat >> "$CODEX_CONFIG_FILE" <<'EOF'

[projects."/workspace"]
trust_level = "trusted"
EOF
    fi

    if grep -q 'command = "/usr/local/bin/github-mcp-server"' "$CODEX_CONFIG_FILE" 2>/dev/null; then
        return 0
    fi

    if command -v codex >/dev/null 2>&1; then
        CODEX_HOME="$CODEX_MCP_DIR" codex mcp remove github >/dev/null 2>&1 || true
        CODEX_HOME="$CODEX_MCP_DIR" codex mcp add github \
            --env GITHUB_PERSONAL_ACCESS_TOKEN='${GITHUB_PERSONAL_ACCESS_TOKEN}' \
            -- /usr/local/bin/github-mcp-server stdio
    elif ! grep -q '^\[mcp_servers\.github\]' "$CODEX_CONFIG_FILE"; then
        printf '\n%s\n' "$(cat "$CODEX_MCP_FILE")" >> "$CODEX_CONFIG_FILE"
    fi
}
merge_codex_mcp_servers

merge_claude_mcp_servers() {
    python3 - "$HOST_AGENT_HOME/.claude.json" "$CLAUDE_MCP_FILE" <<'PY'
import json
import sys
from pathlib import Path

claude_path = Path(sys.argv[1])
fragment_path = Path(sys.argv[2])

fragment = json.loads(fragment_path.read_text())
fragment_servers = fragment.get("mcpServers", fragment)

if claude_path.is_file():
    data = json.loads(claude_path.read_text())
else:
    data = {}

servers = data.setdefault("mcpServers", {})
for name, config in fragment_servers.items():
    servers[name] = config

claude_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}
merge_claude_mcp_servers

GITHUB_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
if [ -z "$GITHUB_TOKEN" ] && command -v gh >/dev/null 2>&1; then
    GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
fi

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

cat > "$HOST_AGENT_HOME/.agent-sandbox-clipboard.sh" <<'EOF'
clip-path() {
    cat "$HOME/clipboard/.latest-container-path" 2>/dev/null || echo "$HOME/clipboard/latest.png"
}
clip-img() {
    echo "Letztes Bild: $(clip-path)"
    ls -la "$HOME/clipboard/latest.png" 2>/dev/null
}
EOF

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
    -e CLAUDE_CONFIG_DIR="$AGENT_HOME/.claude" \
    -e CODEX_HOME="$AGENT_HOME/.codex" \
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
    ${GITHUB_TOKEN:+-e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN"} \
    -v "$WORKSPACE_DIR":/workspace \
    -v "$PASSWD_FILE":/etc/passwd:ro \
    -v "$GROUP_FILE":/etc/group:ro \
    -v "$GITCONFIG":/tmp/host.gitconfig:ro \
    -v "$HOST_AGENT_HOME":"$AGENT_HOME" \
    -v "$CLAUDE_DIR":"/host-claude:ro" \
    -v "$CODEX_MCP_DIR":"$AGENT_HOME/.codex" \
    -v "$CODEX_DIR":"/host-codex:ro" \
    -v "$AGENTS_DIR":"$AGENT_HOME/.agents" \
    -v "$COPILOT_DIR":"$AGENT_HOME/.copilot" \
    -v "$CURSOR_DIR":"$AGENT_HOME/.cursor" \
    -v "$CURSOR_MCP_FILE":"$AGENT_HOME/.cursor/mcp.json" \
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
if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
  export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null || true)"
fi
for f in auth.json hooks.json; do
  [ -f "/host-codex/$f" ] && [ ! -f "$HOME/.codex/$f" ] && cp "/host-codex/$f" "$HOME/.codex/$f"
done
[ -d /host-codex/skills ] && [ ! -e "$HOME/.codex/skills" ] && ln -sfn /host-codex/skills "$HOME/.codex/skills"
mkdir -p "$HOME/.claude"
for f in .credentials.json settings.json settings.local.json; do
  [ -f "/host-claude/$f" ] && [ ! -f "$HOME/.claude/$f" ] && cp "/host-claude/$f" "$HOME/.claude/$f"
done
[ -d /host-claude/hooks ] && [ ! -e "$HOME/.claude/hooks" ] && cp -R /host-claude/hooks "$HOME/.claude/hooks"
[ -d /host-claude/skills ] && [ ! -e "$HOME/.claude/skills" ] && ln -sfn /host-claude/skills "$HOME/.claude/skills"
grep -qF agent-sandbox-clipboard.sh "$HOME/.bashrc" 2>/dev/null || printf "%s\n" "[ -f \"\$HOME/.agent-sandbox-clipboard.sh\" ] && . \"\$HOME/.agent-sandbox-clipboard.sh\"" >> "$HOME/.bashrc"
exec bash -i'
