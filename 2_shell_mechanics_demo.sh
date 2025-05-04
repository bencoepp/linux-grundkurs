#!/usr/bin/env bash
###############################################################################
# Shell‑Mechanismen I — Demo‑Skript zum Seminarabschnitt 10:10 – 11:00
#
# Inhalte: 1) Wildcards   2) Quoting   3) Umleitungen   4) Pipelines
#          + zwei Hands‑on‑Übungen
#
# Alle Kommandos laufen in einem selbst erzeugten Arbeitsverzeichnis, damit
# weder echte Log‑Dateien noch Fotos etc. versehentlich geändert oder gelöscht
# werden.  Sie können das Skript gefahrlos mehrfach ausführen oder später
# einzelne Teile im Seminar Schritt für Schritt zeigen.
###############################################################################

set -euo pipefail             # Saubere Fehlerbehandlung
shopt -s nullglob             # Leere Globs expandieren zu "", nicht zum Pattern
WORKDIR=$(mktemp -d)          # tmp‑Verzeichnis anlegen
trap 'rm -rf "$WORKDIR"' EXIT # Aufräumen bei (auch vorzeitiger) Beendigung
echo "Arbeitsverzeichnis: $WORKDIR"
cd "$WORKDIR"

###############################################################################
# 0. Helfer:  Kommando + Ausgabe hübsch drucken
###############################################################################
run() {                       # Erst Kommando anzeigen, dann ausführen
  printf '\n$ %s\n' "$*"
  "$@"
}

###############################################################################
# 1. Wildcards (Globbing)
###############################################################################
echo -e "\n=== 1. Wildcards ==="

# Demo‑Daten
touch img_{01..09}.jpg photo_{10..29}.raw IMG_2025-05-{01..09}.png

run ls *.jpg                  # * steht für beliebig viele Zeichen
run ls IMG_2025-05-0?.png     # ? ersetzt genau ein Zeichen
run echo photo_[12][0-9].raw  # eckige Klammern = Zeichenklassen
run rm photo_[12][0-9].raw    # Achtung: hier wird wirklich gelöscht (nur Demo‑Dateien)

# Range vor Expansion schützen
run echo "*.log"              # Anführungszeichen verhindern Globbing

###############################################################################
# 2. Quoting
###############################################################################
echo -e "\n=== 2. Quoting ==="

VAR="Seminar"
run echo Pfad unquoted: $PWD          # alles wird expandiert
run echo "Pfad in double quotes: $PWD" # Globbing AUS, $‑Variablen AN
run echo 'Regex: ^[0-9]\{3\}$'        # single quotes ➜ nichts wird ausgewertet
run echo "Preis: 50\€"                # Backslash maskiert genau ein Zeichen

###############################################################################
# 3. Umleitungen
###############################################################################
echo -e "\n=== 3. Umleitungen ==="

# Wir nutzen 'echo' statt echter Compiler‑Ausgabe, um Warnungen zu erzeugen
run echo "Test‑Warnung" > warn.log           # stdout überschreibt Datei
run echo "Zweite Zeile" >> warn.log          # stdout anhängen
run echo "Fehlernachricht" 1>/dev/null 2>err # stderr in Datei, stdout verworfen
run echo "Alles in eine Datei" &> both.log   # stdout UND stderr

# Klassisches Muster: stdout zuerst, dann stderr anhängen
run bash -c 'echo OUT; echo ERR >&2' > all.out 2>&1

# Beispiel A aus den Folien, simuliert mit echo + sleep
run bash -c 'echo OBJ erstellt; sleep 1; echo WARN >&2' \
     2> build.err | tee build.out             # gleichzeitiges Protokollieren

###############################################################################
# 4. Pipelines
###############################################################################
echo -e "\n=== 4. Pipelines ==="

# a) journalctl kann root erfordern – wir simulieren mit dmesg
if command -v journalctl &>/dev/null; then
  run bash -c 'journalctl -k | less -FX'     # bevorzugt: systemd‑Log
else
  run bash -c 'sudo dmesg | less -FX'        # Fallback mit sudo
fi

# b) Prozessliste filtern, grep sich selbst ausschließen
run ps aux | grep '[b]ash' | head

# c) Größte Dateien anzeigen – wir erzeugen zuvor Demo‑Dateien
dd if=/dev/zero of=big1 bs=1M count=2 status=none
dd if=/dev/zero of=big2 bs=1M count=3 status=none
run du -ah . | sort -h | tail -n 5

###############################################################################
# Hands‑on 1: *.log größer als 1 MB finden und komprimieren
###############################################################################
echo -e "\n=== Übung 1 – große Logs komprimieren ==="

# Wir legen Beispieldateien an: 500 kB und 2 MB
dd if=/dev/zero of=small.log bs=1k count=500 status=none
dd if=/dev/zero of=large.log bs=1M count=2 status=none

echo "— Treffer vorab kontrollieren —"
run find . -type f -name '*.log' -size +1M -print

echo "— Variante 1: -each exec —"
run find . -type f -name '*.log' -size +1M -exec gzip {} \;

echo "— Variante 2: xargs —"
dd if=/dev/zero of=large2.log bs=1M count=3 status=none   # weitere Beispieldatei
run find . -type f -name '*.log' -size +1M -print0 | xargs -0 gzip

###############################################################################
# Hands‑on 2: Pipeline-Analyse passwd‑Datei
###############################################################################
echo -e "\n=== Übung 2 – Pipeline analysieren ==="

echo "# Lange Form:"
run bash -c 'cat /etc/passwd | grep /bin/bash | wc -l'

echo "# Ressourcenschonend:"
run grep -c '/bin/bash' /etc/passwd

###############################################################################
# Abschluss
###############################################################################
echo -e "\nDemo beendet.  Arbeitsverzeichnis bleibt bis Skriptende erhalten:"
echo "  $WORKDIR"
echo "(wird durch trap nach EXIT automatisch entfernt)"
