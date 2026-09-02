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
    --resolution "$GROESSE" -- --schlund --schuss "$ZIEL/$name.png" "$@" \
    > /dev/null 2>&1
  echo "  $ZIEL/$name.png"
}

# **Der Lehrpfad muss aus den meisten Bildern heraus.** Der Behaelter hat
# keinen Spielstand, also steht der Einstieg auf Schritt 1 - und dann haengt
# ueber Welle 22 eine Tafel, die erklaert, wie man den Finger haelt. Das ist
# nicht falsch, es passt nur nicht zusammen: die Aufnahme zeigt eine
# ausgebaute Kolonie und einen Satz fuer die erste Minute. `--lehre 9` liegt
# hinter dem letzten Schritt und schaltet ihn ab.
FERTIG="--lehre 9"

echo "Ladenbilder nach $ZIEL:"
# 1. Die Kernschleife - der Kegel gegen eine volle Welle.
schuss 1-wache   --welle 22 --zeit 12 $FERTIG
# 2. Die Tiere, ohne dass der Kegel sie wegraeumt.
schuss 2-arten   --welle 40 --zeit 22 --stau $FERTIG
# 3. Das Aufbauspiel: der Schnitt durch die Kolonie.
schuss 3-kolonie --kolonie 0 --stufen 14 $FERTIG
# 4. Was eine Brutlinie aendert.
schuss 4-linien  --kolonie 1 --stufen 14 $FERTIG
# 5. Das Bestiarium - die Regeln stehen im Spiel, nicht in einem Wiki.
schuss 5-arten   --kolonie 2 --stufen 14 $FERTIG
# 6. Die Bauphase - hier **mit** dem Lehrpfad, weil das Bild genau das zeigen
#    soll: das Spiel erklaert sich im Spiel, und zwar an der Stelle, um die
#    es geht. Ein Screenshot einer Fuehrung ist auch eine Aussage ueber das
#    Spiel, und diese hier stimmt.
schuss 6-bauen   --bauen --welle 6 --lehre 3

echo "fertig."
