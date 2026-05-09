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

Die Konfigurationsverzeichnisse `~/.claude`, `~/.codex`, `~/.agents`,
`~/.copilot` und `~/.cursor` werden beim Start automatisch angelegt, falls sie
noch nicht existieren.

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

Im Container ist `/workspace` das Arbeitsverzeichnis und gleichzeitig das
Home-Verzeichnis (`HOME=/workspace`).

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
| `~/.gitconfig` | `/workspace/.gitconfig` | Git-Konfiguration, read-only |
| `~/.claude` | `/workspace/.claude` | Claude-Konfiguration |
| `~/.codex` | `/workspace/.codex` | Codex-Konfiguration |
| `~/.agents` | `/workspace/.agents` | Agent-Konfiguration und Skills |
| `~/.copilot` | `/workspace/.copilot` | GitHub-Copilot-Konfiguration |
| `~/.cursor` | `/workspace/.cursor` | Cursor-Konfiguration |

## Hinweise

- Der Container wird mit `--rm` gestartet und nach `exit` automatisch entfernt.
- Der Containername ist `agent-sandbox`.
- Der Claude-Autoupdater ist deaktiviert (`CLAUDE_SKIP_AUTOUPDATER=1`).
- Die Zeitzone ist auf `Europe/Berlin` gesetzt.
