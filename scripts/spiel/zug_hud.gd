extends Control

## **Das Bedienbild - auch es ist gestochen.**
##
## Keine rechten Winkel: ein Knopf ist vier Pinselstriche, die sich an den
## Ecken nicht ganz treffen. Fuenf gerahmte Rechtecke untereinander waeren
## ein Antragsformular, das jemand ueber den Holzschnitt gelegt hat.
##
## **Die Aufstiegskarten bekommen den ganzen Schirm.** Sie sind die einzige
## Entscheidung im Lauf; alles andere ist Aufstellung und Reflex.

const TINTE := Color(0.12, 0.10, 0.09)
const ZINNOBER := Color(0.66, 0.14, 0.11)
const GOLD := Color(0.72, 0.55, 0.18)
const SEPIA := Color(0.42, 0.34, 0.24)
const HELL := Color(0.98, 0.96, 0.90)

var _tu := Tusche.new()
## **Die Schrift wird gesammelt wie die Tusche.**
##
## `Tusche` ist ein Sammler: alles landet in einem Netz und wird am Ende in
## **einem** Aufruf gespuelt. `draw_string` geht dagegen sofort aufs Blatt.
## Damit lag jede Beschriftung **unter** ihrer eigenen Tafel - und eine
## Tafel ist ein Pergamentwisch mit zweiundsechzig Prozent Deckung. Im Bild
## stand auf jedem Knopf und jeder Karte graue Schrift, wo schwarze stehen
## sollte; die Kosten in der Burg sahen aus, als koenne man sie sich nicht
## leisten. Die Worte warten deshalb hier und kommen nach dem Spuelen.
var _worte: Array = []
var _felder: Array = []
var _lauf: Node2D

## **Zwei Schriften, und jede hat ihre Aufgabe.** Bricolage, kraeftig, fuer
## das, was einen Schirm benennt - Titel, Namen, Knoepfe; Rajdhani fuer
## Zahlen, deren Ziffern gleich breit stehen. Beide lagen seit August 2026
## im Repository und in `ASSETS.md`, und gezeichnet wurde mit der
## Standardschrift der Engine.
const BRICOLAGE := preload("res://schriften/bricolage/BricolageGrotesque.ttf")
const RAJDHANI := preload("res://schriften/rajdhani/Rajdhani-Medium.ttf")
var _kopf: Font
var _zahl: Font


func _ready() -> void:
    _lauf = get_parent().get_parent() as Node2D
    # Bricolage ist eine variable Schrift; ohne Achse steht sie im duennsten
    # Schnitt, und der verschwindet auf Pergament.
    var fett := FontVariation.new()
    fett.base_font = BRICOLAGE
    fett.variation_opentype = {
        TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
    _kopf = fett
    _zahl = RAJDHANI
    mouse_filter = Control.MOUSE_FILTER_PASS
    set_process(true)


func _process(_d: float) -> void:
    queue_redraw()


func _rand() -> float:
    # `get_display_safe_area()` nur auf dem Telefon: auf dem Schreibtisch
    # liefert sie den ganzen Bildschirm und nicht das Fenster, und aus der
    # Differenz wird ein Rand von vierhundert Bildpunkten.
    if not OS.has_feature("mobile"):
        return 26.0
    var sicher := DisplayServer.get_display_safe_area()
    var fenster := DisplayServer.window_get_size()
    return clampf(float(sicher.position.y), 26.0, float(fenster.y) * 0.12)


# --- Pinselwerk ------------------------------------------------------------

func _kasten(r: Rect2, farbe: Color, breite := 4.0) -> void:
    var a := r.position
    var b := r.position + r.size
    var u := r.size.x * 0.035
    _tu.zug(Vector2(a.x - u, a.y), Vector2(b.x + u * 0.4, a.y - 2.0), breite, farbe, 0.4, 0.3, 2.0, 5)
    _tu.zug(Vector2(b.x, a.y - u * 0.3), Vector2(b.x + 2.0, b.y + u * 0.5), breite, farbe, 0.4, 0.3, 2.0, 5)
    _tu.zug(Vector2(b.x + u * 0.4, b.y), Vector2(a.x - u * 0.6, b.y + 2.0), breite, farbe, 0.4, 0.3, 2.0, 5)
    _tu.zug(Vector2(a.x, b.y + u * 0.3), Vector2(a.x - 2.0, a.y - u * 0.4), breite, farbe, 0.4, 0.3, 2.0, 5)


## **Eine Tafel ist ein Blatt, keine Linse.**
##
## Der erste Anlauf war ein `wisch()` - und der schwillt zur Mitte an und
## laeuft zu den Enden aus. Auf einem Knopf von sechzig Bildpunkten faellt
## das nicht auf; auf einer Berichtstafel von vierhundert stand eine
## **Linse** im Bild, mit hellem Bauch und spitzen Enden. Was eine Flaeche
## sein soll, braucht ueber ihre ganze Laenge dieselbe Breite - und die
## Unregelmaessigkeit gehoert an die Kante, nicht in die Mitte.
## **Dicht genug, dass der Boden nicht durchscheint.** Die Menues standen
## auf halber Deckung, solange der Boden aus blassen Flecken bestand; seit er
## Steine mit Kante und Pfade hat, lagen die quer ueber den Karten.
func _tafel(r: Rect2, deckung: float) -> void:
    var mitte := PackedVector2Array()
    var halb := PackedFloat32Array()
    var deck := PackedFloat32Array()
    var stuecke := 9
    for i in stuecke:
        var t := float(i) / float(stuecke - 1)
        mitte.append(Vector2(r.position.x + r.size.x * t,
            r.position.y + r.size.y * 0.5))
        # Ein handgerissenes Blatt: die Kante wackelt um ein Prozent.
        halb.append(r.size.y * 0.5 * (1.0 + 0.02 * sin(t * 9.0 + r.position.y)))
        deck.append(1.0)
    _tu.band(mitte, halb, Color(HELL.r, HELL.g, HELL.b, deckung), deck)


func _knopf(id: String, r: Rect2, text: String, aktiv := true,
        bild := Callable()) -> void:
    _leiste(id, r, text, aktiv, bild)


# --- Der Rahmen ------------------------------------------------------------

## **Ein Schirm ist ein gerahmtes Blatt** - so stand es in der Vorlage des
## Nutzers (Oktober 2026): helles Pergament, ein dunkelbrauner doppelter
## Rand, Eckbeschlaege, ein Kopf mit Wappen und Linien zwischen den Zeilen.
## Vorher lagen einzelne blasse Karten frei ueber dem Feld.
const RAHMEN := Color(0.333, 0.224, 0.133)
const BLATT := Color(0.957, 0.918, 0.808)
const BLATT_TIEF := Color(0.902, 0.851, 0.718)


## Ein Rechteck, ueberall gleich hoch (siehe `_riegel`).
func _flaeche(r: Rect2, farbe: Color) -> void:
    _riegel(Vector2(r.position.x, r.position.y + r.size.y * 0.5),
        Vector2(r.end.x, r.position.y + r.size.y * 0.5), r.size.y, farbe)


func _rand_linien(r: Rect2, dicke: float, farbe: Color) -> void:
    var a := r.position
    var e := r.end
    _riegel(Vector2(a.x - dicke * 0.5, a.y), Vector2(e.x + dicke * 0.5, a.y), dicke, farbe)
    _riegel(Vector2(a.x - dicke * 0.5, e.y), Vector2(e.x + dicke * 0.5, e.y), dicke, farbe)
    _riegel(Vector2(a.x, a.y), Vector2(a.x, e.y), dicke, farbe)
    _riegel(Vector2(e.x, a.y), Vector2(e.x, e.y), dicke, farbe)


func _rahmen(r: Rect2) -> void:
    _flaeche(Rect2(r.position + Vector2(6.0, 9.0), r.size),
        Color(TINTE.r, TINTE.g, TINTE.b, 0.28))
    _flaeche(r, BLATT)
    _rand_linien(r, 7.0, RAHMEN)
    _rand_linien(r.grow(-11.0), 2.0, Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.45))
    # Eckbeschlaege: ein Quadrat mit Niet.
    for ecke in [r.position, Vector2(r.end.x, r.position.y),
            Vector2(r.position.x, r.end.y), r.end]:
        _flaeche(Rect2(ecke - Vector2.ONE * 11.0, Vector2.ONE * 22.0), RAHMEN)
        _tu.klecks(ecke, 4.0, BLATT_TIEF, 1)


## Eine Linie zwischen zwei Zeilen.
func _trenner(r: Rect2, y: float) -> void:
    _riegel(Vector2(r.position.x + 18.0, y), Vector2(r.end.x - 18.0, y), 2.0,
        Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.35))


## Der Kopf eines Rahmens: Bild links, Titel, optional Untertitel, und das
## Schliesskreuz rechts, das zurueck zum Titel fuehrt.
func _kopfzeile(r: Rect2, titel: String, bild: Callable, unter := "",
        schliessen := false) -> void:
    bild.call(Vector2(r.position.x + 50.0, r.position.y + 58.0))
    var x := r.position.x + 92.0
    var platz := r.end.x - x - (70.0 if schliessen else 24.0)
    _zeile_eng(titel, Vector2(x, r.position.y + (60.0 if unter != "" else 72.0)), 40,
        TINTE, platz, _kopf)
    if unter != "":
        _zeile_eng(unter, Vector2(x, r.position.y + 90.0), 20,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), platz)
    if schliessen:
        var p := Vector2(r.end.x - 40.0, r.position.y + 44.0)
        Zeichen.schliessen(_tu, p, 14.0, RAHMEN)
        _felder.append({"id": "titel", "r": Rect2(p - Vector2.ONE * 30.0,
            Vector2.ONE * 60.0), "aktiv": true})
    _trenner(r, r.position.y + 116.0)


## **Ein Knopf ist eine Leiste**: dunklere Flaeche, brauner Rand, ein Bild
## links und die Schrift daneben.
func _leiste(id: String, r: Rect2, text: String, aktiv := true,
        bild := Callable()) -> void:
    _felder.append({"id": id, "r": r, "aktiv": aktiv})
    _flaeche(Rect2(r.position + Vector2(3.0, 5.0), r.size),
        Color(TINTE.r, TINTE.g, TINTE.b, 0.22))
    _flaeche(r, BLATT_TIEF if aktiv else Color(BLATT.r, BLATT.g, BLATT.b, 0.85))
    _rand_linien(r, 4.0, Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 1.0 if aktiv else 0.45))
    var farbe := TINTE if aktiv else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.6)
    if bild.is_valid():
        bild.call(Vector2(r.position.x + 34.0, r.position.y + r.size.y * 0.5))
        _mitte_eng(text, Rect2(r.position + Vector2(40.0, 0.0),
            r.size - Vector2(40.0, 0.0)), 26, farbe, _kopf)
    else:
        _mitte_eng(text, r, 26, farbe, _kopf)


## Das Wappen in der Farbe des gewaehlten Helden und Gewands.
func _wappen(ort: Vector2, g: float) -> void:
    var h := Burg.stand.held
    var n := Burg.stand.skin(h)
    Zeichen.wappen(_tu, ort, g, Skins.koerper(h, n), Skins.glanz(h, n))


func _mitte(text: String, r: Rect2, groesse: int, farbe: Color,
        schrift: Font = null) -> void:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
    _worte.append({"f": f, "wo": Vector2(r.position.x + (r.size.x - w) * 0.5,
        r.position.y + r.size.y * 0.5 + groesse * 0.36), "text": text,
        "groesse": groesse, "farbe": farbe})


## Mittig wie `_mitte`, und kleiner, bis der Satz mit Rand hineingeht - aus
## demselben Grund wie `_zeile_eng`.
func _mitte_eng(text: String, r: Rect2, groesse: int, farbe: Color,
        schrift: Font = null) -> void:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    var g := groesse
    while g > KLEINSTE and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
            -1, g).x > r.size.x - 52.0:
        g -= 1
    _mitte(text, r, g, farbe, f)


func _zeile(text: String, wo: Vector2, groesse: int, farbe: Color,
        schrift: Font = null) -> void:
    _worte.append({"f": schrift if schrift != null else ThemeDB.fallback_font,
        "wo": wo, "text": text, "groesse": groesse, "farbe": farbe})


## Wie breit ein Text in einer Schrift steht.
func _breite(text: String, groesse: int, schrift: Font = null) -> float:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x


## Eine Zeile, die **in ihre Tafel passt**.
##
## Der erste Anlauf setzte den Satz des Bogenschuetzen in fester Groesse auf
## die Karte: er lief ueber den Rand der Tafel hinaus und rechts aus dem
## Bild. Eine Beschriftung, die breiter ist als das, was sie beschriftet,
## ist keine Beschriftung.
##
## Gekuerzt wird nicht - ein abgeschnittener Satz sagt weniger als ein
## kleinerer. Die Groesse faellt, bis er hineingeht, und nicht unter
## `KLEINSTE`: darunter liest ihn auf einem Telefon niemand mehr.
const KLEINSTE := 15

func _zeile_eng(text: String, wo: Vector2, groesse: int, farbe: Color,
        breite: float, schrift: Font = null) -> void:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    var g := groesse
    while g > KLEINSTE and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
            -1, g).x > breite:
        g -= 1
    _worte.append({"f": f, "wo": wo, "text": text, "groesse": g,
        "farbe": farbe})


## Wie viel Luft ueber einem Block steht, damit er **mittig** im Bild sitzt.
##
## Die Schirme waren von oben her gesetzt. Auf einem 20:9-Telefon
## (720 x 1600) stand alles im oberen Drittel und darunter ein leeres
## Viertel Pergament - das sieht nicht nach Absicht aus, sondern nach einem
## Entwurf fuer ein anderes Geraet. Wird es eng, ist die Luft null und der
## Block klebt wieder oben; ueber den Rand schiebt ihn nichts.
func _luft(hoehe: float) -> float:
    return maxf(0.0, (size.y - _rand() * 2.0 - hoehe) * 0.5)


## **Ein Balken hat ueberall dieselbe Hoehe.**
##
## Der erste Anlauf nahm `zug()`, und der schwillt zur Mitte an: im Bild
## stand eine **Linse** ueber dem Schirm, spitz an beiden Enden. Ein Balken
## ist aber eine Menge und kein Pinselstrich - man liest ihn an seiner
## Laenge, und eine Laenge mit spitzen Enden laesst sich nicht ablesen.
func _riegel(von: Vector2, bis: Vector2, dicke: float, farbe: Color) -> void:
    # Die Laenge zaehlt, nicht der Weg nach rechts: hier stand
    # `bis.x - von.x < 1`, und seit die Rahmen senkrechte Kanten haben, fiel
    # jede davon weg - und jede Linie, die nach links laeuft. Ein leerer
    # Balken (Laenge null) bleibt weiter ungezeichnet.
    if von.distance_squared_to(bis) < 1.0:
        return
    var mitte := PackedVector2Array([von, (von + bis) * 0.5, bis])
    var halb := PackedFloat32Array([dicke * 0.5, dicke * 0.5, dicke * 0.5])
    var deck := PackedFloat32Array([1.0, 1.0, 1.0])
    _tu.band(mitte, halb, farbe, deck)


func _balken(r: Rect2, anteil: float, farbe: Color) -> void:
    var y := r.position.y + r.size.y * 0.5
    _riegel(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y),
        r.size.y, Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.20))
    var b := r.size.x * clampf(anteil, 0.0, 1.0)
    _riegel(Vector2(r.position.x, y), Vector2(r.position.x + b, y),
        r.size.y * 0.84, farbe)


# --- Das Bild --------------------------------------------------------------

func _draw() -> void:
    _felder.clear()
    _worte.clear()
    if _lauf == null:
        return
    match _lauf.lage:
        0:
            _titel()
        1:
            if _lauf.marke:
                _marke()
            else:
                _im_lauf()
        2:
            _ende()
        3:
            _burg()
        4:
            _zeug()
    _tu.spuele(get_canvas_item())
    # **Im Lauf bekommt die Schrift eine Kante.** Sie steht dort nicht auf
    # einer Tafel, sondern direkt ueber dem Gedraenge, und "837 slain" war
    # auf dem Ladenbild zur Haelfte ein Pikenier. Dieselbe Regel wie fuer
    # die Figuren: eine Kante trennt, was sonst ineinanderlaeuft.
    var kante: bool = _lauf.lage == 1
    for w in _worte:
        if kante:
            draw_string_outline(w["f"], w["wo"], w["text"],
                HORIZONTAL_ALIGNMENT_LEFT, -1, w["groesse"],
                maxi(4, int(w["groesse"]) / 5),
                Color(HELL.r, HELL.g, HELL.b, 0.85))
        draw_string(w["f"], w["wo"], w["text"], HORIZONTAL_ALIGNMENT_LEFT,
            -1, w["groesse"], w["farbe"])


func _titel() -> void:
    var b := size.x
    var s := Burg.stand
    var zeilen := Helden.NAMEN.size()
    var hoch := 120.0 + float(zeilen) * TITEL_ZEILE + 96.0
    var oben := _rand() + _luft(SZENE + hoch + 50.0)
    _szene(Vector2(b * 0.5, oben + SZENE - 14.0), b)
    var r := Rect2(24.0, oben + SZENE, b - 48.0, hoch)
    _rahmen(r)
    _kopfzeile(r, "TEN THOUSAND", func(p): _wappen(p, 34.0),
        "One blade. Ten thousand of them.")

    var y := r.position.y + 118.0
    for h in zeilen:
        var frei := Helden.ist_frei(h, s.beste_zeit, s.meiste_erschlagen,
            s.warlord_gefallen)
        var zeile := Rect2(r.position.x, y, r.size.x - 14.0, TITEL_ZEILE)
        # **Jede Zeile zeigt ihren Helden** - in seiner Klasse und dem
        # gewaehlten Gewand. Ein gesperrter steht als Schatten da: man sieht,
        # was kommt, aber nicht, wie es aussieht.
        var n := s.skin(h)
        var kleid := Skins.koerper(h, n) if frei else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.35)
        var glanz := Skins.glanz(h, n) if frei else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.35)
        var fuss := Vector2(r.position.x + 56.0, y + TITEL_ZEILE - 12.0)
        if frei:
            Streiter._schatten(_tu, fuss, 84.0)
        Streiter.held(_tu, fuss, 84.0, 1.0, 0.0, -0.75, kleid, glanz, h)
        var x := r.position.x + 108.0
        _zeile(Helden.name_von(h), Vector2(x, y + 38.0), 28,
            TINTE if frei else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.6), _kopf)
        var satz := Helden.lehre_von(h) if frei else Helden.bedingung_text(h)
        # **Zwei Saetze, zwei Zeilen**, und beide hoeren vor den Gewaendern
        # auf: eine Beschriftung unter einem Knopf ist keine Beschriftung.
        var platz := zeile.end.x - x - 16.0 - (150.0 if frei else 0.0)
        var farbe := Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95 if frei else 0.6)
        var teil := satz.find(". ")
        if teil > 0:
            _zeile_eng(satz.substr(0, teil + 1), Vector2(x, y + 64.0), 19, farbe, platz)
            _zeile_eng(satz.substr(teil + 2), Vector2(x, y + 86.0), 19, farbe, platz)
        else:
            _zeile_eng(satz, Vector2(x, y + 70.0), 19, farbe, platz)
        if frei:
            # **Die Zeile hoert vor den Punkten auf.** Der Treffer nimmt das
            # erste Feld, das passt; laege sie darueber, startete jeder Tipp
            # auf ein Gewand sofort einen Lauf.
            _felder.append({"id": "held%d" % h,
                "r": Rect2(zeile.position, Vector2(zeile.size.x - 156.0, zeile.size.y)),
                "aktiv": true})
            _gewaender(h, zeile)
        y += TITEL_ZEILE
        if h < zeilen - 1:
            _trenner(r, y)

    var halb := (r.size.x - 60.0) * 0.5
    var yk := y + 14.0
    _knopf("burg", Rect2(r.position.x + 22.0, yk, halb, 58.0), "KEEP", true,
        func(p): Zeichen.bau(_tu, Halle.Bau.MAUER, p, 15.0))
    _knopf("zeug", Rect2(r.position.x + 38.0 + halb, yk, halb, 58.0), "GEAR", true,
        func(p): Zeichen.stueck(_tu, Ausruestung.Stueck.VISIERHELM, p, 15.0))
    if s.etwas_zu_holen():
        _tu.klecks(Vector2(r.position.x + 22.0 + halb - 8.0, yk + 8.0), 9.0,
            Palette.HELD, 3, Palette.UMRISS)
    if s.laeufe > 0:
        var z := "best %d:%02d   /   %d felled   /   %d coin" % [
            int(s.beste_zeit) / 60, int(s.beste_zeit) % 60,
            s.meiste_erschlagen, s.sold]
        var zw := _breite(z, 26, _zahl)
        _zeile(z, Vector2((b - zw) * 0.5, r.end.y + 40.0), 26,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.85), _zahl)


const TITEL_ZEILE := 112.0


## Wie hoch die Szene ueber dem Titel steht.
const SZENE := 190.0

## **Einer gegen die Horde - als Bild, bevor man es liest.** Der Held in der
## Mitte, die Sorten von beiden Seiten auf ihn zu, gezeichnet mit denselben
## Figuren wie im Lauf. Die Reihenfolge ist fest: der Titel ist kein
## Gefecht, und ein Bild, das bei jedem Start anders steht, flackert.
const SZENE_REIHE := [
    [-300.0, Feinde.Art.SPIESSER], [-240.0, Feinde.Art.STROLCH],
    [-185.0, Feinde.Art.WOLF], [-120.0, Feinde.Art.RITTER],
    [300.0, Feinde.Art.ARMBRUSTER], [240.0, Feinde.Art.TREIBER],
    [180.0, Feinde.Art.STROLCH], [118.0, Feinde.Art.WOLF],
]

func _szene(boden: Vector2, b: float) -> void:
    # Der Boden: ein flacher Erdfleck, auf dem sie stehen.
    var erde := Palette.ERDE
    # Ein Wisch, der zu den Seiten auslaeuft - als Riegel ueber die ganze
    # Breite stand die Szene auf einem Brett.
    _tu.wisch(boden + Vector2(-b * 0.52, 0.0), boden + Vector2(b * 0.52, 0.0), 34.0,
        Color(erde.r, erde.g, erde.b, 0.55))
    var hoehe := 96.0
    for e in SZENE_REIHE:
        var x: float = e[0] * minf(1.0, b / 720.0)
        var art: int = e[1]
        var f := boden + Vector2(x, -4.0 + absf(x) * 0.02)
        var hh := hoehe * (Feinde.radius(art) / 17.0)
        Streiter.feind(_tu, f, hh, -signf(x), art, absf(x) * 0.05, 0.0, false)
    var held := Burg.stand.held
    var n := Burg.stand.skin(held)
    Streiter.frei_gestellt(_tu, boden + Vector2(0.0, 6.0), hoehe * 1.5, Palette.BODEN)
    Streiter._schatten(_tu, boden + Vector2(0.0, 6.0), hoehe * 1.5)
    Streiter.held(_tu, boden + Vector2(0.0, 6.0), hoehe * 1.5, 1.0, 0.0, -1.0,
        Skins.koerper(held, n), Skins.glanz(held, n), held)


## Die drei Gewaender am rechten Rand einer Heldenkarte.
##
## **Als Farbpunkte und nicht als Namensliste.** Eine Skin ist eine Farbe;
## wer sie waehlen will, will sie sehen und nicht lesen. Was gesperrt ist,
## steht blass da - ein Gewand, das man nicht sieht, ist kein Ziel.
func _gewaender(h: int, karte: Rect2) -> void:
    var s := Burg.stand
    var gewaehlt := s.skin(h)
    for n in Skins.JE_HELD:
        var mitte := Vector2(karte.end.x - 30.0 - float(Skins.JE_HELD - 1 - n) * 46.0,
            karte.position.y + karte.size.y * 0.5)
        var frei := Skins.ist_frei(h, n, s.beste_zeit, s.meiste_erschlagen,
            s.warlord_gefallen)
        if n == gewaehlt:
            # Der Reif um das getragene: zwei Punkte uebereinander waeren
            # zwei Gewaender, ein Reif ist eine Wahl.
            _tu.klecks(mitte, 21.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.9), h * 7)
        var farbe := Skins.koerper(h, n)
        if not frei:
            farbe = Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.25)
        _tu.klecks(mitte, 15.0, farbe, h * 13 + n, Palette.UMRISS)
        if frei:
            _felder.append({"id": "skin%d_%d" % [h, n],
                "r": Rect2(mitte - Vector2.ONE * 23.0, Vector2.ONE * 46.0),
                "aktiv": true})


func _im_lauf() -> void:
    var st: Gefecht.Stand = _lauf.stand()
    if st == null:
        return
    var b := size.x
    var oben := _rand()

    # **Ein Treffer faerbt den Bildrand.** Kurz und blass in Zinnober, an allen
    # vier Kanten: Schaden am Spieler, und im Gedraenge sieht man ihn sonst
    # nur am Balken oben, wohin keiner schaut.
    var wunde: float = _lauf.wunde()
    if wunde > 0.0:
        var c := Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.38 * wunde)
        var d := 46.0
        var h := size.y
        for kante in [[Vector2(0, 0), Vector2(b, 0)], [Vector2(0, h), Vector2(b, h)],
                [Vector2(0, 0), Vector2(0, h)], [Vector2(b, 0), Vector2(b, h)]]:
            _tu.band(PackedVector2Array([kante[0], kante[1]]),
                PackedFloat32Array([d, d]), c, PackedFloat32Array())

    # **Das Leben ist die lauteste Anzeige**, denn es ist der einzige Grund,
    # warum ein Lauf endet.
    # Das Herz vor dem Balken: so ist er Leben und nicht irgendeine Menge.
    _balken(Rect2(60.0, oben + 14.0, b - 86.0, 22.0),
        st.leben / maxf(1.0, st.leben_voll), ZINNOBER)
    _wappen(Vector2(34.0, oben + 30.0), 22.0)
    # Erfahrung darunter, schmaler: sie endet nichts, sie verspricht nur.
    # **Nicht in Gold** - Gold heisst Sold, und so stand sie bis Oktober 2026.
    var noetig := float(Gunst.stufenkosten(st.stufe))
    _balken(Rect2(60.0, oben + 42.0, b - 86.0, 10.0),
        float(st.erfahrung) / maxf(1.0, noetig), Palette.ERFAHRUNG)

    var m := int(st.zeit) / 60
    var sek := int(st.zeit) % 60
    _zeile("%d:%02d" % [m, sek], Vector2(26.0, oben + 96.0), 42, TINTE, _zahl)
    var lv := "LV %d" % st.stufe
    _zeile(lv, Vector2(b - 26.0 - _breite(lv, 32, _kopf), oben + 94.0), 32,
        TINTE, _kopf)
    Zeichen.schaedel(_tu, Vector2(38.0, oben + 122.0), 12.0)
    _zeile("%d" % st.erschlagen, Vector2(58.0, oben + 132.0), 28,
        Color(TINTE.r, TINTE.g, TINTE.b, 0.9), _zahl)
    var sold := "%d" % st.sold
    var sw := _breite(sold, 28, _zahl)
    Zeichen.muenze(_tu, Vector2(b - 26.0 - sw - 18.0, oben + 122.0), 12.0)
    _zeile(sold, Vector2(b - 26.0 - sw, oben + 132.0), 28,
        Color(GOLD.r, GOLD.g, GOLD.b, 0.95), _zahl)

    if st.wartet_auf_wahl:
        _aufstieg(st)
        return

    # **Der erste Lauf erklaert sich, einmal** (Zusicherung 27). Im unteren
    # Drittel: der Held steht in der Mitte, oben liegen die Balken. Keine
    # Tafel - sie verdeckte Figuren, und die Kante der Laufschrift genuegt.
    var hin: float = _lauf.hinweis()
    if hin > 0.0:
        var y := size.y * 0.70
        _mitte_eng("Drag anywhere to move.", Rect2(0.0, y, b, 40.0), 30,
            Color(TINTE.r, TINTE.g, TINTE.b, hin))
        _mitte_eng("Your weapons strike on their own.",
            Rect2(0.0, y + 42.0, b, 34.0), 24,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, hin))

    # Der Stick wird gezeichnet, wo der Daumen ihn aufgesetzt hat.
    if _lauf.zieht():
        var von: Vector2 = _lauf.stick_von()
        var jetzt: Vector2 = _lauf.stick_jetzt()
        _tu.zug(von + Vector2(-34.0, 0.0), von + Vector2(34.0, 0.0), 3.0,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.30), 0.5, 0.0, 6.0, 5)
        _tu.klecks(von, 12.0, Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.26), 1)
        var d := jetzt - von
        if d.length() > 12.0:
            var kopf := von + d.limit_length(72.0)
            _tu.zug(von, kopf, 7.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.36),
                0.5, 0.2, 0.0, 4)
            _tu.klecks(kopf, 16.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.34), 2)


## **Der Name ueber dem Gefecht** - nur fuer das Feature-Bild des Ladens.
##
## Es ist eine Aufnahme aus dem laufenden Spiel und kein Bild aus einem
## Grafikprogramm; `ASSETS.md` fuehrt keine Bilddatei ausser dem App-Symbol.
## Die Tafel dahinter ist so blass, dass das Gedraenge durchscheint, und so
## dicht, dass die Schrift auf ihm steht und nicht zwischen den Figuren.
##
## **Oben und nicht in der Mitte**: die Kamera folgt dem Helden, und der
## steht in der Mitte. Der erste Schuss setzte den Namen genau auf ihn - ein
## Werbebild fuer ein Spiel, in dem man sich findet, auf dem man sich nicht
## findet.
func _marke() -> void:
    var b := size.x
    var h := size.y
    var f := ThemeDB.fallback_font
    var t := "TEN THOUSAND"
    var gross := int(minf(b * 0.085, h * 0.16))
    var w := _breite(t, gross, _kopf)
    var u := "One blade. Ten thousand of them."
    var klein := int(gross * 0.42)
    var uw := f.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, klein).x
    var mitte := h * 0.2
    _tafel(Rect2((b - w) * 0.5 - gross * 0.6, mitte - gross * 1.15,
        w + gross * 1.2, gross * 2.2), 0.78)
    _zeile(t, Vector2((b - w) * 0.5, mitte + gross * 0.12), gross, TINTE, _kopf)
    _tu.zug(Vector2((b - w) * 0.5 - 8.0, mitte + gross * 0.34),
        Vector2((b + w) * 0.5 + 8.0, mitte + gross * 0.38), gross * 0.1,
        Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.85), 0.35, 0.5, 3.0, 7)
    _zeile(u, Vector2((b - uw) * 0.5, mitte + gross * 0.86), klein,
        Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))


## **Der Aufstieg ist ein Banner**: es haengt an einer Stange, traegt die
## drei Angebote untereinander und laeuft unten in eine Spitze aus, ueber der
## eine Burg in den Farben des Helden steht - so stand es in der Vorlage.
## Die Wahl ist das Einzige, was jetzt gilt; das Feld dahinter wird blass.
const WAHL_ZEILE := 124.0

func _aufstieg(st: Gefecht.Stand) -> void:
    var b := size.x
    var h := size.y
    _riegel(Vector2(0.0, h * 0.5), Vector2(b, h * 0.5), h + 4.0,
        Color(HELL.r, HELL.g, HELL.b, 0.55))
    var zahl := st.angebote.size()
    var koerper := 96.0 + float(zahl) * WAHL_ZEILE + 210.0
    var spitze := 80.0
    var oben := _rand() + 150.0 + maxf(0.0, (h - _rand() * 2.0 - 150.0
        - koerper - spitze) * 0.35)
    var r := Rect2(40.0, oben, b - 80.0, koerper)
    var mitte := r.position.x + r.size.x * 0.5
    # Schatten, Tuch und Spitze.
    _flaeche(Rect2(r.position + Vector2(6.0, 9.0), r.size),
        Color(TINTE.r, TINTE.g, TINTE.b, 0.28))
    _flaeche(r, BLATT)
    _tu.strang(PackedVector2Array([Vector2(mitte, r.end.y - 1.0),
        Vector2(mitte, r.end.y + spitze)]),
        PackedFloat32Array([r.size.x, 0.0]), BLATT, 2)
    # Der Rand folgt dem Umriss, die Spitze hinunter.
    var unten := Vector2(mitte, r.end.y + spitze)
    _riegel(r.position, Vector2(r.end.x, r.position.y), 7.0, RAHMEN)
    _riegel(r.position, Vector2(r.position.x, r.end.y), 7.0, RAHMEN)
    _riegel(Vector2(r.end.x, r.position.y), r.end, 7.0, RAHMEN)
    _riegel(Vector2(r.position.x, r.end.y), unten, 7.0, RAHMEN)
    _riegel(r.end, unten, 7.0, RAHMEN)
    _tu.klecks(unten, 7.0, RAHMEN, 2)
    # Die Stange, an der es haengt.
    _riegel(Vector2(r.position.x - 22.0, r.position.y - 4.0),
        Vector2(r.end.x + 22.0, r.position.y - 4.0), 12.0, Zeichen.HOLZ)
    for x in [r.position.x - 24.0, r.end.x + 24.0]:
        _tu.klecks(Vector2(x, r.position.y - 4.0), 10.0, Zeichen.HOLZ, 1, RAHMEN)

    var t := "CHOOSE"
    _zeile(t, Vector2(mitte - _breite(t, 42, _kopf) * 0.5, r.position.y + 68.0), 42,
        TINTE, _kopf)
    var y := r.position.y + 96.0
    _trenner(r, y)
    for i in zahl:
        var a = st.angebote[i]
        var zeile := Rect2(r.position.x, y, r.size.x, WAHL_ZEILE)
        # Das Bild der Waffe oder des Zugs: erkannt ist schneller als gelesen.
        var bild := Vector2(r.position.x + 58.0, y + WAHL_ZEILE * 0.5)
        _tu.klecks(bild, 36.0, BLATT_TIEF, i, Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.6))
        if a.ist_waffe:
            Zeichen.waffe(_tu, a.was, bild, 30.0)
        else:
            Zeichen.zug(_tu, a.was, bild, 30.0)
        var x := r.position.x + 112.0
        _zeile(a.name(), Vector2(x, y + 44.0), 28, TINTE, _kopf)
        # **Stufen als Punkte.** Eine Zahl sagt, wo man steht; Punkte sagen
        # auch, wie weit es noch geht. Der neue ist in der Farbe des Helden.
        var hoechst := Waffen.HOECHSTSTUFE if a.ist_waffe else Gunst.ZUG_HOECHSTSTUFE
        for k in hoechst:
            var p := Vector2(r.end.x - 30.0 - float(hoechst - 1 - k) * 20.0, y + 34.0)
            if k + 1 < a.stufe:
                _tu.klecks(p, 6.5, TINTE, k)
            elif k + 1 == a.stufe:
                _tu.klecks(p, 7.5, Palette.HELD, k, Palette.UMRISS)
            else:
                _tu.klecks(p, 5.5, Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.30), k)
        if a.neu:
            _zeile("NEW", Vector2(r.end.x - 30.0 - float(hoechst - 1) * 20.0 - 8.0,
                y + 66.0), 18, Palette.HELD.darkened(0.35), _kopf)
        _zeile_eng(a.lehre(), Vector2(x, y + 92.0), 20,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.98), r.end.x - x - 20.0)
        _felder.append({"id": "wahl%d" % i, "r": zeile, "aktiv": true})
        y += WAHL_ZEILE
        _trenner(r, y)
    var held := Burg.stand.held
    Zeichen.burg_bild(_tu, Vector2(mitte, y + 176.0), 120.0,
        Skins.koerper(held, Burg.stand.skin(held)))


## **Der Bericht hat ein Bild.** Gewonnen: der Held steht ueber dem
## gefallenen Warlord. Gefallen: die Horde steht, und vor ihr liegt die
## Waffe. Darunter das Blatt mit den Zahlen, darunter zwei Wege.
const BERICHT_BILD := 230.0
const BERICHT_TAFEL := 400.0

func _ende() -> void:
    var st: Gefecht.Stand = _lauf.stand()
    var b := size.x
    var gewonnen: bool = st != null and st.warlord_gefallen
    var oben := _rand() + _luft(BERICHT_BILD + BERICHT_TAFEL + 200.0)
    _bericht_bild(Vector2(b * 0.5, oben + BERICHT_BILD - 20.0), gewonnen,
        st.held if st != null else 0)
    var r := Rect2(b * 0.10, oben + BERICHT_BILD, b * 0.80, BERICHT_TAFEL)
    _rahmen(r)
    var kopf := "THE FIELD IS YOURS" if gewonnen else "YOU FALL"
    var kw := _breite(kopf, 40, _kopf)
    _mitte_eng(kopf, Rect2(r.position.x, r.position.y + 30.0, r.size.x, 60.0), 40,
        TINTE if gewonnen else ZINNOBER, _kopf)
    _trenner(r, r.position.y + 100.0)
    if st != null:
        var zeilen := [
            ["lasted", "%d:%02d" % [int(st.zeit) / 60, int(st.zeit) % 60]],
            ["slain", "%d" % st.erschlagen],
            ["coin", "%d" % st.sold],
            ["level", "%d" % st.stufe],
        ]
        var y := r.position.y + 150.0
        var achse := r.position.x + r.size.x * 0.5
        for z in zeilen:
            # Name links, Zahl rechts an einer Mittelachse: so liest man die
            # Zahlen untereinander und nicht vier Saetze.
            var nw := _breite(z[0], 26)
            _zeile(z[0], Vector2(achse - 14.0 - nw, y), 26,
                Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))
            _zeile(z[1], Vector2(achse + 14.0, y + 2.0), 34,
                GOLD if z[0] == "coin" else Color(TINTE.r, TINTE.g, TINTE.b, 0.92),
                _zahl)
            y += 44.0
        var fu: int = _lauf.fund()
        if fu >= 0:
            _trenner(r, y - 18.0)
            var ft := "found  %s  %d" % [Ausruestung.name_von(fu), _lauf.fund_stufe()]
            var fw := _breite(ft, 26)
            var fx := r.position.x + (r.size.x - fw) * 0.5 + 20.0
            Zeichen.stueck(_tu, fu, Vector2(fx - 30.0, y + 14.0), 20.0)
            _zeile(ft, Vector2(fx, y + 24.0), 26, TINTE)
    # **Kein Angebot nach einer Niederlage.** Zwei Wege, nie mehr.
    var yk := r.end.y + 30.0
    _knopf("nochmal", Rect2(b * 0.14, yk, b * 0.72, 76.0), "AGAIN", true,
        func(p): Zeichen.nochmal(_tu, p, 20.0))
    _knopf("titel", Rect2(b * 0.14, yk + 94.0, b * 0.72, 64.0), "BACK", true,
        func(p): Zeichen.zurueck(_tu, p, 18.0))
    var _k := kw




func _bericht_bild(boden: Vector2, gewonnen: bool, held: int) -> void:
    var erde := Palette.ERDE
    _tu.wisch(boden + Vector2(-260.0, 4.0), boden + Vector2(260.0, 4.0), 34.0,
        Color(erde.r, erde.g, erde.b, 0.55))
    var n := Burg.stand.skin(held)
    if gewonnen:
        Streiter.gefallen(_tu, boden + Vector2(70.0, 0.0), 240.0, -1.0,
            Feinde.Art.WARLORD, 1.0)
        Streiter._schatten(_tu, boden + Vector2(-70.0, 4.0), 170.0)
        Streiter.held(_tu, boden + Vector2(-70.0, 4.0), 170.0, 1.0, 0.0, -1.35,
            Skins.koerper(held, n), Skins.glanz(held, n), held)
    else:
        var reihe := [[-150.0, Feinde.Art.STROLCH], [-75.0, Feinde.Art.RITTER],
            [80.0, Feinde.Art.SPIESSER], [155.0, Feinde.Art.STROLCH]]
        for e in reihe:
            var art: int = e[1]
            var x: float = e[0]
            Streiter.feind(_tu, boden + Vector2(x, -6.0), 120.0 * Feinde.radius(art) / 17.0,
                -signf(x), art, 0.0, 0.0, false)
        Zeichen.waffe(_tu, Helden.startwaffe(held), boden + Vector2(0.0, -8.0), 44.0)


const BURG_ZEILE := 138.0

func _burg() -> void:
    var b := size.x
    var s := Burg.stand
    var hoch := 118.0 + float(Halle.NAMEN.size()) * BURG_ZEILE + 168.0
    var oben := _rand() + _luft(hoch)
    var r := Rect2(24.0, oben, b - 48.0, hoch)
    _rahmen(r)
    _kopfzeile(r, "THE KEEP", func(p): Zeichen.bau(_tu, Halle.Bau.MAUER, p, 26.0),
        "", true)
    var e := "%d" % s.sold
    var ew := _breite(e, 34, _zahl)
    _zeile(e, Vector2(r.end.x - 84.0 - ew, r.position.y + 70.0), 34, GOLD, _zahl)
    Zeichen.muenze(_tu, Vector2(r.end.x - 84.0 - ew - 22.0, r.position.y + 58.0), 15.0)

    var y := r.position.y + 118.0
    for bau in Halle.NAMEN.size():
        var stufe := s.stufe(bau)
        var voll := stufe >= Halle.HOECHSTSTUFE
        var bild := Vector2(r.position.x + 60.0, y + BURG_ZEILE * 0.5)
        _tu.klecks(bild, 36.0, BLATT_TIEF, bau, Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.6))
        Zeichen.bau(_tu, bau, bild, 28.0)
        var x := r.position.x + 116.0
        _zeile(Halle.name_von(bau), Vector2(x, y + 42.0), 30, TINTE, _kopf)
        var nw := _breite(Halle.name_von(bau), 30, _kopf)
        _zeile("%d" % stufe, Vector2(x + nw + 12.0, y + 42.0), 30,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), _zahl)
        _zeile_eng(Halle.beschreibung_von(bau), Vector2(x, y + 74.0), 20,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), r.end.x - x - 24.0)
        _balken(Rect2(x, y + 98.0, r.end.x - x - 200.0, 8.0),
            float(stufe) / float(Halle.HOECHSTSTUFE), RAHMEN)
        _knopf("bau%d" % bau, Rect2(r.end.x - 172.0, y + 82.0, 148.0, 44.0),
            "MAX" if voll else "%d" % s.kosten(bau), s.kann_bauen(bau))
        y += BURG_ZEILE
        _trenner(r, y)
    # **Ton und Beben lassen sich abschalten.** Ein Telefon, das bei jedem
    # Treffer brummt und sich nicht zum Schweigen bringen laesst, spielt man
    # nicht in der Bahn - und die Datenschutzerklaerung verspricht den
    # Schalter. Er steht in der Burg, weil sie der einzige Schirm ist, der
    # ohnehin Einstellungen am Spieler vornimmt.
    var halb := (r.size.x - 60.0) * 0.5
    var laut := s.laut > 0.001
    _knopf("ton", Rect2(r.position.x + 22.0, y + 18.0, halb, 56.0),
        "SOUND ON" if laut else "SOUND OFF", true,
        func(p): Zeichen.laut(_tu, p, 17.0, laut))
    _knopf("beben", Rect2(r.position.x + 38.0 + halb, y + 18.0, halb, 56.0),
        "RUMBLE ON" if s.beben else "RUMBLE OFF", true,
        func(p): Zeichen.ruettel(_tu, p, 17.0, s.beben))
    _knopf("titel", Rect2(r.position.x + r.size.x * 0.25, y + 90.0, r.size.x * 0.5, 56.0),
        "BACK", true, func(p): Zeichen.zurueck(_tu, p, 17.0))


const ZEUG_ZEILE := 118.0

func _zeug() -> void:
    var b := size.x
    var s := Burg.stand
    var plaetze := Ausruestung.PLATZ_NAMEN.size()
    var hoch := 118.0 + float(plaetze) * ZEUG_ZEILE + 100.0
    var oben := _rand() + _luft(hoch)
    var r := Rect2(24.0, oben, b - 48.0, hoch)
    _rahmen(r)
    _kopfzeile(r, "WHAT YOU CARRY",
        func(p): Zeichen.stueck(_tu, Ausruestung.Stueck.VISIERHELM, p, 26.0), "", true)

    var y := r.position.y + 118.0
    var zelle := (r.size.x - 150.0) * 0.5
    for platz in plaetze:
        # Auf halber Zeilenhoehe: sonst steht der Platzname zwischen zwei
        # Reihen und gehoert scheinbar zur falschen.
        _zeile(Ausruestung.platz_name(platz), Vector2(r.position.x + 26.0, y + 64.0), 22,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), _kopf)
        var x := r.position.x + 108.0
        var getragen := int(s.angelegt.get(platz, -1))
        for stueck in Ausruestung.Stueck.size():
            if Ausruestung.platz_von(stueck) != platz:
                continue
            var stufe := int(s.besitz.get(stueck, 0))
            var hat := stufe > 0
            var z := Rect2(x, y + 12.0, zelle, ZEUG_ZEILE - 24.0)
            _flaeche(z, BLATT_TIEF if hat else Color(BLATT_TIEF.r, BLATT_TIEF.g, BLATT_TIEF.b, 0.45))
            _rand_linien(z, 4.0 if stueck == getragen else 2.0,
                Color(RAHMEN.r, RAHMEN.g, RAHMEN.b,
                    1.0 if stueck == getragen else (0.55 if hat else 0.25)))
            # Das Stueck als Bild. Ein nicht gefundenes steht verschleiert
            # da: man weiss, dass es etwas gibt, aber nicht, was es kann.
            var bild := Vector2(z.position.x + 38.0, z.position.y + z.size.y * 0.5)
            Zeichen.stueck(_tu, stueck, bild, 26.0)
            if not hat:
                _tu.klecks(bild, 34.0, Color(BLATT.r, BLATT.g, BLATT.b, 0.72), stueck)
            var tx := z.position.x + 74.0
            _zeile_eng(Ausruestung.name_von(stueck), Vector2(tx, z.position.y + 36.0), 20,
                TINTE if hat else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.45),
                z.end.x - tx - 10.0, _kopf)
            _zeile_eng(Ausruestung.lehre_von(stueck, stufe) if hat else "not found",
                Vector2(tx, z.position.y + 64.0), 18,
                Color(TINTE.r, TINTE.g, TINTE.b, 0.8) if hat
                    else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.4),
                z.end.x - tx - 10.0)
            if hat:
                _felder.append({"id": "lege%d" % stueck, "r": z, "aktiv": true})
            x += zelle + 12.0
        y += ZEUG_ZEILE
        if platz < plaetze - 1:
            _trenner(r, y)
    _knopf("titel", Rect2(r.position.x + r.size.x * 0.25, y + 18.0, r.size.x * 0.5, 56.0),
        "BACK", true, func(p): Zeichen.zurueck(_tu, p, 17.0))


# --- Der Finger ------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
    var los := false
    var ort := Vector2.ZERO
    if e is InputEventScreenTouch and not e.pressed:
        los = true
        ort = e.position
    elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT \
            and not e.pressed:
        los = true
        ort = e.position
    if not los:
        return
    # **Im Lauf gehoert der Finger dem Helden** - ausser wenn gewaehlt wird.
    var st: Gefecht.Stand = _lauf.stand()
    if _lauf.lage == 1 and (st == null or not st.wartet_auf_wahl):
        return
    for feld in _felder:
        if not feld["r"].has_point(ort):
            continue
        if feld["aktiv"]:
            _gewaehlt(String(feld["id"]))
        accept_event()
        return


func _gewaehlt(id: String) -> void:
    Klang.spiele(Klang.Ton.TIPP)
    if id.begins_with("skin"):
        var teile := id.substr(4).split("_")
        Burg.stand.waehle_skin(int(teile[0]), int(teile[1]))
        Burg.sichere()
    elif id.begins_with("held"):
        _lauf.beginne(int(id.substr(4)))
    elif id.begins_with("wahl"):
        _lauf.waehle(int(id.substr(4)))
    elif id.begins_with("bau"):
        Burg.baue(int(id.substr(3)))
    elif id.begins_with("lege"):
        Burg.stand.lege_an(int(id.substr(4)))
        Burg.sichere()
    elif id == "nochmal":
        _lauf.beginne(Burg.stand.held)
    elif id == "ton":
        Burg.stand.laut = 0.0 if Burg.stand.laut > 0.001 else 0.7
        Klang.laut = Burg.stand.laut
        Burg.sichere()
        Klang.spiele(Klang.Ton.TIPP)
    elif id == "beben":
        Burg.stand.beben = not Burg.stand.beben
        Tastsinn.an = Burg.stand.beben
        Burg.sichere()
    elif id == "burg":
        _lauf.lage = 3
    elif id == "zeug":
        _lauf.lage = 4
    elif id == "titel":
        _lauf.lage = 0
