# claude-sandbox

Containerisierte Entwicklungsumgebung mit Java, Maven und Claude Code CLI.

## Enthält

- Debian 12 Slim
- Java (Amazon Corretto 25) via SDKMAN
- Maven 3.9.9 via SDKMAN
- Node.js 20 + Claude Code CLI
- PulseAudio-Client (`alsa-utils`, `libpulse0`, `pulseaudio-utils`)

## Voraussetzungen

- Podman
- `~/.gitconfig`
- `~/Documents/java.certs/cacerts` (Java Truststore)

## Container bauen

```bash
cd /home/vagrant/claude-sandbox
./buildContainer.sh
```

## Starten

```bash
cd /dein/projekt
/home/vagrant/claude-sandbox/claude-sandbox.sh
```

Das aktuelle Verzeichnis wird als `/workspace` in den Container gemountet.
Alternativ kann ein Pfad übergeben werden:

```bash
/home/vagrant/claude-sandbox/claude-sandbox.sh /pfad/zum/projekt
```

### Tipp: Skript ins PATH legen

```bash
ln -s /home/vagrant/claude-sandbox/claude-sandbox.sh ~/.local/bin/claude-sandbox
```

Dann genügt überall:

```bash
cd /dein/projekt
claude-sandbox
```

## Container verwalten

**Starten:** siehe Abschnitt [Starten](#starten)

**Beenden** (von innerhalb des Containers):
```bash
exit
```

**Beenden** (vom Host aus, während der Container läuft):
```bash
docker stop claude-sandbox # bzw. podman stop claude-sandbox
```

**Laufende Container anzeigen:**
```bash
docker ps # bzw. podman ps
```

## Gemountete Verzeichnisse

| Host | Container | Beschreibung |
|------|-----------|--------------|
| aktuelles Verzeichnis (oder Argument) | `/workspace` | Projektdateien |
| `~/.gitconfig` | `/workspace/.gitconfig` | Git-Konfiguration (read-only) |
| `~/.m2/` | `/workspace/.m2` | Maven-Cache |
| `~/.claude/` | `/workspace/.claude` | Claude-Konfiguration |
| `~/Documents/java.certs/cacerts` | `/etc/ssl/java/cacerts` | Java Truststore (read-only) |
| `$XDG_RUNTIME_DIR/pulse` | `$XDG_RUNTIME_DIR/pulse` | PulseAudio-Socket (optional, nur wenn vorhanden) |
| `~/Documents` | `/home/vagrant/Documents` | Audio-Dateien für Notification-Hooks (read-only, optional) |

Die Audio-Mounts werden nur eingebunden, wenn der PulseAudio/PipeWire-Socket unter `$XDG_RUNTIME_DIR/pulse/native` vorhanden ist.

## Notification-Hooks mit Audio

Das Verzeichnis `notification-hook/` enthält Skripte und Anleitungen, um Claude Code bei Fertigstellung oder Benachrichtigungen einen Ton abspielen zu lassen.

- `setup-xrdp-audio-pipewire-hav-env.sh` – richtet PipeWire auf dem Host (HAV-Umgebung via XRDP) ein
- `einrichtung.md` – Schritt-für-Schritt-Anleitung zur Einrichtung
