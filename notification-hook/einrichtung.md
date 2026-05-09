# Notification Hook für Claude Code in der Docker Sandbox aufsetzen

## Audio in der HAV Environment einrichten (außerhalb der Docker Sandbox)

### 1. Skript zur Installation von `PipeWire` ausführen

```bash
chmod +x setup-xrdp-audio-pipewire-hav-env.sh
./setup-xrdp-audio-pipewire-hav-env.sh
```

### 2. RDP beenden und neu verbinden

```bash
pactl info | grep -E 'Server Name|Default Sink|Default Source'
pactl list short sinks
speaker-test -t wav -c 2 # Test
```

---

## 3. `settings.json` in `.claude` öffnen (in der Hav Environment) -> Bitte exakt übernehmen

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "paplay /home/vagrant/Documents/BELLDoor_Doorbell.wav"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "paplay /home/vagrant/Documents/BELLDoor_Doorbell.wav"
          }
        ]
      }
    ]
  }
}
```

---

## Lautstärke einstellen / prüfen (immer nur in der Hav Environment)

### Einstellen

```bash
pactl set-sink-volume @DEFAULT_SINK@ 50%
```

### Prüfen

```bash
pactl get-sink-volume @DEFAULT_SINK@
```

### Stumm / Laut schalten

```bash
pactl set-sink-mute @DEFAULT_SINK@ toggle
```

oder gezielt

```bash
pactl set-sink-mute @DEFAULT_SINK@ 1   # stumm
pactl set-sink-mute @DEFAULT_SINK@ 0   # nicht stumm
```