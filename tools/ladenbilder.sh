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
# **Bis September 2026 rief dieses Skript Schalter auf, die es nicht mehr
# gab** - `--welle`, `--kolonie`, `--offen`, zwei Spiele alt. Godot ueber-
# geht unbekannte Schalter stumm, also waeren sieben Titelbilder
# herausgekommen und kein Fehler. Jeder Schalter hier steht in
# `zug_lauf.gd::_lies_schalter()`.
#
# 1080x1920 statt der Entwurfsgroesse 720x1280: Google will mindestens
# 1080 Pixel auf der kurzen Kante.
set -euo pipefail

ZIEL="${1:-build/laden}"
mkdir -p "$ZIEL"
GROESSE="1080x1920"

# **Ein eigener, leerer Spielstand je Lauf.** Sonst laeuft die Aufnahme auf
# dem Stand, der zufaellig im Behaelter liegt. Die Burgstufen, der Beutel und
# die Bestmarken kommen ohnehin aus `--stufen`.
STAND="$(mktemp -d)"
trap 'rm -rf "$STAND"' EXIT
export HOME="$STAND"
export XDG_DATA_HOME="$STAND/.local/share"

schuss () {
  local name="$1"; shift
  xvfb-run -a godot --path . --rendering-driver opengl3 \
    --resolution "$GROESSE" -- --schuss "$ZIEL/$name.png" "$@" \
    > /dev/null 2>&1
  echo "  $ZIEL/$name.png"
}

echo "Ladenbilder nach $ZIEL:"
# **Die Reihenfolge ist die des Werbens, nicht die der Entstehung.** Wer den
# Eintrag durchwischt, sieht zuerst, worum es geht: einer gegen viele.
#
# `--zeit` rechnet das Gefecht mit `Daumen` vor, demselben simulierten
# Daumen wie `tools/probe.gd` - ein Bild aus einem Lauf, den es gibt.
#
# **Niedrige Burgstufen, mittlere Zeiten.** Der erste Satz nahm Stufe 14 und
# die neunte Minute, weil das nach dem vollen Spiel klang - und zeigte ein
# fast leeres Feld: wer so ausgebaut ist, raeumt schneller, als die Horde
# nachkommt. Ein Ladenbild fuer ein Spiel namens TEN THOUSAND mit acht
# Feinden im Bild wirbt fuer das falsche.
schuss 1-horde    --held 0 --stufen 4 --zeit 240
schuss 2-titel    --lage 0 --stufen 14
schuss 3-bogen    --held 1 --stufen 4 --zeit 200
# Mit `--stufen` stehen auch die Zuege, und damit die Gefaehrten im Bild.
schuss 4-gefolge  --held 2 --stufen 4 --zeit 300
schuss 5-burg     --lage 3 --stufen 10

echo "fertig."
