extends SceneTree

## Erzeugt das App-Symbol und den Android-Symbolsatz - gerechnet, nicht gemalt.
##
##     godot --headless --path . --script tools/symbol.gd
##
## Dieselbe Entscheidung wie bei allem anderen Sichtbaren: die Symbole
## entstehen in diesem Quelltext und haben damit genau eine Herkunft. Die
## erzeugten Dateien stehen in `ASSETS.md` als selbst erzeugt.
##
## Motiv: der Lichtkegel im Graben. Kein Schriftzug - ein Symbol muss auf
## 48 Pixel Kantenlaenge noch erkennbar sein, und Buchstaben sind es dort nie.
##
## --- Warum es fuenf Dateien sind ---
##
## Ein einzelnes Vollbild reicht seit Android 8 nicht mehr. Das System schiebt
## dort **zwei** Ebenen gegeneinander - Hintergrund und Vordergrund - und
## schneidet daraus die Form, die der Hersteller gerade vorsieht: Kreis,
## abgerundetes Quadrat, Tropfen. Wer nur ein fertiges Bild abgibt, bekommt es
## in ein weisses Kaestchen gesetzt und steht damit neben jeder anderen App
## wie ein Fremdkoerper.
##
##   * `symbol.png` - 512, das Projektsymbol und die Vorlage fuer den Web-Bau
##   * `symbol_192.png` - der alte, nicht anpassbare Starter
##   * `symbol_hintergrund.png` - 432, randlos: das Wasser des Grabens
##   * `symbol_vordergrund.png` - 432, durchsichtig: Kegel, Organ, zwei Tiere
##   * `symbol_einfarbig.png` - 432, weiss auf durchsichtig, fuer die
##     eingefaerbten Symbole ab Android 13
##
## **Die Schutzzone ist der ganze Grund fuer die Aufteilung.** Von den 432
## Pixeln sind nur die inneren 66 Prozent sicher sichtbar; alles ausserhalb
## darf beschnitten werden. Das Motiv liegt deshalb im Vordergrund und
## vollstaendig innerhalb dieser Zone, waehrend der Hintergrund bis in die
## Ecken durchgezeichnet ist - was dort abgeschnitten wird, fehlt niemandem.

const ADAPTIV := 432
## Anteil der Kantenlaenge, der sicher sichtbar bleibt.
const SCHUTZZONE := 0.66


func _init() -> void:
    _schreibe(_male(512, true, true), "res://symbol.png")
    _schreibe(_male(192, true, true), "res://symbol_192.png")
    _schreibe(_male(ADAPTIV, true, false), "res://symbol_hintergrund.png")
    _schreibe(_male(ADAPTIV, false, true), "res://symbol_vordergrund.png")
    _schreibe(_einfarbig(ADAPTIV), "res://symbol_einfarbig.png")
    quit()


## Zeichnet das Motiv.
##
## `grund` malt das Wasser, `motiv` den Kegel mit Organ und Tieren. Beide
## zusammen ergeben das Vollbild, einzeln die zwei Ebenen des anpassbaren
## Symbols.
##
## Bei den anpassbaren Ebenen sitzt das Motiv in der Schutzzone: es wird auf
## `SCHUTZZONE` verkleinert und mittig gesetzt. Beim Vollbild fuellt es die
## ganze Flaeche, wie bisher.
func _male(groesse: int, grund: bool, motiv: bool) -> Image:
    var bild := Image.create(groesse, groesse, false, Image.FORMAT_RGBA8)
    var voll := grund and motiv
    var mass := float(groesse) * (1.0 if voll else SCHUTZZONE)
    var rand := (float(groesse) - mass) * 0.5
    var mitte := rand + mass * 0.5

    # Der Waechter sitzt unten, der Kegel oeffnet sich nach oben - genau wie
    # im Spiel. Wer das Symbol kennt, erkennt den Bildschirm wieder.
    var spitze := Vector2(mitte, rand + mass * 0.86)
    var halbwinkel := 0.40
    var reichweite := mass * 0.86

    for y in groesse:
        for x in groesse:
            var p := Vector2(float(x) + 0.5, float(y) + 0.5)
            var farbe := Color(0.0, 0.0, 0.0, 0.0)

            if grund:
                # Grabenschwarz mit Schein von unten. Randlos, damit das
                # System beschneiden kann, ohne ein Loch zu hinterlassen.
                var t := float(y) / float(groesse)
                var w := Color(0.012, 0.028, 0.045).lerp(
                    Color(0.030, 0.090, 0.110), pow(t, 1.6))
                farbe = Color(w.r, w.g, w.b, 1.0)

            if motiv:
                var licht := Color(0.0, 0.0, 0.0)

                # Der Kegel - dieselbe Rechnung wie im Spiel.
                var hell := Schlund.beleuchtung(spitze, Vector2.UP, halbwinkel,
                    reichweite, p)
                licht += Color(0.20, 0.74, 0.88) * hell * 0.62
                licht += Color(0.70, 0.96, 0.92) * pow(hell, 3.0) * 0.30

                # Das Leuchtorgan selbst.
                var d := p.distance_to(spitze - Vector2(0.0, mass * 0.03))
                licht += Color(0.80, 1.0, 0.96) * clampf(
                    1.0 - d / (mass * 0.10), 0.0, 1.0) * 0.9

                # Zwei Raeuber im Licht, damit klar ist, worum es geht.
                for wo in [Vector2(mitte - mass * 0.11, rand + mass * 0.30),
                           Vector2(mitte + mass * 0.09, rand + mass * 0.45)]:
                    var dr: float = p.distance_to(wo)
                    licht += Color(0.62, 0.88, 0.96) * clampf(
                        1.0 - dr / (mass * 0.055), 0.0, 1.0) * 0.85

                # Auf der eigenen Ebene traegt die Helligkeit die Deckung:
                # wo kein Licht ist, ist nichts, und das System sieht dort
                # seinen eigenen Hintergrund.
                var staerke := maxf(licht.r, maxf(licht.g, licht.b))
                if voll:
                    farbe += licht
                else:
                    farbe = Color(licht.r, licht.g, licht.b,
                        clampf(staerke, 0.0, 1.0))

            bild.set_pixel(x, y, Color(clampf(farbe.r, 0.0, 1.0),
                clampf(farbe.g, 0.0, 1.0), clampf(farbe.b, 0.0, 1.0),
                clampf(farbe.a, 0.0, 1.0)))
    return bild


## Die einfarbige Fassung fuer die eingefaerbten Symbole ab Android 13.
##
## Dort faerbt das System selbst - abgegeben wird nur eine Form in Weiss auf
## durchsichtig. Farbverlaeufe sind hier nutzlos: was zaehlt, ist der Umriss,
## und der ist der Kegel.
func _einfarbig(groesse: int) -> Image:
    var bild := Image.create(groesse, groesse, false, Image.FORMAT_RGBA8)
    var mass := float(groesse) * SCHUTZZONE
    var rand := (float(groesse) - mass) * 0.5
    var mitte := rand + mass * 0.5
    var spitze := Vector2(mitte, rand + mass * 0.86)

    for y in groesse:
        for x in groesse:
            var p := Vector2(float(x) + 0.5, float(y) + 0.5)
            var hell := Schlund.beleuchtung(spitze, Vector2.UP, 0.40,
                mass * 0.86, p)
            var d := p.distance_to(spitze - Vector2(0.0, mass * 0.03))
            var kern := clampf(1.0 - d / (mass * 0.12), 0.0, 1.0)
            # Haerter als beim farbigen Motiv: eine einfarbige Form braucht
            # eine Kante, sonst bleibt vom Verlauf nach dem Einfaerben ein
            # grauer Fleck.
            var deckung := clampf(pow(hell, 0.5) * 1.15 + kern, 0.0, 1.0)
            bild.set_pixel(x, y, Color(1.0, 1.0, 1.0, deckung))
    return bild


func _schreibe(bild: Image, ziel: String) -> void:
    var fehler := bild.save_png(ProjectSettings.globalize_path(ziel))
    if fehler != OK:
        push_error("Symbol nicht schreibbar: %s" % error_string(fehler))
        return
    print("Symbol geschrieben: ", ziel, " (", bild.get_width(), "x",
        bild.get_height(), ")")
