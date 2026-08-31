#!/usr/bin/env bash
# Erzeugt die Bilder fuer den Play-Store-Eintrag.
#
#     tools/ladenbilder.sh [zielordner]
#
# **Warum ein Skript und keine Handarbeit.** Google verlangt mindestens zwei
# Screenshots im Hochformat, und sie muessen das Spiel zeigen, das man
# tatsaechlich bekommt - eine Werbung, die etwas anderes zeigt als das Spiel,
# ist ein Verstoss gegen die Play-Richtlinien und nicht nur unfein. Aus
# demselben Grund sind es echte Aufnahmen aus dem laufenden Spiel und keine
# Montagen: dieselbe Bildfolge laesst sich nach jeder Aenderung neu erzeugen
# und bleibt damit ehrlich.
#
# 1080x1920 statt der Entwurfsgroesse 720x1280: Google will mindestens
# 1080 Pixel auf der kurzen Kante.
set -euo pipefail

ZIEL="${1:-build/laden}"
mkdir -p "$ZIEL"
GROESSE="1080x1920"

schuss () {
  local name="$1"; shift
  xvfb-run -a godot --path . --rendering-driver opengl3 \
    --resolution "$GROESSE" -- --schuss "$ZIEL/$name.png" "$@" \
    > /dev/null 2>&1
  echo "  $ZIEL/$name.png"
}

echo "Ladenbilder nach $ZIEL:"
# 1. Die Kernschleife - der Kegel gegen eine volle Welle.
schuss 1-wache   --welle 22 --zeit 12
# 2. Die Tiere, ohne dass der Kegel sie wegraeumt.
schuss 2-arten   --welle 40 --zeit 22 --stau
# 3. Das Aufbauspiel: der Schnitt durch die Kolonie.
schuss 3-kolonie --kolonie 0 --stufen 14
# 4. Was eine Brutlinie aendert.
schuss 4-linien  --kolonie 1 --stufen 14
# 5. Das Bestiarium - die Regeln stehen im Spiel, nicht in einem Wiki.
schuss 5-arten   --kolonie 2 --stufen 14
# 6. Die Bauphase mit dem Hinweis, was zu tun ist.
schuss 6-bauen   --bauen --welle 22

echo "fertig."
