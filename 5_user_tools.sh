#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript zum Kapitel „Werkzeuge der Benutzerverwaltung“
#  Behandelt useradd, usermod, passwd, chage, gpasswd und zeigt
#  ein Provisionierungs‑Szenario (create_students.sh).
# ----------------------------------------------------------------------

set -euo pipefail

DRY_RUN=0
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=1

banner()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
indent()  { sed 's/^/    /'; }

run() {
  # run "Kommentar" "Befehl ..."
  local msg=$1; shift
  banner "$msg"
  if (( DRY_RUN )); then
    echo "(dry‑run) $*"
  else
    echo "+ $*" && eval "$@"
  fi
  echo
}

need_root() {
  if (( DRY_RUN )); then
    echo "(dry‑run) $*"
  else
    if (( EUID != 0 )); then
      echo "❌  Diese Aktion erfordert Root‑Rechte.  Skript mit sudo ausführen oder --dry-run verwenden." >&2
      exit 1
    fi
    "$@"
  fi
}

########################################################################
run "1) Konten anlegen – useradd (Standard‑Syntax zeigen)" \
    "echo 'sudo useradd -m -s /bin/bash -c \"Vollname\" loginname'"

if ! (( DRY_RUN )); then
  banner "useradd -D (Default‑Einstellungen aus /etc/default/useradd)"
  useradd -D | indent
fi

########################################################################
run "2) Konten ändern – usermod" \
    "echo 'sudo usermod -aG docker,video alice  &&  sudo usermod -s /usr/bin/zsh alice'"

########################################################################
banner "3) Passwörter verwalten – passwd & chage"
if (( DRY_RUN )); then
  echo "(dry‑run) Beispiele:"
else
  echo "Beispiel‑Befehl (Passwort sofort ablaufen lassen):"
fi
cat <<'EOF' | indent
# interaktiver Wechsel
sudo passwd alice

# Passwort ablaufen lassen → Benutzer muss es ändern
sudo passwd -e alice

# Maximal 90 Tage gültig, 7 Tage Vorwarnung
sudo chage -M 90 -W 7 alice

# Aktuelle Alterungs‑Parameter anzeigen
sudo chage -l alice
EOF
echo

########################################################################
banner "4) Gruppen pflegen – gpasswd"
cat <<'EOF' | indent
sudo gpasswd -A alice project   # alice wird Admin (Gruppenbesitzer)
sudo gpasswd -a bob project     # bob hinzufügen
sudo gpasswd -a carol project   # carol hinzufügen
getent group project            # Mitgliederliste prüfen
EOF
echo

########################################################################
banner "5) Skript‑basierte Provisionierung – Demo"
cat <<'EOS' | indent
Typischer Ablauf in einem Provisionierungs‑Skript:
  1. Prüfen, ob Konto schon existiert        (id / getent passwd)
  2. Benutzer anlegen                        (useradd)
  3. Startpasswort setzen                    (chpasswd oder passwd --stdin)
  4. Passwort sofort ablaufen lassen         (passwd -e  ODER  chage -d 0)
  5. Zusätzliche Gruppen, Ablaufdatum etc.   (usermod / chage / gpasswd)
EOS
echo

########################################################################
banner "6) Geführte Übung – create_students.sh automatisch erzeugen + ausführen"

WORKDIR=$(mktemp -d)
STUDENT_SCRIPT="$WORKDIR/create_students.sh"

cat >"$STUDENT_SCRIPT" <<'STUDENT'
#!/usr/bin/env bash
#
# Erstellt drei studentische Konten mit Startpasswort und
# erzwingt Passwortwechsel beim ersten Login.
# Aufruf: sudo ./create_students.sh

set -euo pipefail
students=(student1 student2 student3)
initial_pw='Start123!'

for u in "${students[@]}"; do
  if id "$u" &>/dev/null; then
    echo "Konto $u existiert bereits – überspringe."
    continue
  fi

  echo "➕  Erstelle $u …"
  useradd -m -U -s /bin/bash -c "Workshop-Teilnehmer $u" "$u"
  echo "$u:$initial_pw" | chpasswd
  passwd -e "$u"    # Passwort sofort ablaufen lassen
done
STUDENT

chmod +x "$STUDENT_SCRIPT"
echo "Skript wurde in $STUDENT_SCRIPT erzeugt."

if (( DRY_RUN )); then
  echo "(dry‑run) Würde jetzt: sudo $STUDENT_SCRIPT"
else
  need_root "$STUDENT_SCRIPT"
fi
echo

########################################################################
banner "7) Best Practices"
cat <<'EOS' | indent
• Verwenden Sie immer -m und -s bei useradd, um Home‑Dir + Shell zu setzen.
• Mit -U erstellt useradd automatisch eine primäre Gruppe gleichen Namens.
• Bei usermod: -aG NIE ohne -a benutzen, sonst werden bestehende Gruppen ersetzt.
• Passwörter niemals als Klartext in Skripten belassen – chpasswd liest sicher von stdin.
• chage / passwd -e einsetzen, um erzwungene Passwortwechsel zu automatisieren.
• gpasswd ist der bequeme Weg, Admin‑/Mitgliedsrollen in Gruppen zu pflegen.
• Provisionierungs‑Skripte sollten id/getent nutzen, um idempotent zu bleiben.
EOS
echo

banner "Demo abgeschlossen – erneut mit --dry-run testen oder mit sudo produktiv ausführen."
