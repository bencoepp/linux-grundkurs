#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Demo‑Skript: Gerätedateien & Partitionierung
#  • zeigt /dev‑Einträge, lsblk‑Übersicht
#  • erläutert MBR‑ vs. GPT‑Merkmale
#  • demonstriert fdisk‑ (MBR) und gdisk‑(GPT)‑Aufrufe (nur Anzeige)
#  • führt eine vollständige Loop‑Device‑Übung (GPT, 3 Partitionen) durch
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
      echo "❌  Root‑Rechte benötigt – Skript mit sudo ausführen oder --dry-run verwenden." >&2
      exit 1
    fi
    "$@"
  fi
}

run() {                 # run "Titel" "Befehl ..."
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
run "1) Gerätedateien: Beispiel‑Listing" \
    "ls -l /dev/$(lsblk -dn -o NAME | head -n1)"

run "lsblk‑Übersicht (NAME,MAJ:MIN,SIZE,TYPE,MOUNTPOINT)" \
    "lsblk -o NAME,MAJ:MIN,SIZE,TYPE,MOUNTPOINT"

########################################################################
banner "2) MBR vs. GPT – Schnellvergleich"
cat <<'EOS' | indent
                MBR (DOS‑Label)          GPT
------------------------------------------------------------
Max. Partitionen    4 (prim.)          128 (Standard)
Max. Datenträger    2 TiB              9,4 ZB
Redundanz           Keine              Primär + Backup
Prüfsumme           Nein               CRC32
Boot‑Code           440 Byte im MBR    separate EFI‑Partition
Kompatibilität      BIOS               UEFI (BIOS‑Hybrid möglich)
EOS
echo

########################################################################
banner "3) fdisk‑ und gdisk‑Aufrufe (nur Anzeige)"
cat <<'EOS' | indent
# MBR‑Beispiel (fdisk, interaktiv):
sudo fdisk /dev/sdb
  n  p 1  <RETURN>  +1G
  t  83
  w

# MBR‑Skript‑Variante:
printf 'n\np\n1\n\n+1G\nt\n83\nw\n' | sudo fdisk /dev/sdb

# GPT‑Beispiel (gdisk, interaktiv):
sudo gdisk /dev/sdb
  n 1 <RETURN> +512M
  w
EOS
echo

########################################################################
banner "4) Geführte Übung – 100 MiB Loop‑Device mit 3 Partitionen"

LAB_DIR=${LAB_DIR:-$HOME/lab}
DISK_IMG="$LAB_DIR/disk.img"
mkdir -p "$LAB_DIR"

run "Schritt 0 – alte Images/Loops bereinigen" \
    "rm -f '$DISK_IMG' && sudo losetup -D || true"

run "Schritt 1 – 100 MiB Image‑Datei erzeugen" \
    "dd if=/dev/zero of='$DISK_IMG' bs=1M count=100 status=none"

banner "Schritt 2 – Loop‑Gerät verbinden"
if (( DRY_RUN )); then
  echo "(dry‑run) LOOP=\$(sudo losetup --find --show '$DISK_IMG')"
  LOOP="/dev/loopX"
else
  LOOP=$(need_root losetup --find --show "$DISK_IMG")
fi
echo "Verwendetes Loop‑Device: $LOOP"

run "Schritt 3 – GPT‑Label anlegen" \
    "need_root parted -s '$LOOP' mklabel gpt"

banner "Schritt 4 – 3 Partitionen erstellen (20 MiB ext4, 30 MiB xfs, Rest swap)"
cmds=(
  "parted -s '$LOOP' mkpart primary ext4 1MiB 21MiB"
  "parted -s '$LOOP' mkpart primary xfs 21MiB 51MiB"
  "parted -s '$LOOP' mkpart primary linux-swap 51MiB 100%"
)
for c in "${cmds[@]}"; do
  run "$c" "need_root $c"
done
run "Partitionstabelle neu einlesen" "need_root partprobe '$LOOP'"

run "Kontrolle mit lsblk" "lsblk '$LOOP'"

banner "Schritt 5 – Dateisysteme anlegen"
fmt_cmds=(
  "mkfs.ext4 '${LOOP}p1' -F -q"
  "mkfs.xfs  '${LOOP}p2' -f -q"
  "mkswap    '${LOOP}p3'"
)
for f in "${fmt_cmds[@]}"; do
  run "$f" "need_root $f"
done

banner "Schritt 6 – Mount‑Test"
if (( DRY_RUN )); then
  echo "(dry‑run) würde /mnt/loop1 + /mnt/loop2 anlegen und mounten"
else
  need_root mkdir -p /mnt/loop{1,2}
  need_root mount "${LOOP}p1" /mnt/loop1
  need_root mount "${LOOP}p2" /mnt/loop2
  df -h | grep "$LOOP" | indent
  need_root umount /mnt/loop1 /mnt/loop2
fi

run "Schritt 7 – Loop‑Gerät trennen" \
    "need_root losetup -d '$LOOP'"

########################################################################
banner "5) Tipps & Fehlerbehebung"
cat <<'EOS' | indent
• lsblk -f zeigt Dateisystem‑UUIDs und Labels – praktisch für /etc/fstab.
• partprobe oder kpartx aufrufen, wenn Kernel die neue Partitionstabelle
  noch nicht bemerkt hat.
• fdisk -l /dev/sdX listet vorhandene Partitionstabellen.
• GPT‑Partitionstypen schnell ändern: gdisk, Menübefehl t, Hex‑Code (z. B. EF00).
• Loop‑Devices sind ideal für gefahrlose Experimente – nach losetup -d
  ist das Host‑System unverändert.
• Immer Backups oder Test‑VM verwenden, bevor Sie MBR/GPT auf echten
  Produktions‑Disks anfassen.
EOS
echo

banner "Demo abgeschlossen – erneut mit --dry-run testen oder mit sudo produktiv ausführen."
