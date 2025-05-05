#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript zum Kapitel „Benutzer‑ und Gruppenkonzept“
#  Zeigt /etc/passwd, /etc/shadow, UID/GID‑Bereiche, Passwort‑Hashes,
#  legt testweise die Gruppe 'workshop' an und fügt User hinzu.
# ----------------------------------------------------------------------

set -euo pipefail

DRY_RUN=0
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=1

banner() { printf '\n\033[1m%s\033[0m\n' "$*"; }

need_root() {
  if (( DRY_RUN )); then
    echo "(dry‑run) $*"
  else
    if (( EUID != 0 )); then
      echo "❌  Diese Aktion erfordert Root‑Rechte. Skript mit sudo ausführen oder --dry-run verwenden." >&2
      exit 1
    fi
    "$@"
  fi
}

########################################################################
banner "1) /etc/passwd & /etc/shadow"
########################################################################

echo "Beispielzeile für Benutzer 'alice' aus /etc/passwd:"
grep '^alice:' /etc/passwd || echo "⚠️  Benutzer 'alice' existiert hier nicht."
echo

echo "Beispielzeile aus /etc/shadow (SHA‑512‑Hash beginnt mit \$6\$):"
if (( DRY_RUN )); then
  echo "(dry‑run) sudo grep '^alice:' /etc/shadow"
else
  sudo grep '^alice:' /etc/shadow 2>/dev/null || echo "  (Kein Eintrag gefunden oder keine Root‑Rechte)"
fi

########################################################################
banner "2) UID‑ und GID‑Bereiche"
########################################################################

printf "%-5s%s\n" "UID" "Verwendung"
printf "%-5s%s\n" "0"   "root – Superuser"
printf "%-5s%s\n" "1‑999" "System‑/Dienstkonten (Distribution‑abhängig)"
printf "%-5s%s\n" "1000+" "Normale Benutzer (Debian/Ubuntu‑Standard)"
echo

echo "Eigene Kennung(en):"
id

########################################################################
banner "3) Passwort‑Hashes verstehen"
########################################################################

cat <<'EOF'
$1$   MD5  (veraltet)
$5$   SHA‑256
$6$   SHA‑512 (Standard)
EOF
echo
echo "Hash‑Wechsel erzwingen (Beispiel): sudo chage -d 0 alice"

########################################################################
banner "4) Geführte Übung – Gruppenverwaltung"
########################################################################

# Schritt 1 – Eigene Gruppen
echo "› id        # UID/GID + Gruppen"
id
echo "› groups    # Nur Gruppennamen"
groups

# Schritt 2 – Gruppe 'workshop' anlegen
banner "Schritt 2 – Gruppe 'workshop' anlegen"
need_root groupadd workshop || true
getent group workshop || echo "❌  Gruppe 'workshop' nicht gefunden."

# Schritt 3 – Benutzer alice bob carol hinzufügen
banner "Schritt 3 – Benutzer der Gruppe hinzufügen"
for user in alice bob carol; do
  echo "Hinzufügen von $user → workshop"
  need_root usermod -aG workshop "$user" || true
done

# Schritt 4 – Änderungen verifizieren
banner "Schritt 4 – Verifizieren"
for user in alice bob carol; do
  echo -n "$user: "
  id "$user" 2>/dev/null | grep -q workshop && echo "✅  workshop" || echo "❌  fehlt (erneut anmelden?)"
done

########################################################################
banner "5) Best Practices"
########################################################################
cat <<'EOS'
• Niemals Passworthashes direkt in /etc/passwd belassen – immer Shadow‑Mechanismus nutzen.
• Gewöhnliche Benutzer sollten UID ≥ 1000 erhalten (Distributionstandard beachten).
• Sekundäre Gruppen gezielt einsetzen, statt Dateien breit mit chmod 777 freizugeben.
• Beim usermod immer -aG verwenden, sonst überschreiben Sie alle bisherigen Gruppen!
• Änderungen an Gruppenmitgliedschaften gelten erst nach neuer Anmeldung oder newgrp.
EOS

echo
banner "Demo abgeschlossen – bei Bedarf erneut mit --dry-run ausführen."
