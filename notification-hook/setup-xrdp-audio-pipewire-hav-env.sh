#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf '\n[WARN] %s\n' "$*" >&2
}

require_debian_like() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Dieses Skript erwartet ein Debian/Ubuntu-artiges System mit apt-get." >&2
    exit 1
  fi
}

require_non_root_user_context() {
  if [ "${EUID}" -eq 0 ]; then
    cat >&2 <<'EOF'
Bitte nicht direkt als root ausführen.

Nutze:
  bash setup-xrdp-audio-pipewire.sh

Das Skript verwendet sudo für Systempakete, muss aber User-Services
wie pipewire.service im Kontext deines Login-Users aktivieren.
EOF
    exit 1
  fi
}

check_sudo() {
  if ! sudo -v; then
    echo "sudo ist erforderlich." >&2
    exit 1
  fi
}

install_packages() {
  log "Installiere PipeWire/XRDP-Audio-Pakete ..."

  sudo apt-get update

  sudo apt-get install -y \
    pipewire \
    pipewire-bin \
    pipewire-pulse \
    wireplumber \
    pipewire-module-xrdp \
    libpipewire-0.3-modules-xrdp \
    pulseaudio-utils \
    alsa-utils \
    pavucontrol
}

disable_classic_pulseaudio_user_units() {
  log "Deaktiviere klassische PulseAudio-User-Units, falls vorhanden ..."

  systemctl --user stop pulseaudio.socket pulseaudio.service 2>/dev/null || true
  systemctl --user disable pulseaudio.socket pulseaudio.service 2>/dev/null || true
}

enable_pipewire_user_units() {
  log "Aktiviere PipeWire, pipewire-pulse und WirePlumber ..."

  systemctl --user daemon-reload
  systemctl --user enable --now pipewire.socket pipewire.service
  systemctl --user enable --now pipewire-pulse.socket pipewire-pulse.service
  systemctl --user enable --now wireplumber.service
}

restart_xrdp() {
  log "Starte XRDP-Dienste neu ..."

  sudo systemctl restart xrdp xrdp-sesman
}

print_status() {
  log "Status der Audio-Services:"
  systemctl --user --no-pager --full status pipewire pipewire-pulse wireplumber || true

  log "Paketstatus:"
  dpkg -l | grep -E 'pipewire|xrdp|pulse' || true

  log "PulseAudio-Kompatibilität / PipeWire-Status:"
  pactl info | grep -E 'Server Name|Default Sink|Default Source' || true

  log "Sinks:"
  pactl list short sinks || true

  cat <<'EOF'

Fertig.

Wichtig:
  1. RDP-Verbindung jetzt komplett trennen.
  2. Im Windows-RDP-Client prüfen:
       Optionen anzeigen
       -> Lokale Ressourcen
       -> Remoteaudio: Einstellungen
       -> Remotewiedergabe: Auf diesem Computer wiedergeben
  3. Danach neu verbinden.

Test nach dem Neuverbinden:
  pactl info | grep -E 'Server Name|Default Sink|Default Source'
  pactl list short sinks
  speaker-test -t wav -c 2

Erwartung:
  Server Name: PulseAudio (on PipeWire ...)
  Default Sink: xrdp-sink

Hinweis:
  xrdp-sink ... SUSPENDED ist nach dem Abspielen normal.
  Während Audio läuft, kann der Sink kurz RUNNING sein.
EOF
}

main() {
  require_debian_like
  require_non_root_user_context
  check_sudo

  install_packages
  disable_classic_pulseaudio_user_units
  enable_pipewire_user_units
  restart_xrdp
  print_status
}

main "$@"