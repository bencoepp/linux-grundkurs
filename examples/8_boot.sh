#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript: Linux‑Boot‑Vorgang (UEFI → GRUB → Kernel → systemd)
#  • erklärt die vier Boot‑Phasen
#  • misst Boot‑Zeit via systemd‑analyze, erzeugt Boot‑SVG
#  • klont Menüeintrag ohne 'quiet' in /etc/grub.d/40_linux_verbose
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

run() {                        # run "Titel" "Befehl …"
  local title=$1; shift
  banner "$title"
  if (( DRY_RUN )); then
    echo "(dry‑run) $*"
  else
    echo "+ $*" && eval "$@"
  fi
  echo
}

# ----------------------------------------------------------------------
banner "1) Vier Phasen des Linux‑Boot‑Prozesses"
cat <<'EOS' | indent
1. UEFI‑Firmware
     • liest BootOrder, startet EFI‑Binary (shimx64.efi, grubx64.efi …)
     • Secure Boot verifiziert Signaturen
2. GRUB (Bootloader)
     • lädt /boot/grub/grub.cfg, zeigt Menü, startet Kernel
3. Kernel & initrd
     • initramfs entpacken, Treiber / LVM / Crypto initialisieren
     • root=<UUID/Pfad> bestimmt Root‑Dateisystem
4. systemd (PID 1)
     • liest default.target, startet Units parallel
     • Gesamtdauer mit systemd‑analyze messbar
EOS
echo

# ----------------------------------------------------------------------
banner "2) Boot‑Dauer analysieren"

run "Übersicht (Firmware + Loader + Kernel + Userspace)" \
    "systemd-analyze"

run "Kritische Kette anzeigen" \
    "systemd-analyze critical-chain | head -n 20"

banner "Boot‑Zeitleiste als SVG"
if (( DRY_RUN )); then
  echo "(dry‑run) systemd-analyze plot > boot.svg"
else
  systemd-analyze plot > boot.svg
  echo "SVG gespeichert als ./boot.svg – per Browser betrachten (xdg-open boot.svg)."
fi
echo

# ----------------------------------------------------------------------
banner "3) GRUB‑Anpassung – Menüeintrag ohne 'quiet' erstellen"

GRUB_DIR="/etc/grub.d"
CUSTOM="${GRUB_DIR}/40_linux_verbose"
BACKUP="${CUSTOM}.orig.$(date +%s)"

if [[ -f "$CUSTOM" && ! -f "$BACKUP" ]]; then
  need_root cp "$CUSTOM" "$BACKUP"
fi

ROOT_DEV=$(findmnt -n -o SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV" || echo "UNKNOWN")

WRITE_ENTRY() {
cat <<EOF
#!/bin/sh
exec tail -n +3 \$0
#---------------------------------------------------------------
menuentry 'Linux (verbose)' {
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --no-floppy --fs-uuid --set=root $ROOT_UUID
    linux /vmlinuz root=UUID=$ROOT_UUID ro
    initrd /initrd.img
}
#---------------------------------------------------------------
EOF
}

if (( DRY_RUN )); then
  echo "(dry‑run) würde folgende Datei schreiben: $CUSTOM"
  WRITE_ENTRY | indent
else
  WRITE_ENTRY | need_root tee "$CUSTOM" > /dev/null
  need_root chmod +x "$CUSTOM"
fi
echo

banner "GRUB‑Konfiguration regenerieren"
if (( DRY_RUN )); then
  echo "(dry‑run) update‑grub  ODER  grub2-mkconfig -o /boot/grub2/grub.cfg"
else
  if command -v update-grub &>/dev/null; then
    need_root update-grub
  elif command -v grub2-mkconfig &>/dev/null; then
    need_root grub2-mkconfig -o /boot/grub2/grub.cfg
  else
    echo "⚠️  Kein GRUB‑Update‑Tool gefunden."
  fi
fi
echo

# ----------------------------------------------------------------------
banner "4) Neuen Eintrag testweise auswählen (temporär)"

CMD="grub-reboot 'Linux (verbose)' && reboot"
if (( DRY_RUN )); then
  echo "(dry‑run) $CMD"
else
  read -rp $'➤ Jetzt sofort in den neuen Eintrag booten? [y/N] ' ans
  if [[ $ans =~ ^[Yy]$ ]]; then
    need_root grub-reboot 'Linux (verbose)'
    echo "System wird neu gestartet …"
    need_root reboot
  else
    echo "Überspringe Reboot – GRUB‑Eintrag ist aber gespeichert."
  fi
fi
echo

# ----------------------------------------------------------------------
banner "5) Troubleshooting & Sicherheit (Merkzettel)"
cat <<'EOS' | indent
• GRUB‑Menü: Taste 'e' → Kernel‑Parameter ad‑hoc anpassen, z. B. systemd.unit=rescue.target
• EFI‑Einträge prüfen:  efibootmgr -v
• Secure Boot + eigene Kernel: mit sbsign signieren oder Secure Boot deaktivieren
• Früh‑Logs ohne quiet?  systemd‑journal‑remote / journalctl -b -1
EOS
echo

banner "Demo abgeschlossen – erneut mit --dry-run testen oder mit sudo produktiv ausführen."
