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
- GitHub MCP Server (`github-mcp-server`, offizielles Binary-Release)
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

### Skripte ins PATH legen

Im Projektverzeichnis `agent-sandbox`:

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd)/agent-sandbox.sh" ~/.local/bin/agent-sandbox
ln -s "$(pwd)/clipboard-paste-path.sh" ~/.local/bin/clipboard-paste-path
```

Stelle sicher, dass `~/.local/bin` in deiner Shell im `PATH` liegt (z. B. in
`~/.zshrc`: `export PATH="$HOME/.local/bin:$PATH"`).

Danach kann der Container aus jedem Projekt heraus gestartet werden:

```bash
cd /dein/projekt
agent-sandbox
```

Und der Clipboard-Pfad steht überall zur Verfügung:

```bash
clipboard-paste-path
```

### GitHub MCP

Der Container bringt den offiziellen [GitHub MCP Server](https://github.com/github/github-mcp-server)
als Binary mit. Die MCP-Konfiguration liegt getrennt vom Host:

| Agent | Datei |
|-------|-------|
| Cursor Agent CLI | `~/.agent-sandbox/cursor/mcp.json` |
| Claude Code | `~/.agent-sandbox/claude/mcp-servers.json` → wird in `~/.agent-sandbox/home/.claude.json` gemergt |
| Codex CLI | `~/.agent-sandbox/codex/` → beschreibbares `CODEX_HOME` im Container |

Beim ersten Start werden Default-Dateien angelegt. Host-Pfade aus `~/.cursor/mcp.json`,
`~/.claude.json` oder `~/.codex/config.toml` funktionieren im Container nicht.

**Einmalig authentifizieren** (im Container):

```bash
gh auth login
```

Das Token wird in `~/.agent-sandbox/home/.config/gh/` gespeichert. Beim Start
liest das Skript es via `gh auth token` und setzt `GITHUB_PERSONAL_ACCESS_TOKEN`.
Alternativ kann das Token vom Host übergeben werden:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"
./agent-sandbox.sh
```

**Prüfen** (im Container):

```bash
# Cursor Agent CLI
cursor-agent mcp list
cursor-agent mcp list-tools github

# Claude Code
claude mcp list
claude mcp get github

# Codex CLI
codex mcp list
codex mcp get github
```

Für **Copilot CLI** ist der GitHub MCP eingebaut — nach `gh auth login` reicht
`/mcp show github-mcp-server`.

Weitere MCP-Server kannst du in den Container-Config-Dateien ergänzen
(`~/.agent-sandbox/codex/config.toml` für Codex).
Nur Container-Pfade oder HTTP-URLs verwenden, keine Host-Pfade wie `/Users/...`.

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
| `~/.agent-sandbox/home/.claude` | `/home/<user>/.claude` | Claude-Code-Daten im Container (Credentials, Hooks; getrennt vom Host) |
| `~/.claude` | `/host-claude` (read-only) | Host-Claude: Credentials/Hooks/Skills werden beim Start übernommen bzw. verlinkt |
| `~/.agent-sandbox/codex` | `/home/<user>/.codex` | Codex-Home im Container (beschreibbar, inkl. MCP und Hook-Trust) |
| `~/.codex` | `/host-codex` (read-only) | Host-Codex: `auth.json`, `skills` usw. werden bei Bedarf übernommen |
| `~/.agents` | `/home/<user>/.agents` | Agent-Konfiguration und Skills |
| `~/.copilot` | `/home/<user>/.copilot` | GitHub-Copilot-Konfiguration |
| `~/.cursor` | `/home/<user>/.cursor` | Cursor-Konfiguration (Skills, Rules usw.) |
| `~/.agent-sandbox/cursor/mcp.json` | `/home/<user>/.cursor/mcp.json` | Container-MCP für Cursor Agent CLI |
| `~/.agent-sandbox/claude/mcp-servers.json` | (gemergt in Container-Home) | Container-MCP für Claude Code |
| `~/.agent-sandbox/home/.claude.json` | `/home/<user>/.claude.json` | Claude-Code-State inkl. gemergter MCP-Server |
| `~/.gemini/antigravity-cli` | `/home/<user>/.gemini/antigravity-cli` | Antigravity-CLI-Einstellungen, Plugins, Keybindings |
| `~/.gemini/config` | `/home/<user>/.gemini/config` | Antigravity-Projektkonfiguration |
| `~/.gemini/settings.json` usw. | `/host-gemini/…` → Symlink | Optional: MCP, OAuth und Account-Dateien (falls vorhanden) |
| `~/tools/clipboard-images` (oder `AGENT_SANDBOX_CLIPBOARD_DIR`) | `/home/<user>/clipboard` | Zwischenablage-Bilder vom macOS-Host (nur macOS) |

### Zwischenablage-Bilder (macOS)

**Ziel:** Ein Bild vom Mac (Screenshot, Browser, …) soll im Container
verfügbar sein — z. B. als Dateipfad in einem Claude-Code-Prompt.

Beim Start von `./agent-sandbox.sh` läuft auf macOS automatisch
`clipboard-monitor.sh` im Hintergrund. Sobald du ein Bild mit **Cmd+C** kopierst,
wird es unter `~/tools/clipboard-images` gespeichert und ist im Container unter
`/home/<user>/clipboard/` erreichbar.

Die **Host-Zwischenablage wird beim normalen Kopieren nie verändert** — Copy &
Paste von Bildern auf dem Mac funktioniert uneingeschränkt weiter.

#### Empfohlener Ablauf (4 Schritte)

1. **Sandbox starten** (falls noch nicht aktiv):
   ```bash
   ./agent-sandbox.sh
   ```
   Der Clipboard-Monitor läuft nur, solange die Sandbox gestartet wurde.

2. **Bild auf dem Mac kopieren** — wie gewohnt **Cmd+C** (Screenshot, Browser,
   Vorschau, …). Du musst nichts manuell speichern oder hochladen.

3. **Im Container-Terminal** den Pfad holen:
   ```bash
   clip-path
   ```
   Ausgabe z. B. `~/clipboard/clipboard-image-20260623_221200.png`

4. **Pfad in den Agent-Prompt einfügen**, z. B. in Claude Code:
   ```
   Was siehst du auf diesem Bild?
   ~/clipboard/clipboard-image-20260623_221200.png
   ```

   Statt `clip-path` kannst du auch immer den festen Symlink verwenden:
   ```bash
   ~/clipboard/latest.png    # zeigt auf das zuletzt kopierte Bild
   ```

#### Alternative: Pfad per Cmd+V einfügen (Host-Skript)

Nur nötig, wenn du den Pfad **vom Mac aus** per **Cmd+V** ins Container-Terminal
einfügen willst (z. B. per Tastenkürzel), statt `clip-path` im Container zu tippen.

1. Sandbox läuft, Bild wurde mit **Cmd+C** kopiert (siehe oben).
2. **Auf dem Mac** (zweites Terminal oder Automator-Kurzbefehl):
   ```bash
   clipboard-paste-path
   ```
   Einmalig Symlink anlegen (im Projektverzeichnis):
   `ln -s "$(pwd)/clipboard-paste-path.sh" ~/.local/bin/clipboard-paste-path`
   — siehe auch [Skripte ins PATH legen](#skripte-ins-path-legen).
3. Das Skript gibt eine Zeile aus, z. B.:
   `/home/<user>/clipboard/clipboard-image-20260623_221200.png`
   Gleichzeitig liegt **dieser Text** in der macOS-Zwischenablage.
4. **Im Container-Terminal** **Cmd+V** drücken — der Pfad wird eingefügt.

   Den Terminal-Output musst du nicht extra kopieren; er dient nur zur Kontrolle.
   Den Pfad **nicht auf dem Mac öffnen** — er existiert nur im Container.

#### Wann muss der Container laufen?

| Aktion | Container nötig? |
|--------|------------------|
| `clipboard-paste-path.sh` ausführen | Nein (liest nur eine Datei auf dem Mac) |
| Neues Bild erfassen (Cmd+C) | Ja — Clipboard-Monitor muss laufen |
| Bild/Pfad im Container nutzen | Ja |

#### Anderen Host-Ordner setzen

```bash
export AGENT_SANDBOX_CLIPBOARD_DIR=/pfad/zu/clipboard-images
./agent-sandbox.sh
```

## Hinweise

- Der Container wird mit `--rm` gestartet und nach `exit` automatisch entfernt.
- Der Containername ist `agent-sandbox`.
- Der Claude-Autoupdater ist deaktiviert (`CLAUDE_SKIP_AUTOUPDATER=1`).
- Claude-Code-Credentials liegen isoliert unter `~/.agent-sandbox/home/.claude/`,
  damit der Host-Daemon (`~/.claude/daemon`) die Container-Session nicht
  invalidiert. Beim ersten Start werden vorhandene Credentials von
  `~/.claude/.credentials.json` einmalig übernommen. Skills unter
  `~/.claude/skills/` werden als Symlink nach `/host-claude/skills` eingebunden.
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
