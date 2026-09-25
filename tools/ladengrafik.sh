#!/usr/bin/env bash
# Erzeugt das Feature-Bild fuer den Play-Store-Eintrag.
#
#     tools/ladengrafik.sh [zielordner]
#
# Google verlangt genau 1024x500, und es steht ganz oben ueber dem Eintrag -
# fuer viele ist es das erste, was sie von dem Spiel sehen.
#
# **Auch das ist eine Aufnahme aus dem laufenden Spiel**, kein Bild aus einem
# Grafikprogramm. Das ist derselbe Nachweis wie ueberall hier: `ASSETS.md`
# fuehrt keine einzige Bilddatei ausser dem App-Symbol, und ein Feature-Bild
# aus fremder Hand waere der erste Eintrag. Gezeichnet wird der Schriftzug
# von `zug_hud.gd::_marke()`, der Rest ist ein Gefecht in der sechsten
# Minute, gefuehrt vom selben Daumen wie der Messstand.
#
# Aufgenommen wird in doppelter Groesse und danach verkleinert: Schrift und
# Kanten werden davon sauber, und die Kantenglaettung der Aufnahme arbeitet
# auf der grossen Flaeche.
set -euo pipefail

ZIEL="${1:-build/laden}"
mkdir -p "$ZIEL"

# Eigener, leerer Spielstand - wie bei den Ladenbildern, damit kein
# gewachsener Stand hineinregiert.
STAND="$(mktemp -d)"
trap 'rm -rf "$STAND"' EXIT
export HOME="$STAND"
export XDG_DATA_HOME="$STAND/.local/share"

ROH="$STAND/roh.png"
xvfb-run -a godot --path . --rendering-driver opengl3 \
  --resolution 2048x1000 -- --marke --held 0 --stufen 12 --zeit 330 \
  --schuss "$ROH" > /dev/null 2>&1

python3 - "$ROH" "$ZIEL/feature.png" <<'PY'
import sys
from PIL import Image
roh = Image.open(sys.argv[1]).convert("RGB")
roh.resize((1024, 500), Image.LANCZOS).save(sys.argv[2])
PY

echo "  $ZIEL/feature.png (1024x500)"
