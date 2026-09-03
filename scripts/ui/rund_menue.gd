extends CanvasLayer

## Der Titelbildschirm - und der Bericht nach der Fahrt.
##
## Nach dem Entwurf, den der Spieler vorgelegt hat: Logo links oben, darunter
## eine Spalte Sechseckknoepfe, und **dahinter laeuft das Spiel weiter**. Ein
## Standbild sagt "hier waere ein Spiel"; eine laufende Szene sagt, wie es
## aussieht. Das kostet nichts - die Szene laeuft ohnehin.
##
## Alles gezeichnet, keine Bilddatei. Das ist hier keine Stilfrage: `ASSETS.md`
## fuehrt keine einzige Grafik, `tools/lizenzcheck.gd` erzwingt das, und
## STORE.md sagt dem Laden zu, dass alles Sichtbare vom Programm selbst
## erzeugt wird. Ein Logo als PNG waere der erste Eintrag - und damit der
## Anfang vom Ende dieses Nachweises.

const RAND := 22.0
const SCHRIFT := Color(0.86, 0.96, 1.0)
const LEISE := Color(0.48, 0.68, 0.74)
const HELL := Color(0.42, 0.92, 0.94)
const RAHMEN := Color(0.30, 0.62, 0.66)

## Die Knoepfe. Deutsch im Bezeichner, englisch auf dem Schirm - so wie
## ueberall hier.
const KNOEPFE: Array[Dictionary] = [
    {&"kennung": &"SPIELEN", &"text": "PLAY"},
    {&"kennung": &"AUSBAU", &"text": "COLONY"},
    {&"kennung": &"LINIEN", &"text": "LINES"},
    {&"kennung": &"TAG", &"text": "DAILY"},
    # Die alte Schleife bleibt erreichbar. Sie ist fertig, geprueft und
    # verkaufbar - sie hinter einem Kommandozeilenschalter zu begraben, waere
    # das Wegwerfen von Monaten.
    {&"kennung": &"SCHLUND", &"text": "TRENCH WATCH"},
]

var lauf: Node = null

var _flaeche: Control
var _schrift: Font
var _zeit := 0.0
var _felder: Array[Rect2] = []


func _ready() -> void:
    layer = 20
    _flaeche = Control.new()
    _flaeche.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flaeche)
    _flaeche.draw.connect(_zeichne)
    _schrift = ThemeDB.fallback_font


func _process(delta: float) -> void:
    _zeit += delta
    visible = lauf != null and lauf.lage != lauf.Lage.SPIEL \
        and not lauf.kolonie_offen()
    if visible:
        _flaeche.queue_redraw()


func _input(ereignis: InputEvent) -> void:
    if not visible:
        return
    var ort := Vector2.ZERO
    if ereignis is InputEventScreenTouch and ereignis.pressed:
        ort = ereignis.position
    elif ereignis is InputEventMouseButton and ereignis.pressed \
            and ereignis.button_index == MOUSE_BUTTON_LEFT:
        ort = ereignis.position
    else:
        return
    for i in _felder.size():
        if _felder[i].has_point(ort):
            match lauf.lage:
                lauf.Lage.ENDE:
                    _gewaehlt_am_ende(i)
                lauf.Lage.PAUSE:
                    _gewaehlt_in_pause(i)
                _:
                    _gewaehlt(i)
            return


func _gewaehlt(i: int) -> void:
    Klang.spiele(Klang.Ton.TIPP)
    match KNOEPFE[i][&"kennung"]:
        &"SPIELEN":
            lauf.starte()
        &"SCHLUND":
            get_tree().change_scene_to_file("res://scenes/schlund.tscn")
        &"AUSBAU":
            lauf.oeffne_kolonie(0)
        &"LINIEN":
            # Die Brutlinien sind ein Reiter desselben Bildschirms und kein
            # eigener. Ein zweiter Weg zu denselben Daten waere eine zweite
            # Stelle, an der sie falsch stehen koennen.
            lauf.oeffne_kolonie(1)
        &"TAG":
            lauf.oeffne_kolonie(4)
        _:
            pass


## In der Pause gibt es drei Wege: weiter, bauen, abbrechen.
func _gewaehlt_in_pause(i: int) -> void:
    Klang.spiele(Klang.Ton.TIPP)
    match i:
        0:
            lauf.weiter()
        1:
            lauf.oeffne_kolonie(0)
        _:
            lauf.brich_ab()


## Die Pausentafel.
##
## **Sie zeigt den Stand der laufenden Fahrt, nicht nur Knoepfe.** Wer
## pausiert, tut das meistens, weil er etwas wissen will - wie weit er ist,
## wieviel er verdient hat -, und ein Schirm, der darauf keine Antwort gibt,
## schickt ihn zurueck ins Spiel, um sie sich zusammenzusuchen.
func _zeichne_pause(breite: float, hoehe: float) -> void:
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe),
        Color(0.010, 0.030, 0.042, 0.70))
    var oben := hoehe * 0.24
    _text(Vector2(breite * 0.5, oben), "PAUSED", 30, HELL, true, 6.0)
    _text(Vector2(breite * 0.5, oben + 26.0),
        "WAVE %d  ·  %s NUTRIENT  ·  %d KILLS"
        % [int(lauf.welle_nummer), Zahl.kurz(int(lauf.verdient)),
        int(lauf.erlegt)], 12, LEISE, true, 1.6)

    _felder.clear()
    var texte: PackedStringArray = ["RESUME", "COLONY", "END DIVE"]
    var y := oben + 64.0
    for i in texte.size():
        var kasten := Rect2(RAND, y, breite - RAND * 2.0, 48.0)
        _felder.append(kasten)
        var weg := _hexweg(kasten)
        _flaeche.draw_colored_polygon(weg,
            Color(0.035, 0.115, 0.135, 0.80) if i == 0
            else Color(0.020, 0.052, 0.066, 0.72))
        var puls := 0.5 + 0.5 * sin(_zeit * 2.4)
        _flaeche.draw_polyline(weg + PackedVector2Array([weg[0]]),
            Color(HELL.r, HELL.g, HELL.b, (0.45 + 0.35 * puls) if i == 0
            else 0.26), 1.4, true)
        _text(Vector2(breite * 0.5, kasten.position.y + 31.0), texte[i], 18,
            SCHRIFT if i == 0 else LEISE, true, 2.5)
        y += 58.0
    _text(Vector2(breite * 0.5, hoehe - 56.0),
        "THE COLONY KEEPS WHAT YOU ALREADY BROUGHT BACK", 11, LEISE, true,
        1.4)


## Am Ende gibt es genau zwei Wege: noch einmal, oder zurueck.
##
## **Keine Werbung und kein Angebot an dieser Stelle.** Der Plan sagt es in
## einem Satz: niemals nach einer Niederlage - das ist die Erfahrung, die
## Ein-Stern-Bewertungen schreibt.
func _gewaehlt_am_ende(i: int) -> void:
    Klang.spiele(Klang.Ton.TIPP)
    match i:
        0:
            lauf.starte()
        1:
            # **Der Ausbau gehoert hierher.** Nach der Fahrt liegt der
            # Naehrstoff frisch in der Kolonie, und das ist der Moment, in
            # dem man ihn ausgeben will. Ein Weg dorthin, der ueber das
            # Titelbild fuehrt, ist ein Weg, den die Haelfte nicht findet.
            lauf.oeffne_kolonie()
        _:
            lauf.lage = lauf.Lage.MENUE


## Der Bericht: was diese Fahrt eingebracht hat.
##
## Der Naehrstoff steht oben und die Punkte darunter, und das ist keine
## Geschmacksfrage: der Naehrstoff **bleibt** - er liegt schon in der Kolonie,
## weil er je erlegtem Tier faellt. Die Punkte sind eine Bestmarke und mit der
## Fahrt vorbei. Was bleibt, gehoert nach oben.
func _zeichne_ende(breite: float, hoehe: float) -> void:
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe),
        Color(0.010, 0.030, 0.042, 0.72))
    var oben := hoehe * 0.20
    # **Dasselbe Blatt in zwei Farben.** Gehalten und gebrochen zeigen
    # dieselben Zahlen - was sich unterscheidet, ist eine Zeile und ein
    # Farbton. Zwei getrennte Bildschirme dafuer waeren zwei Stellen, an
    # denen dieselbe Zahl falsch stehen kann.
    var geschafft: bool = lauf.gehalten
    var ton := Color(0.42, 0.94, 0.80) if geschafft else Color(1.0, 0.42, 0.34)
    _text(Vector2(breite * 0.5, oben),
        "DIVE COMPLETE" if geschafft else "HULL BREACHED", 30, ton, true, 5.0)
    _text(Vector2(breite * 0.5, oben + 26.0),
        "THE COLONY KEEPS WHAT YOU BROUGHT BACK", 12, LEISE, true, 1.6)

    var zeilen: Array[Array] = [
        ["NUTRIENT", Zahl.kurz(int(lauf.verdient))],
        ["SCORE", Zahl.kurz(int(lauf.punkte))],
        ["WAVE", str(int(lauf.welle_nummer))],
        ["KILLS", str(int(lauf.erlegt))],
        ["SITES", str(int(lauf.funde))],
        ["BEST CHAIN", "x%.1f" % Graben.kette_faktor(int(lauf.kette_hoechste))],
    ]
    var y := oben + 66.0
    for i in zeilen.size():
        var kasten := Rect2(RAND, y, breite - RAND * 2.0, 34.0)
        if i == 0:
            _flaeche.draw_colored_polygon(_hexweg(kasten, 10.0),
                Color(0.035, 0.115, 0.135, 0.60))
        _text(kasten.position + Vector2(18.0, 23.0), String(zeilen[i][0]),
            13, LEISE, false, 2.4)
        _text(Vector2(kasten.end.x - 18.0, kasten.position.y + 24.0),
            String(zeilen[i][1]), 20,
            HELL if i == 0 else SCHRIFT, false, 1.0, true)
        y += 38.0

    _felder.clear()
    var texte: PackedStringArray = ["DIVE AGAIN", "COLONY", "SURFACE"]
    if lauf.gehalten:
        texte[0] = "DIVE DEEPER"
    y += 14.0
    for i in texte.size():
        var kasten := Rect2(RAND, y, breite - RAND * 2.0, 48.0)
        _felder.append(kasten)
        var weg := _hexweg(kasten)
        _flaeche.draw_colored_polygon(weg,
            Color(0.035, 0.115, 0.135, 0.80) if i == 0
            else Color(0.020, 0.052, 0.066, 0.72))
        var puls := 0.5 + 0.5 * sin(_zeit * 2.4)
        _flaeche.draw_polyline(weg + PackedVector2Array([weg[0]]),
            Color(HELL.r, HELL.g, HELL.b, (0.45 + 0.35 * puls) if i == 0
            else 0.26), 1.4, true)
        _text(Vector2(breite * 0.5, kasten.position.y + 31.0), texte[i], 18,
            SCHRIFT if i == 0 else LEISE, true, 2.5)
        y += 58.0


func _hexweg(kasten: Rect2, schraege := 14.0) -> PackedVector2Array:
    var s := minf(schraege, kasten.size.y * 0.5)
    return PackedVector2Array([
        kasten.position + Vector2(s, 0.0),
        Vector2(kasten.end.x - s, kasten.position.y),
        Vector2(kasten.end.x, kasten.position.y + s),
        Vector2(kasten.end.x, kasten.end.y - s),
        Vector2(kasten.end.x - s, kasten.end.y),
        Vector2(kasten.position.x + s, kasten.end.y),
        Vector2(kasten.position.x, kasten.end.y - s),
        Vector2(kasten.position.x, kasten.position.y + s),
    ])


## `rechts` setzt den Text linksbuendig **an** `wo` endend. Im Bericht stehen
## Zahlen rechts am Rand; ohne das muesste jede Zeile ihre Breite selbst
## ausmessen, und die Spalte waere nur ungefaehr eine.
func _text(wo: Vector2, was: String, groesse: int, farbe: Color,
        mittig := false, sperrung := 0.0, rechts := false) -> void:
    if sperrung <= 0.0:
        var breite := _schrift.get_string_size(was, HORIZONTAL_ALIGNMENT_LEFT,
            -1, groesse).x
        var p := wo
        if mittig:
            p -= Vector2(breite * 0.5, 0.0)
        elif rechts:
            p -= Vector2(breite, 0.0)
        _flaeche.draw_string(_schrift, p, was, HORIZONTAL_ALIGNMENT_LEFT, -1,
            groesse, farbe)
        return
    # **Gesperrt gesetzt.** Der Entwurf schreibt den Titel weit auseinander,
    # und das ist kein Zierat: ein gesperrter Titel liest sich als Marke, ein
    # enger als Fliesstext. Godot kann das nicht, also Zeichen fuer Zeichen.
    var ganz := 0.0
    for z in was:
        ganz += _schrift.get_string_size(z, HORIZONTAL_ALIGNMENT_LEFT, -1,
            groesse).x + sperrung
    var x := wo.x
    if mittig:
        x -= ganz * 0.5
    elif rechts:
        x -= ganz
    for z in was:
        _flaeche.draw_string(_schrift, Vector2(x, wo.y), z,
            HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)
        x += _schrift.get_string_size(z, HORIZONTAL_ALIGNMENT_LEFT, -1,
            groesse).x + sperrung


func _zeichne() -> void:
    var breite := _flaeche.size.x
    var hoehe := _flaeche.size.y
    if lauf.lage == lauf.Lage.ENDE:
        _zeichne_ende(breite, hoehe)
        return
    if lauf.lage == lauf.Lage.PAUSE:
        _zeichne_pause(breite, hoehe)
        return

    # Ein Schleier ueber der laufenden Szene. Ohne ihn steht die Schrift im
    # Gewimmel und ist nicht zu lesen; mit zu viel davon sieht man nicht
    # mehr, dass dahinter etwas laeuft.
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe),
        Color(0.010, 0.030, 0.042, 0.52))

    var oben := hoehe * 0.16
    _text(Vector2(RAND + 6.0, oben), "NEKTON", 46, SCHRIFT, false, 9.0)
    _text(Vector2(RAND + 10.0, oben + 30.0), "DEEP GUARD", 17, HELL, false, 7.0)

    _felder.clear()
    var y := oben + 74.0
    for i in KNOEPFE.size():
        var kasten := Rect2(RAND, y, 232.0, 46.0)
        _felder.append(kasten)
        var erste := i == 0
        var weg := _hexweg(kasten)
        _flaeche.draw_colored_polygon(weg,
            Color(0.035, 0.115, 0.135, 0.80) if erste
            else Color(0.020, 0.052, 0.066, 0.72))
        var zu := weg + PackedVector2Array([weg[0]])
        # Der erste Knopf atmet. Er ist der einzige, den man beim ersten Mal
        # druecken soll, und ein Ring, der sich bewegt, sagt das ohne Wort.
        var puls := 0.5 + 0.5 * sin(_zeit * 2.4)
        _flaeche.draw_polyline(zu, Color(HELL.r, HELL.g, HELL.b,
            (0.45 + 0.35 * puls) if erste else 0.26), 1.4, true)
        if erste:
            _dreieck(kasten.position + Vector2(24.0, kasten.size.y * 0.5),
                9.0, HELL)
        _text(kasten.position + Vector2(44.0, 30.0),
            String(KNOEPFE[i][&"text"]), 18,
            SCHRIFT if erste else LEISE, false, 2.5)
        y += 56.0

    # Der Satz aus dem Entwurf, unten. Er sagt in drei Woertern, was die
    # Sitzung ist - und er ist das Einzige hier, was Werbung sein darf.
    _text(Vector2(breite * 0.5, hoehe - 74.0),
        "DARK. FAST. ONE MORE DIVE.", 17, HELL, true, 2.0)
    _text(Vector2(breite * 0.5, hoehe - 50.0),
        "SURVIVE. BUILD. GO DEEPER.", 13, LEISE, true, 2.0)


## Das Abspielzeichen im ersten Knopf.
func _dreieck(mitte: Vector2, r: float, farbe: Color) -> void:
    var weg := PackedVector2Array([
        mitte + Vector2(r, 0.0),
        mitte + Vector2(-r * 0.62, r * 0.82),
        mitte + Vector2(-r * 0.62, -r * 0.82),
    ])
    _flaeche.draw_colored_polygon(weg, farbe)
