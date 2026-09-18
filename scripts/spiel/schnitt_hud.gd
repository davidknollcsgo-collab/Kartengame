extends Control

## **Das Bedienbild - auch es ist gepinselt.**
##
## Es gibt in diesem Spiel keine rechten Winkel, und das gilt fuer die
## Oberflaeche genauso wie fuer die Buehne. Ein Knopf ist hier kein Rechteck
## mit Rahmen, sondern vier Pinselstriche, die sich an den Ecken nicht ganz
## treffen - ein Kasten, den jemand gezogen hat. Fuenf gerahmte Rechtecke
## untereinander waeren ein Antragsformular, das jemand ueber die Zeichnung
## gelegt hat.
##
## **Die Wunden sind die wichtigste Anzeige im Bild**, denn sie sind der
## einzige Grund, warum eine Ronde endet. Sie stehen deshalb oben links als
## Striche und nicht als Zahl: drei Striche zaehlt man nicht, man sieht sie.

const TINTE := Color(0.09, 0.08, 0.09)
const ZINNOBER := Color(0.78, 0.16, 0.10)
const GRAU := Color(0.44, 0.43, 0.44)

var _tu := Tusche.new()
var _felder: Array = []
var _lauf: Node2D


func _ready() -> void:
    _lauf = get_parent().get_parent() as Node2D
    mouse_filter = Control.MOUSE_FILTER_PASS
    set_process(true)


func _process(_d: float) -> void:
    queue_redraw()


func _rand() -> float:
    # `get_display_safe_area()` nur auf dem Telefon fragen: auf dem
    # Schreibtisch liefert sie den ganzen Bildschirm und nicht das Fenster,
    # und aus der Differenz wird ein Rand von vierhundert Bildpunkten.
    if not OS.has_feature("mobile"):
        return 24.0
    var sicher := DisplayServer.get_display_safe_area()
    var fenster := DisplayServer.window_get_size()
    var oben := float(sicher.position.y)
    # Alles ueber zwoelf Prozent der Bildkante ist eine Fehlmessung und
    # keine Kerbe.
    return clampf(oben, 24.0, float(fenster.y) * 0.12)


# --- Pinselwerk ------------------------------------------------------------

func _kasten(r: Rect2, farbe: Color, breite := 4.0) -> void:
    # Die Striche laufen absichtlich ueber die Ecken hinaus und treffen sich
    # nicht: ein geschlossener Rahmen ist gedruckt, ein offener gezogen.
    var a := r.position
    var b := r.position + r.size
    var u := r.size.x * 0.04
    _tu.zug(Vector2(a.x - u, a.y), Vector2(b.x + u * 0.4, a.y - 2.0),
        breite, farbe, 0.4, 0.3, 2.0, 6)
    _tu.zug(Vector2(b.x, a.y - u * 0.3), Vector2(b.x + 2.0, b.y + u * 0.5),
        breite, farbe, 0.4, 0.3, 2.0, 6)
    _tu.zug(Vector2(b.x + u * 0.4, b.y), Vector2(a.x - u * 0.6, b.y + 2.0),
        breite, farbe, 0.4, 0.3, 2.0, 6)
    _tu.zug(Vector2(a.x, b.y + u * 0.3), Vector2(a.x - 2.0, a.y - u * 0.4),
        breite, farbe, 0.4, 0.3, 2.0, 6)


func _wisch_tafel(r: Rect2, deckung: float) -> void:
    _tu.wisch(Vector2(r.position.x, r.position.y + r.size.y * 0.5),
        Vector2(r.position.x + r.size.x, r.position.y + r.size.y * 0.5),
        r.size.y, Color(0.99, 0.985, 0.97, deckung))


func _knopf(id: String, r: Rect2, text: String, aktiv := true) -> void:
    _felder.append({"id": id, "r": r, "aktiv": aktiv})
    var farbe := TINTE if aktiv else GRAU
    _wisch_tafel(r, 0.55 if aktiv else 0.3)
    _kasten(r, Color(farbe.r, farbe.g, farbe.b, 0.85 if aktiv else 0.4), 4.0)
    _schrift(text, r, 34, Color(farbe.r, farbe.g, farbe.b, 1.0 if aktiv else 0.5))


func _schrift(text: String, r: Rect2, groesse: int, farbe: Color,
        oben := false) -> void:
    var f := ThemeDB.fallback_font
    var breite := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse).x
    var y := r.position.y + (groesse * 0.8 if oben
        else r.size.y * 0.5 + groesse * 0.36)
    draw_string(f, Vector2(r.position.x + (r.size.x - breite) * 0.5, y),
        text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)


func _zeile(text: String, wo: Vector2, groesse: int, farbe: Color) -> void:
    draw_string(ThemeDB.fallback_font, wo, text, HORIZONTAL_ALIGNMENT_LEFT,
        -1, groesse, farbe)


# --- Das Bild --------------------------------------------------------------

func _draw() -> void:
    _felder.clear()
    if _lauf == null:
        return
    var b := size.x
    var oben := _rand()
    match _lauf.lage:
        0:
            _titel(b, oben)
        1:
            _duell(b, oben)
        2:
            _ende(b, oben)
        3:
            _schule(b, oben)
    _tu.spuele(get_canvas_item())


func _titel(b: float, oben: float) -> void:
    var f := ThemeDB.fallback_font
    var t := "HUNDRED CUTS"
    var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 62).x
    _zeile(t, Vector2((b - w) * 0.5, oben + 150.0), 62, TINTE)
    # Ein Zinnoberstrich unter dem Titel: das Siegel des Blattes.
    _tu.zug(Vector2((b - w) * 0.5 - 6.0, oben + 178.0),
        Vector2((b + w) * 0.5 + 6.0, oben + 182.0), 7.0,
        Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.85), 0.35, 0.5, 3.0, 8)
    var u := "Read the line. Meet the line."
    var uw := f.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
    _zeile(u, Vector2((b - uw) * 0.5, oben + 226.0), 30,
        Color(GRAU.r, GRAU.g, GRAU.b, 0.9))

    var s := Weg.stand
    _knopf("spielen", Rect2(b * 0.22, 1010.0, b * 0.56, 84.0),
        "ROUND %d" % s.naechste_ronde())
    _knopf("schule", Rect2(b * 0.22, 1112.0, b * 0.56, 72.0), "SCHOOL")
    if s.etwas_zu_holen():
        # Ein Punkt sagt, dass dort etwas liegt. Eine Belohnung, die das
        # nicht sagt, holt niemand ab.
        _tu.klecks(Vector2(b * 0.78 - 16.0, 1148.0), 9.0, ZINNOBER, 3)
    if s.beste_kette > 0:
        var z := "best chain %d   /   %d felled" % [s.beste_kette,
            s.gefaellt_gesamt]
        var zw := ThemeDB.fallback_font.get_string_size(z,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
        _zeile(z, Vector2((b - zw) * 0.5, 1222.0), 26,
            Color(GRAU.r, GRAU.g, GRAU.b, 0.8))


func _duell(b: float, oben: float) -> void:
    var st: Duell.Stand = _lauf.stand()
    if st == null:
        return
    # **Die Wunden.** Ein Strich je Atemzug, der verbrauchte in Zinnober
    # durchgestrichen. Man zaehlt sie nicht, man sieht sie.
    for i in st.atem_voll:
        var x := 34.0 + float(i) * 26.0
        var y := oben + 34.0
        var lebt := i < st.atem
        _tu.zug(Vector2(x, y), Vector2(x + 4.0, y + 40.0), 7.0,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.9 if lebt else 0.18),
            0.3, 0.4, 1.5, 5)
        if not lebt:
            _tu.zug(Vector2(x - 8.0, y + 32.0), Vector2(x + 14.0, y + 6.0),
                5.0, Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.75),
                0.3, 0.5, 1.0, 4)

    _zeile("ROUND %d" % _lauf.ronde(), Vector2(b - 176.0, oben + 40.0), 30,
        Color(TINTE.r, TINTE.g, TINTE.b, 0.8))
    _zeile("%d left" % st.offen(), Vector2(b - 176.0, oben + 76.0), 26,
        Color(GRAU.r, GRAU.g, GRAU.b, 0.9))

    # Die Kette waechst nach oben aus der Mitte - sie ist der einzige Wert,
    # den man im Kampf wirklich verfolgt.
    if st.kette > 1:
        var k := "%d" % st.kette
        var kw := ThemeDB.fallback_font.get_string_size(k,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
        _zeile(k, Vector2((b - kw) * 0.5, oben + 96.0), 54,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b,
                clampf(0.35 + float(st.kette) * 0.06, 0.0, 0.95)))

    var m: String = _lauf.meldung()
    if m != "":
        var mw := ThemeDB.fallback_font.get_string_size(m,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
        _zeile(m, Vector2((b - mw) * 0.5, 420.0), 44,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.85))

    var e: String = _lauf.einstieg_satz()
    if e != "":
        var ew := ThemeDB.fallback_font.get_string_size(e,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
        _zeile(e, Vector2((b - ew) * 0.5, 1180.0), 27,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.75))


func _ende(b: float, oben: float) -> void:
    var st: Duell.Stand = _lauf.stand()
    var gewonnen: bool = st != null and st.lebt()
    var kopf := "ROUND CLEARED" if gewonnen else "CUT DOWN"
    var f := ThemeDB.fallback_font
    var kw := f.get_string_size(kopf, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
    _wisch_tafel(Rect2(b * 0.10, 330.0, b * 0.80, 400.0), 0.72)
    _zeile(kopf, Vector2((b - kw) * 0.5, 400.0), 52,
        TINTE if gewonnen else ZINNOBER)
    if st != null:
        var zeilen := [
            "honour   %d" % st.ehre,
            "felled   %d" % st.gefaellt,
            "chain    %d" % st.beste_kette,
            "in hand  %d" % Weg.stand.ehre,
        ]
        var y := 470.0
        for z in zeilen:
            var zw := f.get_string_size(z, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
            _zeile(z, Vector2((b - zw) * 0.5, y), 32,
                Color(TINTE.r, TINTE.g, TINTE.b, 0.88))
            y += 46.0
    # **Kein Angebot an dieser Stelle.** Nach einer Niederlage wird nicht
    # verkauft - nie.
    _knopf("spielen", Rect2(b * 0.16, 830.0, b * 0.68, 84.0),
        "ROUND %d" % Weg.stand.naechste_ronde())
    _knopf("schule", Rect2(b * 0.16, 932.0, b * 0.68, 72.0), "SCHOOL")
    _knopf("titel", Rect2(b * 0.16, 1024.0, b * 0.68, 62.0), "BACK")


func _schule(b: float, oben: float) -> void:
    var s := Weg.stand
    var f := ThemeDB.fallback_font
    _zeile("THE SCHOOL", Vector2(40.0, oben + 70.0), 46, TINTE)
    var e := "honour %d" % s.ehre
    var ew := f.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
    _zeile(e, Vector2(b - 40.0 - ew, oben + 68.0), 32,
        Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.9))

    var y := oben + 120.0
    for h in Schule.NAMEN.size():
        var r := Rect2(36.0, y, b - 72.0, 168.0)
        _wisch_tafel(r, 0.5)
        var stufe := s.stufe(h)
        var voll := stufe >= Schule.HOECHSTSTUFE
        _zeile("%s  %d" % [Schule.name_von(h), stufe],
            Vector2(r.position.x + 22.0, y + 46.0), 36, TINTE)
        _zeile(Schule.beschreibung_von(h),
            Vector2(r.position.x + 22.0, y + 82.0), 24,
            Color(GRAU.r, GRAU.g, GRAU.b, 0.95))
        # Der Balken misst die Stufe an der Hoechststufe: er sagt, wie weit
        # die Halle noch kann - die Zahl daneben, was sie jetzt tut.
        var bl := (r.size.x - 44.0) * float(stufe) / float(Schule.HOECHSTSTUFE)
        _tu.zug(Vector2(r.position.x + 22.0, y + 104.0),
            Vector2(r.position.x + 22.0 + maxf(4.0, bl), y + 104.0), 5.0,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.35), 0.5, 0.2, 1.0, 5)
        var kann := s.kann_bauen(h)
        var text := "MASTERED" if voll else "%d" % s.kosten(h)
        _knopf("bau%d" % h, Rect2(r.position.x + r.size.x - 186.0, y + 112.0,
            164.0, 48.0), text, kann)
        y += 182.0

    _knopf("titel", Rect2(b * 0.22, y + 8.0, b * 0.56, 68.0), "BACK")


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
    # Im Duell gehoert der Finger der Klinge. Das Bedienbild fasst dort
    # nichts an - ein Knopf, der einen Wisch verschluckt, kostet eine Wunde.
    if _lauf.lage == 1:
        return
    for feld in _felder:
        if not feld["r"].has_point(ort):
            continue
        if not feld["aktiv"]:
            accept_event()
            return
        _gewaehlt(String(feld["id"]))
        accept_event()
        return


func _gewaehlt(id: String) -> void:
    Stahl.spiele(Stahl.Ton.TIPP)
    if id == "spielen":
        _lauf.beginne_ronde(Weg.stand.naechste_ronde())
    elif id == "schule":
        _lauf.lage = 3
    elif id == "titel":
        _lauf.lage = 0
    elif id.begins_with("bau"):
        var h := int(id.substr(3))
        if Weg.baue(h):
            Stahl.spiele(Stahl.Ton.PARADE, 1.6, 0.5)
