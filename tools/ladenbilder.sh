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

# Es gibt nur noch eine Schleife. `fahrt` nimmt sie auf - im Spiel, im
# Titelbild, im Bericht oder auf einem Reiter des Ausbaus, je nach Schaltern.
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
# 4. Eine spaete Welle, ohne Nebel: der Grund, ueber den man faehrt.
#
# **Auch hier `--stufen 14`.** Ohne den Schalter steht in der Kopfzeile der
# leere Spielstand des Behaelters neben einer Welle 40. In diesem Zustand
# ist nie ein Spieler: wer so tief kommt, hat eine gewachsene Kolonie. Ein
# Ladenbild soll das Spiel zeigen, das man bekommt, und dazu gehoert ein
# Stand, den es gibt.
fahrt  4-tief    --spiel --offen --welle 40 --zeit 30 --stufen 14 $FERTIG
# 5. Das Aufbauspiel: der Schnitt durch die Kolonie.
fahrt  5-kolonie --kolonie 0 --stufen 14 $FERTIG
# 6. Was eine Brutlinie aendert.
fahrt  6-linien  --kolonie 1 --stufen 14 $FERTIG
# 7. Das Bestiarium - die Regeln stehen im Spiel, nicht in einem Wiki.
#
# **Mit einer Welle davor.** Der Reiter zeigt, was schon aufgetreten ist;
# ohne gespielte Welle stuenden dort zwoelf Zeilen "Not yet encountered" -
# ein Ladenbild, das nur sagt, dass man nichts gesehen hat.
fahrt  7-arten   --spiel --welle 40 --zeit 26 --kolonie 2 --stufen 14 $FERTIG

echo "fertig."
