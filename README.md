# agent-sandbox

Containerisierte Entwicklungsumgebung mit Java, Maven, Node.js und Agent-CLIs.

## Enthalten

- Debian 12 Slim
- Java (Amazon Corretto 25) via SDKMAN
- Maven 3.9.9 via SDKMAN
- Node.js 22
- Claude Code CLI (`@anthropic-ai/claude-code`)
- OpenAI Codex CLI (`@openai/codex`)
- Cursor Agent CLI (`curl https://cursor.com/install -fsS | bash`)
- GitHub Copilot CLI (`@github/copilot`)

## Voraussetzungen

- Docker
- `~/.gitconfig`

Das persistente Container-Home `~/.agent-sandbox/home` und die
Konfigurationsverzeichnisse `~/.claude`, `~/.codex`, `~/.agents`, `~/.copilot`
und `~/.cursor` werden beim Start automatisch angelegt, falls sie noch nicht
existieren.

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
Agenten liegt separat unter `/tmp/agent-home` und wird auf dem Host unter
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
| `~/.agent-sandbox/home` | `/tmp/agent-home` | Persistentes Container-Home |
| `~/.gitconfig` | `/tmp/host.gitconfig` | Git-Konfiguration, read-only |
| `~/.claude` | `/tmp/agent-home/.claude` | Claude-Konfiguration |
| `~/.codex` | `/tmp/agent-home/.codex` | Codex-Konfiguration |
| `~/.agents` | `/tmp/agent-home/.agents` | Agent-Konfiguration und Skills |
| `~/.copilot` | `/tmp/agent-home/.copilot` | GitHub-Copilot-Konfiguration |
| `~/.cursor` | `/tmp/agent-home/.cursor` | Cursor-Konfiguration |

## Hinweise

- Der Container wird mit `--rm` gestartet und nach `exit` automatisch entfernt.
- Der Containername ist `agent-sandbox`.
- Der Claude-Autoupdater ist deaktiviert (`CLAUDE_SKIP_AUTOUPDATER=1`).
- `HOME`, `HISTFILE` und die XDG-Verzeichnisse zeigen auf `/tmp/agent-home`.
  Dadurch landen `.bash_history`, `.cache`, `.local`, `.npm` und
  Claude-Home-Dateien nicht mehr in `/workspace`, bleiben aber unter
  `~/.agent-sandbox/home` erhalten.
- npm-Cache und npm-Logs liegen im Container unter `/tmp`, damit Agent-CLIs
  keine npm-Logdateien im gemounteten Projektverzeichnis erzeugen.
- Die Agent-CLIs starten im YOLO-Modus:
  `claude --dangerously-skip-permissions`,
  `codex --dangerously-bypass-approvals-and-sandbox`,
  `copilot --yolo` und
  `cursor-agent`/`agent --yolo --sandbox disabled --approve-mcps`.
- Die Zeitzone ist auf `Europe/Berlin` gesetzt.
