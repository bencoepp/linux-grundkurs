#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript: Services starten & stoppen mit systemd
#  • zeigt wichtigste systemctl‑Befehle
#  • erklärt Anatomy einer Unit‑Datei + Targets + cgroups‑Infos
#  • erstellt und aktiviert Timer/Service motd.timer
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

run() {                     # run "Titel" "Befehl …"
  local title=$1; shift
  banner "$title"
  if (( DRY_RUN )); then
    echo "(dry‑run) $*"
  else
    echo "+ $*" && eval "$@"
  fi
  echo
}

########################################################################
banner "1) systemctl – wichtigste Befehle (Kurz‑Demo)"

for cmd in \
  "systemctl status sshd.service" \
  "systemctl start sshd.service" \
  "systemctl enable sshd.service" \
  "systemctl is-enabled sshd.service"; do
  run "$cmd" "$cmd | head -n 5"
done

########################################################################
banner "2) Anatomy einer Unit‑Datei (Beispiel ausgeben)"
cat <<'EOS' | indent
[Unit]
Description=Example HTTP Server
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/local/bin/httpd -f /etc/httpd.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOS
echo

########################################################################
banner "3) Targets – moderne Runlevel"
cat <<'EOS' | indent
graphical.target   – GUI + Multi‑User‑Ebene     (ehem. Runlevel 5)
multi-user.target  – Netzwerk‑/Daemon‑Ebene     (ehem. Runlevel 3)
rescue.target      – Single‑User‑Mode, Netzwerk aus
emergency.target   – Minimal‑Shell, keine Mounts
EOS
run "Aktuelles Default‑Target anzeigen" "systemctl get-default"
echo

########################################################################
banner "4) cgroups v2 – Ressourcenkontrolle"
run "cgroup‑Pfad & Stats einer laufenden Unit anzeigen" \
    "systemctl status --no-pager --full sshd.service | grep -A2 'CGroup:'"
echo "Unit‑Option‑Beispiele: MemoryMax=512M, CPUWeight=200" | indent
echo

########################################################################
banner "5) Geführte Übung – motd.timer in Aktion"

# Dateien
SCRIPT="/usr/local/bin/update-motd.sh"
SERVICE="/etc/systemd/system/motd.service"
TIMER="/etc/systemd/system/motd.timer"

# Schritt 1 – MOTD‑Skript
banner "Schritt 1 – Skript $SCRIPT anlegen"
write_script() {
cat <<'EOF'
#!/usr/bin/env bash
echo "Willkommen! $(date)" | tee /etc/motd
EOF
}
if (( DRY_RUN )); then
  echo "(dry‑run) Inhalt von $SCRIPT:"
  write_script | indent
else
  need_root mkdir -p "$(dirname "$SCRIPT")"
  write_script | need_root tee "$SCRIPT" > /dev/null
  need_root chmod +x "$SCRIPT"
fi

# Schritt 2 – Service‑Unit
banner "Schritt 2 – Service‑Unit motd.service schreiben"
write_service() {
cat <<EOF
[Unit]
Description=Generate MOTD

[Service]
Type=oneshot
ExecStart=$SCRIPT
EOF
}
if (( DRY_RUN )); then
  write_service | indent
else
  write_service | need_root tee "$SERVICE" > /dev/null
fi

# Schritt 3 – Timer‑Unit
banner "Schritt 3 – Timer‑Unit motd.timer schreiben"
write_timer() {
cat <<'EOF'
[Unit]
Description=Run MOTD generator 2 min after boot

[Timer]
OnBootSec=2min
Unit=motd.service
Persistent=true

[Install]
WantedBy=timers.target
EOF
}
if (( DRY_RUN )); then
  write_timer | indent
else
  write_timer | need_root tee "$TIMER" > /dev/null
fi

# Schritt 4 – Aktivieren + Starten
banner "Schritt 4 – daemon‑reload, Timer aktivieren & Status"
if (( DRY_RUN )); then
  echo "(dry‑run) systemctl daemon-reload"
  echo "(dry‑run) systemctl enable --now motd.timer"
else
  need_root systemctl daemon-reload
  need_root systemctl enable --now motd.timer
  systemctl list-timers motd.timer
fi
echo

########################################################################
banner "6) Best Practices – Spickzettel"
cat <<'EOS' | indent
• systemd-analyze blame  – listet langsam startende Units.
• journalctl -f -u <unit>  – Live‑Logs nur dieser Unit.
• Ressourcenkontrolle direkt in der Unit (MemoryMax, CPUQuota …) statt ulimit.
• Timer ersetzen cron: OnCalendar=, OnBootSec=, RandomizedDelaySec= … plus Abhängigkeiten.
• Type=oneshot für Skripte, Type=forking für klassische Daemons, Type=notify für sd_notify‑fähige Dienste.
EOS
echo

banner "Demo abgeschlossen – erneut mit --dry-run testen oder mit sudo produktiv ausführen."
