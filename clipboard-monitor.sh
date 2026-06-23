#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "clipboard-monitor: nur auf macOS unterstützt" >&2
    exit 1
fi

OUTPUT_FOLDER="${AGENT_SANDBOX_CLIPBOARD_DIR:-$HOME/tools/clipboard-images}"
CONTAINER_PREFIX="${AGENT_SANDBOX_CLIPBOARD_CONTAINER_PATH:-/home/$(id -un)/clipboard}"
TERMINAL_APPS='^(Terminal|iTerm2|Cursor|Warp|WezTerm|Alacritty|kitty|Hyper|Docker Desktop)$'

mkdir -p "$OUTPUT_FOLDER"

save_clipboard_png() {
    local outfile="$1"
    osascript - "$outfile" <<'APPLESCRIPT'
on run argv
    set outPath to item 1 of argv
    try
        set imageData to the clipboard as «class PNGf»
        set outFile to POSIX file outPath
        set fileRef to open for access outFile with write permission
        set eof fileRef to 0
        write imageData to fileRef
        close access fileRef
        return "ok"
    on error
        try
            close access (POSIX file outPath)
        end try
        return "fail"
    end try
end run
APPLESCRIPT
}

set_clipboard_png_only() {
    local infile="$1"
    osascript - "$infile" <<'APPLESCRIPT'
on run argv
    set imagePath to item 1 of argv
    try
        set imageData to read (POSIX file imagePath) as «class PNGf»
        set the clipboard to {«class PNGf»:imageData}
        return "ok"
    on error
        return "fail"
    end try
end run
APPLESCRIPT
}

set_clipboard_png_and_path() {
    local infile="$1"
    local docker_path="$2"
    osascript - "$infile" "$docker_path" <<'APPLESCRIPT'
on run argv
    set imagePath to item 1 of argv
    set pathText to item 2 of argv
    try
        set imageData to read (POSIX file imagePath) as «class PNGf»
        set the clipboard to {«class PNGf»:imageData, string:pathText}
        return "ok"
    on error
        return "fail"
    end try
end run
APPLESCRIPT
}

frontmost_app() {
    osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true
}

is_terminal_focused() {
    local app="${1:-$(frontmost_app)}"
    [[ "$app" =~ $TERMINAL_APPS ]]
}

last_hash=""
last_image_path=""
last_docker_path=""
path_injected=false
last_frontmost=""

handle_focus_change() {
    local frontmost="$1"

    if is_terminal_focused "$frontmost"; then
        if [[ -n "$last_image_path" && -f "$last_image_path" && -n "$last_docker_path" ]]; then
            set_clipboard_png_and_path "$last_image_path" "$last_docker_path" >/dev/null
            path_injected=true
        fi
        return
    fi

    if [[ "$path_injected" == true && -n "$last_image_path" && -f "$last_image_path" ]]; then
        local current_clip
        current_clip="$(pbpaste 2>/dev/null || true)"
        if [[ "$current_clip" == "$last_docker_path" ]]; then
            set_clipboard_png_only "$last_image_path" >/dev/null
        fi
        path_injected=false
    fi
}

while true; do
    sleep 0.5

    frontmost="$(frontmost_app)"
    if [[ "$frontmost" != "$last_frontmost" ]]; then
        handle_focus_change "$frontmost"
        last_frontmost="$frontmost"
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/clipboard-monitor.XXXXXX")"
    if [[ "$(save_clipboard_png "$tmp")" != "ok" ]]; then
        rm -f "$tmp"
        continue
    fi

    hash="$(md5 -q "$tmp")"
    if [[ -z "$hash" || "$hash" == "$last_hash" ]]; then
        rm -f "$tmp"
        continue
    fi

    timestamp="$(date +%Y%m%d_%H%M%S)"
    filename="clipboard-image-${timestamp}.png"
    full_path="$OUTPUT_FOLDER/$filename"
    mv "$tmp" "$full_path"

    docker_path="$CONTAINER_PREFIX/$filename"
    printf '%s\n' "$docker_path" > "$OUTPUT_FOLDER/.latest-container-path"
    ln -sfn "$filename" "$OUTPUT_FOLDER/latest.png"

    last_image_path="$full_path"
    last_docker_path="$docker_path"
    last_hash="$hash"

    if is_terminal_focused "$frontmost"; then
        set_clipboard_png_and_path "$full_path" "$docker_path" >/dev/null
        path_injected=true
    else
        path_injected=false
    fi

    echo "[$(date +%H:%M:%S)] Gespeichert: $filename"
    echo "    Container-Pfad: $docker_path"
done
