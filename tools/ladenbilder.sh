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

# **Ein eigener, leerer Spielstand je Lauf.**
#
# Vorher liefen die Aufnahmen auf dem Stand, der zufaellig im Behaelter lag -
# und der hatte ein Datum. Beim naechsten Lauf stand deshalb ueber der
# Schlundwache die Tafel "WHILE YOU WERE AWAY" mit 45.3K gefilterten
# Naehrstoffen: ein Ladenbild, das nicht das Spiel zeigt, sondern eine
# Rueckkehr. Die Kammerstufen kommen ohnehin aus `--stufen`, also braucht
# keine Aufnahme einen gewachsenen Stand.
STAND="$(mktemp -d)"
trap 'rm -rf "$STAND"' EXIT
export HOME="$STAND"
export XDG_DATA_HOME="$STAND/.local/share"

# Zwei Schuesse, weil es zwei Schleifen gibt. `schuss` geht in die
# Schlundwache (`--schlund`), `fahrt` bleibt im Rundumlauf, mit dem die App
# jetzt startet.
schuss () {
  local name="$1"; shift
  xvfb-run -a godot --path . --rendering-driver opengl3 \
    --resolution "$GROESSE" -- --schlund --schuss "$ZIEL/$name.png" "$@" \
    > /dev/null 2>&1
  echo "  $ZIEL/$name.png"
}

fahrt () {
  local name="$1"; shift
  xvfb-run -a godot --path . --rendering-driver opengl3 \
    --resolution "$GROESSE" -- --schuss "$ZIEL/$name.png" "$@" \
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
# **Die Reihenfolge ist die des Spiels, nicht die der Entstehung.** Wer den
# Eintrag durchwischt, sieht zuerst, womit die App aufmacht.
#
# 1. Der Rundumlauf, die Fahrt - das ist der erste Bildschirm nach PLAY.
fahrt  1-fahrt   --spiel --welle 24 --zeit 26 --stufen 14 $FERTIG
# 2. Das Titelbild: der Name, und dass es hinter ihm weitergeht.
fahrt  2-titel   --zeit 6 --stufen 14 $FERTIG
# 3. Der Bericht nach einer Fahrt.
fahrt  3-bericht --ende --zeit 3 $FERTIG
# 4. Die andere Schleife - der Kegel gegen eine volle Welle.
schuss 4-wache   --welle 22 --zeit 12 $FERTIG
# 5. Die Tiere, ohne dass der Kegel sie wegraeumt.
schuss 5-arten   --welle 40 --zeit 22 --stau $FERTIG
# 6. Das Aufbauspiel: der Schnitt durch die Kolonie.
schuss 6-kolonie --kolonie 0 --stufen 14 $FERTIG
# 7. Was eine Brutlinie aendert.
schuss 7-linien  --kolonie 1 --stufen 14 $FERTIG
# 8. Das Bestiarium - die Regeln stehen im Spiel, nicht in einem Wiki.
schuss 8-arten   --kolonie 2 --stufen 14 $FERTIG

echo "fertig."
