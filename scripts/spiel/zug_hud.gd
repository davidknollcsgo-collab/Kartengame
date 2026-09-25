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


func _ready() -> void:
    _lauf = get_parent().get_parent() as Node2D
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


func _knopf(id: String, r: Rect2, text: String, aktiv := true) -> void:
    _felder.append({"id": id, "r": r, "aktiv": aktiv})
    var farbe := TINTE if aktiv else SEPIA
    _tafel(r, 0.62 if aktiv else 0.3)
    _kasten(r, Color(farbe.r, farbe.g, farbe.b, 0.9 if aktiv else 0.4))
    _mitte(text, r, 32, Color(farbe.r, farbe.g, farbe.b, 1.0 if aktiv else 0.5))


func _mitte(text: String, r: Rect2, groesse: int, farbe: Color) -> void:
    var f := ThemeDB.fallback_font
    var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
    _worte.append({"f": f, "wo": Vector2(r.position.x + (r.size.x - w) * 0.5,
        r.position.y + r.size.y * 0.5 + groesse * 0.36), "text": text,
        "groesse": groesse, "farbe": farbe})


func _zeile(text: String, wo: Vector2, groesse: int, farbe: Color) -> void:
    _worte.append({"f": ThemeDB.fallback_font, "wo": wo, "text": text,
        "groesse": groesse, "farbe": farbe})


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
        breite: float) -> void:
    var f := ThemeDB.fallback_font
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
    if bis.x - von.x < 1.0:
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
    var oben := _rand() + _luft(230.0 + float(Helden.NAMEN.size()) * 130.0 + 136.0)
    var f := ThemeDB.fallback_font
    var t := "TEN THOUSAND"
    var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
    _zeile(t, Vector2((b - w) * 0.5, oben + 108.0), 58, TINTE)
    _tu.zug(Vector2((b - w) * 0.5 - 8.0, oben + 132.0),
        Vector2((b + w) * 0.5 + 8.0, oben + 136.0), 6.0,
        Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.85), 0.35, 0.5, 3.0, 7)
    var u := "One blade. Ten thousand of them."
    var uw := f.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
    _zeile(u, Vector2((b - uw) * 0.5, oben + 174.0), 27,
        Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))

    var s := Burg.stand
    var y := oben + 230.0
    for h in Helden.NAMEN.size():
        var frei := Helden.ist_frei(h, s.beste_zeit, s.meiste_erschlagen,
            s.warlord_gefallen)
        var r := Rect2(38.0, y, b - 76.0, 118.0)
        _tafel(r, 0.5 if frei else 0.25)
        _kasten(r, Color(TINTE.r, TINTE.g, TINTE.b, 0.75 if frei else 0.3), 3.0)
        _zeile(Helden.name_von(h), Vector2(r.position.x + 22.0, y + 44.0), 34,
            TINTE if frei else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.6))
        var satz := Helden.lehre_von(h) if frei else Helden.bedingung_text(h)
        # **Die Zeile hoert vor den Gewaendern auf.** Sonst laeuft sie unter
        # den Farbpunkten durch, und eine Beschriftung unter einem Knopf ist
        # keine Beschriftung.
        _zeile_eng(satz, Vector2(r.position.x + 22.0, y + 80.0), 22,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95 if frei else 0.6),
            r.size.x - 44.0 - (156.0 if frei else 0.0))
        if frei:
            # **Die Karte hoert vor den Punkten auf.** Der Treffer nimmt das
            # erste Feld, das passt; laege die Karte darueber, startete jeder
            # Tipp auf ein Gewand sofort einen Lauf.
            _felder.append({"id": "held%d" % h,
                "r": Rect2(r.position, Vector2(r.size.x - 156.0, r.size.y)),
                "aktiv": true})
            _gewaender(h, r)
        y += 130.0

    _knopf("burg", Rect2(38.0, y + 14.0, (b - 92.0) * 0.5, 72.0), "KEEP")
    _knopf("zeug", Rect2(b * 0.5 + 8.0, y + 14.0, (b - 92.0) * 0.5, 72.0), "GEAR")
    if s.etwas_zu_holen():
        _tu.klecks(Vector2(38.0 + (b - 92.0) * 0.5 - 14.0, y + 26.0), 9.0,
            ZINNOBER, 3)
    if s.laeufe > 0:
        var z := "best %d:%02d   /   %d felled   /   %d coin" % [
            int(s.beste_zeit) / 60, int(s.beste_zeit) % 60,
            s.meiste_erschlagen, s.sold]
        var zw := ThemeDB.fallback_font.get_string_size(z,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
        _zeile(z, Vector2((b - zw) * 0.5, y + 122.0), 23,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.9))


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

    # **Das Leben ist die lauteste Anzeige**, denn es ist der einzige Grund,
    # warum ein Lauf endet.
    _balken(Rect2(26.0, oben + 14.0, b - 52.0, 22.0),
        st.leben / maxf(1.0, st.leben_voll), ZINNOBER)
    # Erfahrung darunter, schmaler: sie endet nichts, sie verspricht nur.
    var noetig := float(Gunst.stufenkosten(st.stufe))
    _balken(Rect2(26.0, oben + 42.0, b - 52.0, 10.0),
        float(st.erfahrung) / maxf(1.0, noetig), GOLD)

    var m := int(st.zeit) / 60
    var sek := int(st.zeit) % 60
    _zeile("%d:%02d" % [m, sek], Vector2(26.0, oben + 92.0), 34, TINTE)
    _zeile("LV %d" % st.stufe, Vector2(b - 130.0, oben + 92.0), 30, TINTE)
    _zeile("%d slain" % st.erschlagen, Vector2(26.0, oben + 124.0), 22,
        Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))
    _zeile("%d coin" % st.sold, Vector2(b - 130.0, oben + 122.0), 22,
        Color(GOLD.r, GOLD.g, GOLD.b, 0.95))

    if st.wartet_auf_wahl:
        _aufstieg(st)
        return

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
    var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, gross).x
    var u := "One blade. Ten thousand of them."
    var klein := int(gross * 0.42)
    var uw := f.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, klein).x
    var mitte := h * 0.2
    _tafel(Rect2((b - w) * 0.5 - gross * 0.6, mitte - gross * 1.15,
        w + gross * 1.2, gross * 2.2), 0.78)
    _zeile(t, Vector2((b - w) * 0.5, mitte + gross * 0.12), gross, TINTE)
    _tu.zug(Vector2((b - w) * 0.5 - 8.0, mitte + gross * 0.34),
        Vector2((b + w) * 0.5 + 8.0, mitte + gross * 0.38), gross * 0.1,
        Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.85), 0.35, 0.5, 3.0, 7)
    _zeile(u, Vector2((b - uw) * 0.5, mitte + gross * 0.86), klein,
        Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))


func _aufstieg(st: Gefecht.Stand) -> void:
    var b := size.x
    var h := size.y
    # Der Schirm wird ausgeblendet: die Wahl ist das Einzige, was jetzt gilt.
    _tu.wisch(Vector2(-40.0, h * 0.5), Vector2(b + 40.0, h * 0.5), h * 1.2,
        Color(HELL.r, HELL.g, HELL.b, 0.82))
    var f := ThemeDB.fallback_font
    var t := "CHOOSE"
    var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
    _zeile(t, Vector2((b - w) * 0.5, h * 0.20), 44, TINTE)

    var y := h * 0.26
    for i in st.angebote.size():
        var a = st.angebote[i]
        var r := Rect2(40.0, y, b - 80.0, 140.0)
        _tafel(r, 0.72)
        _kasten(r, Color(TINTE.r, TINTE.g, TINTE.b, 0.85), 4.0)
        var kopf: String = a.name()
        var marke := "NEW" if a.neu else "%d" % a.stufe
        _zeile(kopf, Vector2(r.position.x + 24.0, y + 50.0), 34, TINTE)
        var mw := f.get_string_size(marke, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
        _zeile(marke, Vector2(r.position.x + r.size.x - 24.0 - mw, y + 48.0), 30,
            ZINNOBER if a.neu else Color(GOLD.r, GOLD.g, GOLD.b, 1.0))
        _zeile(a.lehre(), Vector2(r.position.x + 24.0, y + 92.0), 22,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.98))
        _felder.append({"id": "wahl%d" % i, "r": r, "aktiv": true})
        y += 156.0


func _ende() -> void:
    var st: Gefecht.Stand = _lauf.stand()
    var b := size.x
    var gewonnen: bool = st != null and st.warlord_gefallen
    var f := ThemeDB.fallback_font
    var kopf := "THE FIELD IS YOURS" if gewonnen else "YOU FALL"
    var kw := f.get_string_size(kopf, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
    _tafel(Rect2(b * 0.08, 300.0, b * 0.84, 470.0), 0.75)
    _zeile(kopf, Vector2((b - kw) * 0.5, 368.0), 42,
        TINTE if gewonnen else ZINNOBER)
    if st != null:
        var zeilen := [
            "lasted   %d:%02d" % [int(st.zeit) / 60, int(st.zeit) % 60],
            "slain    %d" % st.erschlagen,
            "coin     %d" % st.sold,
            "level    %d" % st.stufe,
        ]
        var y := 430.0
        for z in zeilen:
            var zw := f.get_string_size(z, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
            _zeile(z, Vector2((b - zw) * 0.5, y), 30,
                Color(TINTE.r, TINTE.g, TINTE.b, 0.9))
            y += 44.0
        var fu: int = _lauf.fund()
        if fu >= 0:
            var ft := "found  %s  %d" % [Ausruestung.name_von(fu),
                _lauf.fund_stufe()]
            var fw := f.get_string_size(ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
            _zeile(ft, Vector2((b - fw) * 0.5, y + 14.0), 28, GOLD)
    # **Kein Angebot nach einer Niederlage.** Zwei Wege, nie mehr.
    _knopf("nochmal", Rect2(b * 0.14, 840.0, b * 0.72, 84.0), "AGAIN")
    _knopf("titel", Rect2(b * 0.14, 942.0, b * 0.72, 68.0), "BACK")


func _burg() -> void:
    var b := size.x
    var oben := _rand() + _luft(100.0 + float(Halle.NAMEN.size()) * 164.0 + 162.0)
    var s := Burg.stand
    _zeile("THE KEEP", Vector2(38.0, oben + 62.0), 42, TINTE)
    var e := "%d coin" % s.sold
    var ew := ThemeDB.fallback_font.get_string_size(e,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
    _zeile(e, Vector2(b - 38.0 - ew, oben + 60.0), 30, GOLD)

    var y := oben + 100.0
    for bau in Halle.NAMEN.size():
        var r := Rect2(34.0, y, b - 68.0, 152.0)
        _tafel(r, 0.5)
        var stufe := s.stufe(bau)
        var voll := stufe >= Halle.HOECHSTSTUFE
        _zeile("%s  %d" % [Halle.name_von(bau), stufe],
            Vector2(r.position.x + 20.0, y + 42.0), 32, TINTE)
        _zeile_eng(Halle.beschreibung_von(bau),
            Vector2(r.position.x + 20.0, y + 76.0), 21,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), r.size.x - 40.0)
        _balken(Rect2(r.position.x + 20.0, y + 96.0, r.size.x - 220.0, 8.0),
            float(stufe) / float(Halle.HOECHSTSTUFE), TINTE)
        _knopf("bau%d" % bau, Rect2(r.position.x + r.size.x - 178.0, y + 92.0,
            158.0, 46.0), "MAX" if voll else "%d" % s.kosten(bau),
            s.kann_bauen(bau))
        y += 164.0
    # **Ton und Beben lassen sich abschalten.** Ein Telefon, das bei jedem
    # Treffer brummt und sich nicht zum Schweigen bringen laesst, spielt man
    # nicht in der Bahn - und die Datenschutzerklaerung verspricht den
    # Schalter. Er steht in der Burg, weil sie der einzige Schirm ist, der
    # ohnehin Einstellungen am Spieler vornimmt.
    var halb := (b - 92.0) * 0.5
    _knopf("ton", Rect2(38.0, y + 10.0, halb, 56.0),
        "SOUND ON" if s.laut > 0.001 else "SOUND OFF")
    _knopf("beben", Rect2(b * 0.5 + 8.0, y + 10.0, halb, 56.0),
        "RUMBLE ON" if s.beben else "RUMBLE OFF")
    _knopf("titel", Rect2(b * 0.24, y + 86.0, b * 0.52, 66.0), "BACK")


func _zeug() -> void:
    var b := size.x
    var oben := _rand() + _luft(100.0
        + float(Ausruestung.PLATZ_NAMEN.size()) * 96.0 + 96.0)
    var s := Burg.stand
    _zeile("WHAT YOU CARRY", Vector2(38.0, oben + 62.0), 38, TINTE)

    var y := oben + 100.0
    for platz in Ausruestung.PLATZ_NAMEN.size():
        # Auf halber Kartenhoehe, nicht an ihrer Oberkante: sonst steht der
        # Platzname zwischen zwei Reihen und gehoert scheinbar zur falschen.
        _zeile(Ausruestung.platz_name(platz), Vector2(38.0, y + 50.0), 24,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))
        var x := 150.0
        var getragen := int(s.angelegt.get(platz, -1))
        for stueck in Ausruestung.Stueck.size():
            if Ausruestung.platz_von(stueck) != platz:
                continue
            var stufe := int(s.besitz.get(stueck, 0))
            var r := Rect2(x, y, (b - 190.0) * 0.5, 84.0)
            var hat := stufe > 0
            _tafel(r, 0.55 if hat else 0.22)
            _kasten(r, Color(TINTE.r, TINTE.g, TINTE.b,
                0.9 if stueck == getragen else (0.45 if hat else 0.2)),
                5.0 if stueck == getragen else 3.0)
            _zeile_eng(Ausruestung.name_von(stueck),
                Vector2(r.position.x + 14.0, y + 34.0), 21,
                TINTE if hat else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.45),
                r.size.x - 28.0)
            _zeile_eng(Ausruestung.lehre_von(stueck, stufe) if hat else "not found",
                Vector2(r.position.x + 14.0, y + 62.0), 19,
                Color(GOLD.r, GOLD.g, GOLD.b, 0.95) if hat
                    else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.4),
                r.size.x - 28.0)
            if hat:
                _felder.append({"id": "lege%d" % stueck, "r": r, "aktiv": true})
            x += (b - 190.0) * 0.5 + 10.0
        y += 96.0
    _knopf("titel", Rect2(b * 0.24, y + 20.0, b * 0.52, 66.0), "BACK")


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
