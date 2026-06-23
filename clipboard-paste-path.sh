#!/bin/bash
# Legt den Container-Pfad des letzten kopierten Bildes als Text in die
# macOS-Zwischenablage. Danach kann der Pfad per Cmd+V ins Container-Terminal
# eingefügt werden.
#
# Aufruf: clipboard-paste-path (oder per Tastenkürzel/Automator-Service)
set -euo pipefail

CLIPBOARD_DIR="${AGENT_SANDBOX_CLIPBOARD_DIR:-$HOME/tools/clipboard-images}"
LATEST_PATH="$CLIPBOARD_DIR/.latest-container-path"

if [[ ! -f "$LATEST_PATH" ]]; then
    echo "Kein Bild vorhanden." >&2
    exit 1
fi

path="$(cat "$LATEST_PATH")"
printf '%s' "$path" | pbcopy
echo "$path"
