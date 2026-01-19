# Code-Review: userscripts

## Kritische Probleme

### update-local.sh

- [ ] **Partial Upgrade Risiko (Zeile 112-113)**: `pacman -Sy` ohne `-u` kann auf Arch zu Partial-Upgrade-Problemen führen. `yay -Sy` ebenso. Besser komplett weglassen oder nur `-Syu` verwenden.

  ** Chris **: Danke für den Hinweis... die Idee sollte hier eigentlich sein, entweder "nur" Update oder eben mit Package-Sync... können wir das so umstellen?

- [ ] **Fehler werden verschluckt (Zeilen 112-113, 118-119)**: `|| true` nach pacman/yay-Befehlen verhindert, dass Fehler erkannt werden. Besser: Fehler loggen oder gezielt nur bestimmte Exit-Codes ignorieren.

  ** Chris **: Loggen wäre gut... im Prinzip ist das nicht unbedingt kritisch, dass die Updates ausgeführt werden - wenn es mal hakt, dann... ok, hakt es halt, dann macht man es 30 Minuten später nochmal. Hintergrund ist hier: CachyOS - das ist noch nicht ganz 100% stabil von den Paketquellen her.

- [ ] **Keine Lock-Datei**: Parallele Ausführung könnte zu Race Conditions führen (z.B. pacman-Datenbank-Locks, doppelte Installationen).

  ** Chris **: Gefällt mir - sofern es möglich ist, dass diese Lock-Datei wirklich zuverlässig von selbst verschwindet.

### setup-local.sh

- [ ] **Config wird immer gelöscht (Zeile 35-37)**: `rm "$config_file" || true` ist nicht idempotent. Bei versehentlicher Mehrfach-Ausführung gehen Einstellungen verloren, ohne dass der User es merkt.

  ** Chris **: Können wir das ersetzen durch Anzeige der Datei (`cat` reicht eigentlich) und Frage "Konfiguration beibehalten?"

- [ ] **yay-Abhängigkeit nicht geprüft (Zeile 69)**: `yay` wird verwendet, aber es wird nicht geprüft, ob es installiert ist. Script bricht ab falls yay fehlt.

  ** Chris **: *sollte* eigentlich funktionieren, Pre-Installer-Script für das OS stellt Installation von `yay` sicher - aber wir könnten das auch hier einbauen, das stimmt.

### update-lazyvim.sh

- [ ] **`set -euo pipefail` fehlt**: Fehler werden nicht abgefangen.

  ** Chris **: Großes "ups" - habe ich vergessen

- [ ] **Unsicheres `cd` (Zeile 9)**: Wenn `~/.config/nvim` nicht existiert oder cd fehlschlägt, wird `git pull` im falschen Verzeichnis ausgeführt.

  ** Chris **: Ok, aber wie macht man `cd` sicher?

- [ ] **nvim-Existenz nicht geprüft**: Script könnte fehlschlagen wenn neovim nicht installiert ist.

  ** Chris **: Kann man das sicher prüfen? Evtl. Abfrage, ob `nvim` als Kommando funktioniert, oder?

---

## Idempotenz-Probleme

### update-local.sh

- [ ] **Keychron-Rules (Zeile 144-145)**: Rules werden bei jedem Lauf neu geschrieben. Besser: Nur schreiben wenn Inhalt unterschiedlich ist.

  ** Chris **: Ok, wenn möglich, ohne, dass es an Zuverlässigkeit verliert - Hintergrund: ist mir ziemlich wichtig diese Funktion

- [ ] **journald.conf (Zeile 152)**: Config wird bei jedem Lauf neu geschrieben und journald neu gestartet. Prüfung auf bestehende Config fehlt.

  ** Chris **: Wie bei Keychron-Rules

- [ ] **hyprwalz (Zeilen 122-127)**: Wird bei jedem Lauf komplett neu geklont und installiert, auch wenn bereits aktuell. Keine Version-Prüfung.

  ** Chris **: Zu meiner Schande muss ich gestehen, dass `hyprwalz` noch keine Versionierung hat... belassen wir das vorerst so, aber Danke für den Hinweis, ich will es ohnehin in die AUR geben beizeiten

### setup-local.sh

- [ ] **docker-Gruppe (Zeile 75)**: `groupadd docker || true` ist okay, aber `getent group docker >/dev/null || sudo groupadd docker` wäre sauberer.Datei

  ** Chris **: Ui ja, das gefällt mir WEITAUS besser!

- [ ] **ssh-agent (Zeilen 56-61)**: `systemctl --user daemon-reexec` vor `daemon-reload` ist unübliche Reihenfolge. Normalerweise erst `reload`, dann bei Bedarf `reexec`.

  ** Chris **: Ja, bitte ändern

### sddm-theme.sh

- [ ] **Theme-Config (Zeile 87)**: Wird immer geschrieben, auch wenn das gewählte Theme bereits aktiv ist. Keine Änderungsprüfung.

  ** Chris **: Ja, können wir umstellen

---

## Potentielle Fallstricke

### update-local.sh

- [ ] **chezmoi update --force (Zeile 191)**: Überschreibt lokale Änderungen ohne Warnung. Kein Diff wird vorher angezeigt.

  ** Chris **: Ist absolut Absicht. Hintergrund: zwar sind meine eigenen Dotfiles als Overlay für end-4 gedacht, aber an zwei oder drei Stellen muss ich bestehende Dateien von end-4 überschreiben (Grund: so Sachen wie `hypridle` - die haben dafür leider keinen User-Hook, nur diese eine Lock-Datei)

- [ ] **git stash -u || true (Zeile 201)**: Verschluckt Fehler. Falls stash fehlschlägt, könnte `git pull` Konflikte verursachen.

  ** Chris **: Hm, können wir da an dieser Stelle das `git stash` noch mehr forcieren? Damit es wirklich um jeden Preis gemacht wird? Ist wirklich Absicht!

- [ ] **pushd/popd ohne Fehlerbehandlung (Zeilen 200, 204)**: Falls pushd fehlschlägt, wird popd das falsche Verzeichnis verlassen.

  ** Chris **: Ich habe leider keine Vorstellung davon, wie man hier Fehler behandeln könnte, aber wenn das möglich ist: ja gern!

- [ ] **UV_VENV_CLEAR=1 (Zeile 203)**: Löscht Python-venv ohne Backup oder Warnung.

  ** Chris **: Ist Absicht - liegt am Installer von end-4, der das auch vorschlägt

### sddm-theme.sh

- [ ] **awk auf *.conf (Zeile 28)**: Bei mehreren .conf-Dateien könnte das Ergebnis unvorhersehbar sein (Reihenfolge abhängig von Dateinamen-Sortierung).

  ** Chris **: Ja, darüber habe ich auch schon nachgedacht, aber wie können wir das wirklich lösen? Bin eigentlich derzeit zufrieden, heben wir uns das für später auf

- [ ] **99 Themes Limit (Zeile 53-56)**: Arbiträres Limit. Besser: fzf oder ähnliches für große Listen verwenden.

  ** Chris **: `fzf` wäre einfach nur genial! Bitte das machen!

### translate (Python)

- [ ] **Kein Timeout bei subprocess.run (Zeile 61)**: `dict`-Befehl könnte hängen bleiben. Besser: `timeout=10` setzen.

  ** Chris **: Ja bitte!

- [ ] **Keine Prüfung ob dictd-Daemon läuft**: Fehler erst bei Ausführung sichtbar.

  ** Chris **: Ja bitte!

### setup-local.sh

- [ ] **Netzwerk-Abhängigkeit (Zeile 70)**: `flatpak remote-add` kann fehlschlagen wenn Netzwerk nicht verfügbar. Keine Retry-Logik.

  ** Chris **: Ja bitte!

---

## Verbesserungsvorschläge

### Allgemein

- [ ] **Lock-Mechanismus**: Für setup-local.sh und update-local.sh eine Lock-Datei verwenden (`flock` oder ähnlich), um parallele Ausführung zu verhindern.

  ** Chris **: Ja bitte, aber siehe oben: muss zuverlässig entfernt werden auch wenn das Script abgebrochen wird

- [ ] **Logging-Option**: `--verbose` oder `--log` Flag für Debug-Ausgaben in eine Datei.

  ** Chris **: Gute Idee, ja!

- [ ] **Dry-Run-Modus**: `--dry-run` Flag um zu sehen was passieren würde, ohne Änderungen vorzunehmen.

  ** Chris **: Ja, bitte!

- [ ] **Gemeinsame Library**: Wiederkehrende Funktionen (ask, extract_packages, Root-Check) in eine gemeinsame `lib.sh` auslagern.Datei

  ** Chris **: Ui ja, das gefällt mir! Ich wollte ohnehin immer schon wissen, wie das in Shell-Scripts funktioniert

- [ ] **Konsistente Fehlerbehandlung**: Einheitliche Error-Handler-Funktion mit Cleanup.

  ** Chris **: Ja, bitte!

### update-local.sh

- [ ] **Diff vor chezmoi update**: Vor `chezmoi update --force` ein `chezmoi diff` anzeigen und User bestätigen lassen (außer bei `--force` Flag).

  ** Chris **: Nein, ich sehe `chezmoi` hier als sehr striktes "ich forciere überall den gleichen Stand"-Tool

- [ ] **Backup vor hyprwalz**: Prüfen ob hyprwalz bereits installiert ist und nur updaten statt komplett neu zu installieren.

  ** Chris **: Derzeit keine Versionierung bei `hyprwalz`

- [ ] **sudo-Timeout-Refresh**: Am Anfang des Scripts einmal `sudo -v` und dann periodisch refreshen, statt viele einzelne sudo-Aufrufe.

  ** Chris **: Das klingt hervorragend

- [ ] **Atomic Config-Writes**: Keychron-Rules und journald.conf mit `cmp -s` prüfen bevor neu geschrieben wird:
  ```bash
  new_content='SUBSYSTEM=="hidraw"...'
  if [[ ! -f "$file" ]] || [[ "$(cat "$file")" != "$new_content" ]]; then
    echo "$new_content" | sudo tee "$file" >/dev/null
  fi

  ** Chris **: Ui, ja!

### update-lazyvim.sh

- [ ] **Robuster machen**:
  ```bash
  set -euo pipefail
  nvim_dir="$HOME/.config/nvim"
  if [[ ! -d "$nvim_dir" ]]; then
    git clone https://github.com/LazyVim/starter "$nvim_dir"
  fi
  cd "$nvim_dir" && git pull
  command -v nvim >/dev/null && nvim --headless "+Lazy! sync" +qa
  ```

### setup-local.sh

- [ ] **Config-Migration statt Löschen**: Bestehende Config einlesen und nur fehlende Werte erfragen, statt alles zu löschen.

  ** Chris **: Ja bitte!

- [ ] **yay-Installation anbieten**: Falls yay fehlt, anbieten es zu installieren (via `pacman -S --needed base-devel git && git clone ... && makepkg -si`).

  ** Chris **: Nicht anbieten, einfach machen :-)

### sddm-theme.sh

- [ ] **Keine Änderung bei gleichem Theme**: Vor dem Schreiben prüfen ob das Theme bereits aktiv ist und dann abbrechen mit "Theme already set".

  ** Chris **: Ja, bitte!

### translate

- [ ] **dictd-Status prüfen**:
  ```python
  result = subprocess.run(["systemctl", "is-active", "dictd"], capture_output=True)
  if result.returncode != 0:
      print("Warning: dictd service not running", file=sys.stderr)

  ** Chris **: Ja, bitte!

  ```
- [ ] **Timeout hinzufügen**: `subprocess.run(..., timeout=10)`

  ** Chris **: Ja, bitte!

---

## Nice-to-Have

- [ ] **Versionierung**: Versionsnummer in den Scripts, `--version` Flag.

  ** Chris **: noch nicht - ist alles noch sehr früh "Alpha"

- [ ] **CHANGELOG.md**: Änderungshistorie dokumentieren.

  ** Chris **: noch nicht - Alpha!

- [ ] **Shellcheck CI**: `.shellcheckrc` und automatische Prüfung.

  ** Chris **: Ja, das gefällt mir!

- [ ] **Bash-Completion**: Tab-Completion für Flags von update-local.sh.Datei

  ** Chris **: System verwendet `fish`

- [ ] **Notification nach Abschluss**: Optional Desktop-Notification wenn lange laufende Updates fertig sind (`notify-send`).

  ** Chris **: Großartige Idee!
