#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript zum Kapitel „Shell‑Mechanismen II“
#  Zeigt Variablen‑Handhabung, Umgebungsvariablen, Kommando‑Substitution
#  und führt die Übung „diskfree.sh“ automatisiert aus.
# ----------------------------------------------------------------------

set -euo pipefail

banner() { printf '\n\033[1m%s\033[0m\n' "$*"; }

########################################################################
banner "1) Variablen und Umgebungsvariablen"
########################################################################

# Lokale Variable
NAME=alice
echo "Lokale Variable gesetzt: NAME=alice"
echo "echo \"\$NAME\" → $NAME"

# Exportieren
export NAME
echo "Nach dem Export (env | grep ^NAME):"
env | grep ^NAME

# Stolperfalle 1 – Leerzeichen
banner "Stolperfalle 1 – Leerzeichen in Variablenwerten"
echo 'FALSCH  : GREETING=Hello World     # World würde als Befehl interpretiert!'
echo 'RICHTIG : GREETING="Hello World"'
GREETING="Hello World"
echo "GREETING=\"Hello World\" → \"$GREETING\""

# Stolperfalle 2 – PATH
banner "Stolperfalle 2 – \$PATH prüfen"
echo "Aktueller PATH, zeilenweise:"
echo "$PATH" | tr ':' '\n'
echo "Fehlt z. B. \$HOME/bin?  Dann ergänzen Sie mit:"
echo '  export PATH="$PATH:$HOME/bin"'

########################################################################
banner "2) Kommando‑Substitution"
########################################################################

NOW=$(date '+%F %T')
echo "NOW=\$(date '+%F %T') → $NOW"
echo "Direkt eingebettet: Es ist jetzt $(date '+%H:%M Uhr am %d.%m.%Y')."

########################################################################
banner "3) Geführte Übung: diskfree.sh"
########################################################################

# Wir arbeiten in einem temporären Verzeichnis, um nichts zu überschreiben
WORKDIR=$(mktemp -d)
echo "Arbeitsverzeichnis: $WORKDIR"

cat <<'EOF' >"$WORKDIR/diskfree.sh"
#!/usr/bin/env bash
#
# Zeigt Datum und freie Plattenkapazität der Root‑Partition an

NOW=$(date '+%F %T')
echo "Stand: $NOW"
df -h /
EOF

chmod +x "$WORKDIR/diskfree.sh"
echo "Skript diskfree.sh wurde angelegt und ausführbar gemacht:"
ls -l "$WORKDIR/diskfree.sh"

echo
echo "Ausgabe von diskfree.sh:"
"$WORKDIR/diskfree.sh"

echo
echo "So machen Sie das Skript dauerhaft verfügbar:"
cat <<'EOS'
mkdir -p ~/bin
mv diskfree.sh ~/bin/          # oder cp, falls Sie es behalten wollen
export PATH="$PATH:$HOME/bin"  # temporär – für dauerhaft in ~/.bashrc einfügen
EOS

########################################################################
banner "4) Zusammenfassung & Best Practices"
########################################################################
cat <<'EOS'
• Variablen ohne Leerzeichen um das „=“ setzen; Werte mit Leerzeichen immer in Anführungszeichen.
• Mit „export“ gelangen Variablen in die Umgebung von Kindprozessen.
• Prüfen Sie Ihren $PATH, damit eigene Skripte gefunden werden.
• Kommando‑Substitution $(...) fängt Befehlsausgaben ab.
• Legen Sie eigene Hilfsskripte (z. B. diskfree.sh) in ~/bin ab und erweitern Sie den PATH.
EOS

echo
banner "Demo abgeschlossen – viel Erfolg beim Ausprobieren!"
