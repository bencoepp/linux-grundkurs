#!/bin/bash

# Inhalt der Datei
content="ich bin eine test datei"

# Alle Home-Verzeichnisse unter /home/ durchgehen
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        file_path="$user_home/test.txt"
        
        # Datei mit Inhalt erstellen
        echo "$content" > "$file_path"
        
        # Überprüfen ob Datei erfolgreich erstellt wurde
        if [ -f "$file_path" ]; then
            echo "Datei wurde erfolgreich erstellt in: $file_path"
        else
            echo "Fehler beim Erstellen der Datei in: $file_path"
        fi
    fi
done