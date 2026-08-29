extends SceneTree

## Erzeugt das App-Symbol - gerechnet, nicht gemalt.
##
##     godot --headless --path . --script tools/symbol.gd
##
## Dieselbe Entscheidung wie bei allem anderen Sichtbaren: das Symbol entsteht
## in diesem Quelltext und hat damit genau eine Herkunft. Die erzeugte Datei
## steht in `ASSETS.md` als selbst erzeugt.
##
## Motiv: der Lichtkegel im Graben. Kein Schriftzug - ein Symbol muss auf
## 48 Pixel Kantenlaenge noch erkennbar sein, und Buchstaben sind es dort nie.

const GROESSE := 512
const ZIEL := "res://symbol.png"


func _init() -> void:
    var bild := Image.create(GROESSE, GROESSE, false, Image.FORMAT_RGBA8)
    var mitte := float(GROESSE) * 0.5

    # Der Waechter sitzt unten, der Kegel oeffnet sich nach oben - genau wie
    # im Spiel. Wer das Symbol kennt, erkennt den Bildschirm wieder.
    var spitze := Vector2(mitte, GROESSE * 0.86)
    var halbwinkel := 0.40
    var reichweite := GROESSE * 0.86

    for y in GROESSE:
        for x in GROESSE:
            var p := Vector2(float(x) + 0.5, float(y) + 0.5)

            # 1. Grund: Grabenschwarz mit Schein von unten.
            var t := float(y) / float(GROESSE)
            var farbe := Color(0.012, 0.028, 0.045).lerp(
                Color(0.030, 0.090, 0.110), pow(t, 1.6))

            # 2. Der Kegel - dieselbe Rechnung wie im Spiel.
            var hell := Schlund.beleuchtung(spitze, Vector2.UP, halbwinkel,
                reichweite, p)
            farbe += Color(0.20, 0.74, 0.88) * hell * 0.62
            farbe += Color(0.70, 0.96, 0.92) * pow(hell, 3.0) * 0.30

            # 3. Das Leuchtorgan selbst.
            var d := p.distance_to(spitze - Vector2(0.0, GROESSE * 0.03))
            farbe += Color(0.80, 1.0, 0.96) * clampf(
                1.0 - d / (GROESSE * 0.10), 0.0, 1.0) * 0.9

            # 4. Zwei Raeuber im Licht, damit klar ist, worum es geht.
            for wo in [Vector2(mitte - GROESSE * 0.11, GROESSE * 0.30),
                       Vector2(mitte + GROESSE * 0.09, GROESSE * 0.45)]:
                var dr: float = p.distance_to(wo)
                farbe += Color(0.62, 0.88, 0.96) * clampf(
                    1.0 - dr / (GROESSE * 0.055), 0.0, 1.0) * 0.85

            bild.set_pixel(x, y, Color(clampf(farbe.r, 0.0, 1.0),
                clampf(farbe.g, 0.0, 1.0), clampf(farbe.b, 0.0, 1.0), 1.0))

    var fehler := bild.save_png(ProjectSettings.globalize_path(ZIEL))
    if fehler != OK:
        push_error("Symbol nicht schreibbar: %s" % error_string(fehler))
        quit(1)
    print("Symbol geschrieben: ", ZIEL, " (", GROESSE, "x", GROESSE, ")")
    quit(0)
