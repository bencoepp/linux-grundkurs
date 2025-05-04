#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript: PAM‑Architektur & Security‑Demo
#  Behandelt Anatomie einer PAM‑Zeile, wichtige Module,
#  Login‑Versuchsbegrenzung (pam_tally2) und Ressourcengrenzen (pam_limits).
# ----------------------------------------------------------------------

set -euo pipefail

DRY_RUN=0
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=1

banner()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
indent()  { sed 's/^/    /'; }

need_root() {
  if (( DRY_RUN )); then
    echo "(dry‑run) $*"
  else
    if (( EUID != 0 )); then
      echo "❌  Root‑Rechte benötigt – Skript mit sudo ausführen oder --dry-run verwenden." >&2
      exit 1
    fi
    "$@"
  fi
}

patch_file() {         # patch_file <datei> <suchmuster> <neue_zeile>
  local file=$1 pattern=$2 newline=$3
  grep -qF -- "$newline" "$file" && return 0
  if (( DRY_RUN )); then
    echo "(dry‑run) würde einfügen: $newline"
  else
    need_root cp "$file" "${file}.orig.$(date +%s)"
    need_root awk -v pat="$pattern" -v ins="$newline" '
      BEGIN {done=0}
      {print}
      !done && $0 ~ pat {print ins; done=1}
    ' "$file" | need_root tee "$file" > /dev/null
  fi
}

########################################################################
banner "1) Anatomie einer PAM‑Zeile"
cat <<'EOS' | indent
Typ   Control‑Flag   Modulname   Optionen
-----------------------------------------
auth  required       pam_unix.so try_first_pass nullok
EOS
echo

########################################################################
banner "2) Wichtige Module"
cat <<'EOS' | indent
• pam_unix.so    – Authentifizierung gegen /etc/passwd & /etc/shadow
• pam_limits.so  – Ressourcengrenzen aus /etc/security/limits.conf anwenden
• pam_tally2.so  – Fehlversuche zählen, Konten sperren (legacy, aber gängig)
EOS
echo

########################################################################
banner "3) Demo – Fehlversuche begrenzen (pam_tally2)"
SSH_PAM="/etc/pam.d/sshd"
LINE_AUTH='auth required pam_tally2.so onerr=fail deny=5 unlock_time=900'
if [[ -f "$SSH_PAM" ]]; then
  echo "Datei: $SSH_PAM"
  patch_file "$SSH_PAM" '^auth' "$LINE_AUTH"
  if (( DRY_RUN )); then
    echo "(dry‑run) würde sshd neu laden"
  else
    need_root systemctl reload sshd
  fi
  cat <<'EOT' | indent
Test: 5× falsches Passwort → Konto gesperrt
Status eines Users prüfen:
  sudo pam_tally2 --user alice
  sudo faillock --user alice     # je nach Distribution
EOT
else
  echo "⚠️  $SSH_PAM nicht gefunden – vermutlich kein OpenSSH‑Server installiert."
fi
echo

########################################################################
banner "4) Demo – Ressourcengrenzen (pam_limits.so)"
LIMITS="/etc/security/limits.conf"
LINE1='@workshop hard nproc  100'
LINE2='@workshop hard nofile 4096'
LINE3='@workshop soft core   0'
for L in "$LINE1" "$LINE2" "$LINE3"; do
  patch_file "$LIMITS" '^@workshop' "$L"
done
cat <<'EOS' | indent
Änderungen greifen bei neuer Sitzung
  → SSH neu einloggen oder: newgrp workshop
Prüfen:
  ulimit -a
EOS
echo

########################################################################
banner "5) Gruppen‑Challenge (Erinnerung)"
cat <<'EOS' | indent
Ziel A – Fehlversuche limitieren
  auth required pam_tally2.so deny=5 onerr=fail unlock_time=600
  sudo systemctl reload sshd

Ziel B – Limits für Gruppe workshop
  @workshop hard nproc   120
  @workshop hard nofile  2048
  @workshop soft memlock 256000
  → neue SSH‑Sitzung, dann ulimit -a
EOS
echo

########################################################################
banner "6) Best Practices & Fehlersuche"
cat <<'EOS' | indent
• Immer Backup der PAM‑Datei anlegen (cp /etc/pam.d/xyz xyz.orig).
• Reihenfolge im PAM‑Stack ist kritisch – Zeile immer direkt unter erstem auth‑Eintrag einfügen.
• /etc/security/limits.conf: Syntax strikt einhalten; Tippfehler blockieren Login nicht, führen aber zu stiller Ignoranz.
• Fehlerdiagnose: /var/log/auth.log  bzw. journalctl -u sshd.
• pam_tally2 zählt nur fehlgeschlagene Authentifizierungen via PAM‑fähige Dienste.
• Nach unlock_time Konten automatisch frei – manuell mit pam_tally2 ‑‑user <u> ‑‑reset.
EOS
echo

banner "Demo abgeschlossen – erneut mit --dry-run testen oder mit sudo produktiv ausführen."
