# agent-sandbox

Containerisierte Entwicklungsumgebung mit Java, Maven, Node.js, Python und Agent-CLIs.

## Enthalten

- Debian 12 Slim
- Java (Amazon Corretto 25) via SDKMAN
- Maven 3.9.9 via SDKMAN
- Node.js 22
- Python 3 (inkl. `pip`, `venv`)
- Claude Code CLI (`@anthropic-ai/claude-code`)
- OpenAI Codex CLI (`@openai/codex`)
- Cursor Agent CLI (`curl https://cursor.com/install -fsS | bash`)
- GitHub Copilot CLI (`@github/copilot`)
- GitHub CLI (`gh`, offizielles APT-Repository)
- Google Antigravity CLI (`agy`, via `curl -fsSL https://antigravity.google/cli/install.sh | bash`)

## Voraussetzungen

- Docker
- `~/.gitconfig`

Das persistente Container-Home `~/.agent-sandbox/home` und die
Konfigurationsverzeichnisse `~/.claude`, `~/.codex`, `~/.agents`, `~/.copilot`,
`~/.cursor`, `~/.gemini/antigravity-cli` und `~/.gemini/config` werden beim
Start automatisch angelegt, falls sie noch nicht existieren. Vorhandene Dateien
unter `~/.gemini/` (`settings.json`, `oauth_creds.json`, `google_accounts.json`)
werden bei Bedarf nach `/host-gemini` gemountet und beim Start nach
`~/.gemini` verlinkt (vermeidet virtiofs-Konflikte mit dem Container-Home).

## Unterstützte Host-Systeme

Das Startskript ist für Unix-artige Hosts ausgelegt:

- macOS mit Docker Desktop oder Colima
- Linux mit Docker Engine oder einer kompatiblen Docker-Umgebung
- Windows über WSL2, wenn Docker aus der WSL-Shell erreichbar ist

Windows PowerShell und CMD werden nicht direkt unterstützt, weil das Skript
Bash, Unix-Pfade, UID/GID-Mapping und Unix-Volume-Mounts verwendet.

Das Image kann grundsätzlich auf `amd64` und `arm64` gebaut werden, sofern die
installierten Agent-CLIs passende Linux-Binaries für die jeweilige Architektur
bereitstellen.

## Container bauen

```bash
./buildContainer.sh
```

Das Skript baut das Image `agent-sandbox` aus dem lokalen `Containerfile`.

## Starten

Im Projektverzeichnis:

```bash
./agent-sandbox.sh
```

Das aktuelle Verzeichnis wird als `/workspace` in den Container gemountet.
Alternativ kann ein Projektpfad übergeben werden:

```bash
./agent-sandbox.sh /pfad/zum/projekt
```

Im Container ist `/workspace` das Arbeitsverzeichnis. Das Home-Verzeichnis der
Agenten liegt separat unter `/home/<user>` und wird auf dem Host unter
`~/.agent-sandbox/home` gespeichert, damit Shell-Historie, XDG-State,
Authentifizierung und Agent-Dateien erhalten bleiben, aber nicht im Projektroot
entstehen.
Der Container läuft mit der UID/GID des aufrufenden Host-Users, damit im
Projekt erzeugte Dateien nicht root gehören. Beim Start werden temporäre
`/etc/passwd`- und `/etc/group`-Dateien gemountet, damit diese UID im Container
auch einen Namen hat.

### Skript ins PATH legen

```bash
ln -s "$(pwd)/agent-sandbox.sh" ~/.local/bin/agent-sandbox
```

Danach kann der Container aus jedem Projekt heraus gestartet werden:

```bash
cd /dein/projekt
agent-sandbox
```

## Container verwalten

**Beenden** (im Container):

```bash
exit
```

**Beenden** (vom Host aus, während der Container läuft):

```bash
docker stop agent-sandbox
```

**Laufende Container anzeigen:**

```bash
docker ps
```

## Gemountete Verzeichnisse

| Host | Container | Beschreibung |
|------|-----------|--------------|
| aktuelles Verzeichnis oder Argument | `/workspace` | Projektdateien |
| `~/.agent-sandbox/home` | `/home/<user>` | Persistentes Container-Home |
| `~/.gitconfig` | `/tmp/host.gitconfig` | Host-Git-Konfiguration, read-only (per `[include]` in `~/.agent-sandbox/home/.gitconfig`) |
| `~/.agent-sandbox/home/.gitconfig` | `/home/<user>/.gitconfig` | Beschreibbare Git-Konfiguration im Container (z. B. für `gh auth login`) |
| `~/.claude` | `/home/<user>/.claude` | Claude-Konfiguration |
| `~/.codex` | `/home/<user>/.codex` | Codex-Konfiguration |
| `~/.agents` | `/home/<user>/.agents` | Agent-Konfiguration und Skills |
| `~/.copilot` | `/home/<user>/.copilot` | GitHub-Copilot-Konfiguration |
| `~/.cursor` | `/home/<user>/.cursor` | Cursor-Konfiguration |
| `~/.gemini/antigravity-cli` | `/home/<user>/.gemini/antigravity-cli` | Antigravity-CLI-Einstellungen, Plugins, Keybindings |
| `~/.gemini/config` | `/home/<user>/.gemini/config` | Antigravity-Projektkonfiguration |
| `~/.gemini/settings.json` usw. | `/host-gemini/…` → Symlink | Optional: MCP, OAuth und Account-Dateien (falls vorhanden) |
| `~/tools/clipboard-images` (oder `AGENT_SANDBOX_CLIPBOARD_DIR`) | `/home/<user>/clipboard` | Zwischenablage-Bilder vom macOS-Host (nur macOS) |

### Zwischenablage-Bilder (macOS)

Beim Start von `./agent-sandbox.sh` läuft auf macOS automatisch
`clipboard-monitor.sh` im Hintergrund. Kopierte Bilder landen unter
`~/tools/clipboard-images` und sind im Container unter
`/home/<user>/clipboard/` verfügbar. Die Zwischenablage enthält danach
**Bild und Container-Pfad gleichzeitig**: In Apps wie Slack/Preview wird das
Bild eingefügt, im Container-Terminal der Pfad.

Im Container:

```bash
cat ~/clipboard/.latest-container-path   # letzter Pfad
ls ~/clipboard/latest.png                  # Symlink auf letztes Bild
```

Anderen Host-Ordner setzen:

```bash
export AGENT_SANDBOX_CLIPBOARD_DIR=/pfad/zu/clipboard-images
./agent-sandbox.sh
```

## Hinweise

- Der Container wird mit `--rm` gestartet und nach `exit` automatisch entfernt.
- Der Containername ist `agent-sandbox`.
- Der Claude-Autoupdater ist deaktiviert (`CLAUDE_SKIP_AUTOUPDATER=1`).
- `HOME`, `HISTFILE` und die XDG-Verzeichnisse zeigen auf `/home/<user>`.
  Dadurch landen `.bash_history`, `.cache`, `.local`, `.npm` und
  Claude-Home-Dateien nicht mehr in `/workspace`, bleiben aber unter
  `~/.agent-sandbox/home` erhalten.
- Das Container-Home liegt bewusst nicht unter `/tmp`, weil Codex CLI dort
  keine Helper-Binaries anlegen will.
- npm-Cache und npm-Logs liegen im Container unter `/tmp`, damit Agent-CLIs
  keine npm-Logdateien im gemounteten Projektverzeichnis erzeugen.
- Die Agent-CLIs starten im YOLO-Modus:
  `claude --dangerously-skip-permissions`,
  `codex --dangerously-bypass-approvals-and-sandbox`,
  `copilot --yolo` und
  `cursor-agent`/`agent --yolo --sandbox disabled --approve-mcps` und
  `agy`/`antigravity --dangerously-skip-permissions`.
- Interaktiv entspricht das dem Autonomie-Level `always-proceed` aus `/permissions`
  ([Antigravity CLI Features](https://antigravity.google/docs/cli-features)).
- Die Zeitzone ist auf `Europe/Berlin` gesetzt.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz veröffentlicht. Siehe [LICENSE](LICENSE).
