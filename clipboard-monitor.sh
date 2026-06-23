#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "clipboard-monitor: nur auf macOS unterstützt" >&2
    exit 1
fi

OUTPUT_FOLDER="${AGENT_SANDBOX_CLIPBOARD_DIR:-$HOME/tools/clipboard-images}"
CONTAINER_PREFIX="${AGENT_SANDBOX_CLIPBOARD_CONTAINER_PATH:-/home/$(id -un)/clipboard}"

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

last_hash=""

while true; do
    sleep 0.5

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

    echo "[$(date +%H:%M:%S)] Gespeichert: $filename"
    echo "    Container-Pfad: $docker_path"

    last_hash="$hash"
done
