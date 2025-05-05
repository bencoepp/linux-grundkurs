#!/usr/bin/env bash
# ===============================================================
# Seminar‑Demo: Unix‑Prozessmodell, Shell‑Typen und Aliases
# v3 – robust gegen fehlenden Alias‑Include in ~/.bashrc
# ===============================================================

set -euo pipefail

# ---------- Hilfsfunktionen ------------------------------------
pause() {
  if [[ -t 0 ]]; then
    read -rp $'\nWeiter mit <Enter> …'
  else
    echo -e '\n[Kein TTY – fahre automatisch fort]'
  fi
}

safe_demo() {
  local title=$1; shift
  echo -e "\n-- $title --"
  set +e
  "$@"
  local rc=$?
  set -e
  echo "  (Exit‑Status $rc wurde ignoriert)"
}

ensure_alias_include() {
  # Sorgt dafür, dass ~/.bashrc die Datei ~/.bash_aliases einliest
  local marker='[ -f ~/.bash_aliases ] &&'
  if ! grep -qF "$marker" ~/.bashrc 2>/dev/null; then
    echo -e "\n# Persönliche Alias‑Datei automatisch einbinden\nif [ -f ~/.bash_aliases ]; then\n    . ~/.bash_aliases\nfi" >> ~/.bashrc
    echo "→ include‑Block in ~/.bashrc ergänzt."
  fi
}

reload_aliases() {
  # Versucht zuerst source ~/.bashrc; falls ll danach nicht existiert,
  # lädt es ~/.bash_aliases direkt.
  [[ -f ~/.bashrc ]] && source ~/.bashrc || true
  if ! type -t ll &>/dev/null; then
    source ~/.bash_aliases
  fi
}
# ---------------------------------------------------------------

clear
echo "===== 1. Unix‑Prozessmodell ====="
echo "PID  (aktuelle Shell): $$"
echo "PPID (Elternprozess) : $PPID"
echo
sleep 1 & child=$!
echo "Kindprozess‑PID      : $child"
ps -o pid,ppid,comm -p "$child,$$,$PPID"
wait "$child"
pause

echo "===== 2. Shell‑Typen in Aktion ====="
safe_demo "Login‑Shell (bash --login)" \
          bash --login -c 'echo "  \$0  = $0"; echo "  Flags \$- = $-"; [[ $0 == -* ]] && echo "  ➜ Login‑Shell erkannt"'

safe_demo "Interaktive Non‑Login‑Shell (bash -i)" \
          bash -i -c 'echo "  \$0  = $0"; echo "  Flags \$- = $-"; [[ $- == *i* ]] && echo "  ➜ interaktiv"'

safe_demo "Nicht‑interaktive Shell (bash -c)" \
          bash -c 'echo "  \$0  = $0"; echo "  Flags \$- = $-"; [[ $- != *i* ]] && echo "  ➜ nicht‑interaktiv"'
pause

echo "===== 3. Welche Start‑Dateien werden gelesen? ====="
if command -v strace &>/dev/null; then
  tmpdir=$(mktemp -d)
  strace -e openat,access -f -o "$tmpdir/login.log" bash --login -c 'true'
  echo "Login‑Shell:"
  grep -E '/(etc/profile|\.bash_(profile|login|rc|bashrc|aliases|profile))' \
        "$tmpdir/login.log" | sed -E 's#.*"(.*)".*#  \1#' | sort -u || true

  strace -e openat,access -f -o "$tmpdir/nologin.log" bash -i -c 'true'
  echo -e "\nInteraktive Non‑Login‑Shell:"
  grep -E '/(etc/profile|\.bash_(profile|login|rc|bashrc|aliases|profile))' \
        "$tmpdir/nologin.log" | sed -E 's#.*"(.*)".*#  \1#' | sort -u || true
  rm -r "$tmpdir"
else
  echo "(strace fehlt – Abschnitt übersprungen)"
fi
pause

echo "===== 4. Alias‑Übung ====="
ensure_alias_include

if [[ ! -f ~/.bash_aliases ]]; then
  touch ~/.bash_aliases
  echo '# Eigene Shell‑Aliases' >> ~/.bash_aliases
  echo "→ ~/.bash_aliases neu angelegt."
fi

if ! grep -q "^alias ll=" ~/.bash_aliases; then
  echo "alias ll='ls -lh --group-directories-first -a --color=auto'" \
       >> ~/.bash_aliases
  echo "→ Alias ll hinzugefügt."
else
  echo "→ Alias ll war schon vorhanden."
fi

echo -e "\nAktuelle Inhalte:"
tail -n 5 ~/.bash_aliases
pause

echo "Alias sofort aktivieren …"
reload_aliases

echo -e "\nFunktionstest:"
type -a ll
echo
ll | head -n 5
pause

echo "===== 5. Bonus‑Aliases ====="
for line in \
  "alias grep='grep --color=auto'" \
  "alias ..='cd ..'" \
  "alias ...='cd ../..'"
do
  key=${line%%=*}
  if ! grep -q "${key#alias }" ~/.bash_aliases; then
    echo "$line" >> ~/.bash_aliases
    echo "→ ${key#alias } hinzugefügt."
  fi
done

reload_aliases
echo -e "\nAktive Bonus‑Aliases:"
alias | grep -E '^(grep|\.\.)='
echo

echo "===== Ende der Demo – viel Spaß beim Experimentieren! ====="
