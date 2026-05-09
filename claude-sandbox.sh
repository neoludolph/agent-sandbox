#!/bin/bash
CONTAINER_NAME=claude-sandbox
WORKSPACE_DIR="${1:-$(pwd)}"
GITCONFIG=/home/vagrant/.gitconfig
M2_DIR=/home/vagrant/.m2/
CLAUDE_DIR=/home/vagrant/.claude/
TRUSTSTORE=/home/vagrant/Documents/java.certs/cacerts
PULSE_SOCKET_DIR=/run/user/$(id -u)/pulse

# Sicherstellen, dass die Host-Ressourcen existieren
[ -f "$GITCONFIG" ] || { echo "Datei $GITCONFIG nicht vorhanden"; exit 1; }
[ -f "$TRUSTSTORE" ] || { echo "Datei $TRUSTSTORE nicht vorhanden"; exit 1; }
mkdir -p "$M2_DIR"
mkdir -p "$CLAUDE_DIR"

AUDIO_ARGS=()
if [ -S "$PULSE_SOCKET_DIR/native" ]; then
    AUDIO_ARGS=(
        -v "$PULSE_SOCKET_DIR:$PULSE_SOCKET_DIR"
        -v "/home/vagrant/Documents:/home/vagrant/Documents:ro,z"
        -e "PULSE_SERVER=unix:$PULSE_SOCKET_DIR/native"
        -e "XDG_RUNTIME_DIR=/run/user/$(id -u)"
    )
else
    echo "[WARN] PulseAudio/PipeWire-Socket nicht gefunden ($PULSE_SOCKET_DIR/native) – kein Audio im Container."
fi

podman run -it \
    --rm \
    --userns=keep-id \
    -e CLAUDE_SKIP_AUTOUPDATER=1 \
    -v "$WORKSPACE_DIR":/workspace:z \
    -v "$GITCONFIG":/workspace/.gitconfig:ro,z \
    -v "$M2_DIR":/workspace/.m2:z \
    -v "$CLAUDE_DIR":/workspace/.claude:z \
    -v "$TRUSTSTORE":/etc/ssl/java/cacerts:ro,z \
    "${AUDIO_ARGS[@]}" \
    -w /workspace \
    -e HOME=/workspace \
    -e TZ="Europe/Berlin" \
    --name="$CONTAINER_NAME" \
    --replace \
    localhost/claude-sandbox \
    bash
