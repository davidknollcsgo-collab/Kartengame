extends CanvasLayer

## Das Bedienbild des Rundumlaufs.
##
## **Vorher gab es keins.** Man sah das Boot fahren und sonst nichts - nicht,
## in welcher Welle man ist, nicht wieviel Huelle noch steht, nicht ob das
## Stosslicht geladen hat.
##
## Der Zuschnitt folgt einem Entwurf, den der Spieler vorgelegt hat: Zahlen
## in Sechseckrahmen an den Ecken, segmentierte Balken statt glatter, ein
## Warnband bei einem Leitwesen. Die Farben bleiben die des Spiels - ein
## fremdes Blau haette den Graben zu einem anderen Ort gemacht.
##
## **Ein Sechseck und keine Schachtel**, und das ist keine Zierde: eine
## abgeschraegte Ecke sagt "Geraet" statt "Fenster", und sie kostet zwei
## Punkte mehr im Umriss. Gezeichnet wird er als Linienzug, wie alles hier -
## `draw_polygon` ist in Godot nicht kantengeglaettet, `draw_polyline` schon.

const RAND := 16.0
const SCHRIFT := Color(0.78, 0.94, 0.98)
const LEISE := Color(0.46, 0.66, 0.72)
const HELL := Color(0.42, 0.92, 0.94)
const WARM := Color(1.0, 0.84, 0.52)
const WARNUNG := Color(1.0, 0.42, 0.34)
const RAHMEN := Color(0.30, 0.62, 0.66)

var lauf: Node = null

## Die Raender, die das Geraet selbst braucht - Kerbe oben, Gestenbalken
## unten, gerundete Ecken an den Seiten.
##
## **Dieselbe Rechnung wie in `hud.gd`, aus demselben Grund.** Der Entwurf
## steht auf 720x1280, und dort gibt es keine Aussparungen; der Fehler
## existiert nur auf dem Geraet, fuer das gebaut wird. Der Stossknopf sass
## bis hierher fuenfzehn Punkte ueber der unteren Kante - auf einem Telefon
## mit Gestenbalken also darunter.
var _rand_oben := 0.0
var _rand_unten := 0.0
var _rand_seite := 0.0

var _flaeche: Control
var _schrift: Font
var _zeit := 0.0

## Die Tippflaechen. Sie werden beim Zeichnen gesetzt, damit Bild und
## Beruehrung nie auseinanderlaufen koennen - dieselbe Regel wie im Schlund.
var stossknopf := Rect2()

## Die Pausenflaeche oben in der Mitte. **Ein sichtbarer Knopf und nicht nur
## die Zurueck-Taste**: die gibt es im Browser nicht, auf dem Schreibtisch
## nicht, und auf einem Telefon mit Gestensteuerung findet sie nicht jeder.
var pausenknopf := Rect2()


func _ready() -> void:
    layer = 10
    _flaeche = Control.new()
    _flaeche.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flaeche)
    _flaeche.draw.connect(_zeichne)
    _schrift = ThemeDB.fallback_font


func _process(delta: float) -> void:
    _zeit += delta
    # Im Menue nicht: dort steht das Logo, und eine Huellenanzeige daneben
    # sagt nur, dass gerade niemand spielt.
    visible = lauf != null and lauf.lage == lauf.Lage.SPIEL
    if visible:
        _flaeche.queue_redraw()


# --- Bausteine ---------------------------------------------------------------

## Ein Sechseck mit abgeschraegten Ecken links und rechts.
func _hexweg(kasten: Rect2, schraege := 12.0) -> PackedVector2Array:
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


func _tafel(kasten: Rect2, farbe := RAHMEN, deckung := 0.42,
        schraege := 12.0) -> void:
    var weg := _hexweg(kasten, schraege)
    _flaeche.draw_colored_polygon(weg, Color(0.020, 0.052, 0.066, 0.72))
    var zu := weg + PackedVector2Array([weg[0]])
    _flaeche.draw_polyline(zu, Color(farbe.r, farbe.g, farbe.b, deckung),
        1.3, true)


## Ein segmentierter Balken. **Segmente, nicht ein glatter Streifen**: bei
## einem Streifen sieht man, dass etwas fehlt, aber nicht wieviel, und das
## ist genau die Zahl, die zaehlt.
## Ab wievielen Teilen der Balken glatt wird.
##
## **Segmente zaehlen nur, solange man sie zaehlen kann.** Die Huelle kommt
## aus der Brutkammer, und die geht bis Stufe 80 - das sind zweiundfuenfzig
## Eier. In einer Leiste von 158 Punkten waere jedes davon einen Punkt breit
## und der Zwischenraum zwei: eine gestrichelte Linie, aus der man nichts
## abliest. Darueber also ein glatter Balken und eine Zahl daneben.
const SEGMENTE_HOECHSTENS := 22


func _balken(kasten: Rect2, ist: int, voll: int, farbe: Color) -> void:
    if voll <= 0:
        return
    if voll > SEGMENTE_HOECHSTENS:
        _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.14))
        _flaeche.draw_rect(Rect2(kasten.position, Vector2(kasten.size.x
            * clampf(float(ist) / float(voll), 0.0, 1.0), kasten.size.y)),
            farbe)
        return
    var breit := kasten.size.x / float(voll)
    for i in voll:
        var teil := Rect2(kasten.position + Vector2(breit * float(i), 0.0),
            Vector2(breit - 2.0, kasten.size.y))
        if i < ist:
            _flaeche.draw_rect(teil, farbe)
        else:
            _flaeche.draw_rect(teil, Color(farbe.r, farbe.g, farbe.b, 0.14))


func _text(wo: Vector2, was: String, groesse: int, farbe: Color,
        mittig := false, rechts := false) -> void:
    var breite := _schrift.get_string_size(was, HORIZONTAL_ALIGNMENT_LEFT,
        -1, groesse).x
    var p := wo
    if mittig:
        p.x -= breite * 0.5
    elif rechts:
        p.x -= breite
    _flaeche.draw_string(_schrift, p, was, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse, farbe)


# --- Das Bild ----------------------------------------------------------------

## Nur auf dem Telefon fragen: auf dem Schreibtisch liefert
## `get_display_safe_area()` den ganzen Bildschirm und nicht das Fenster
## (Zusage 17). Und gedeckelt, weil kein Geraet sich ein Achtel des Bildes
## nimmt - was darueber liegt, ist eine Fehlmessung und keine Kerbe.
func _miss_geraeterand() -> void:
    if not OS.has_feature("mobile"):
        return
    var fenster := DisplayServer.window_get_size()
    if fenster.x <= 0 or fenster.y <= 0 or _flaeche.size.x <= 0.0:
        return
    var sicher := DisplayServer.get_display_safe_area()
    if sicher.size.x <= 0 or sicher.size.y <= 0:
        return
    var skala := _flaeche.size / Vector2(fenster)
    var deckel := _flaeche.size * 0.12
    _rand_oben = clampf(float(sicher.position.y) * skala.y, 0.0, deckel.y)
    _rand_unten = clampf(
        float(fenster.y - sicher.position.y - sicher.size.y) * skala.y,
        0.0, deckel.y)
    var links := float(sicher.position.x) * skala.x
    var rechts := float(fenster.x - sicher.position.x - sicher.size.x) * skala.x
    _rand_seite = clampf(maxf(links, rechts), 0.0, deckel.x)


func _zeichne() -> void:
    if lauf == null:
        return
    _miss_geraeterand()
    var breite := _flaeche.size.x
    var hoehe := _flaeche.size.y

    _zustand(breite)
    _welle(breite)
    # Die Stroemungszeile schiebt die Punkte nach unten. Ohne das lagen sie
    # zehn Punkte auseinander und in derselben Spalte - zwei Zeilen, die
    # sich beruehren, liest man als eine.
    _punkte(breite, 26.0 if lauf.stroemung else 0.0)
    _karte(hoehe)
    _knoepfe(breite, hoehe)
    _pause(breite)
    _warnung(breite, hoehe)
    _lehre(breite, hoehe)
    _atem(breite, hoehe)
    _abschnitt(breite, hoehe)


## Links oben: Huelle und Ladung des Stosslichts.
func _zustand(_breite: float) -> void:
    var kasten := Rect2(RAND + _rand_seite, RAND + _rand_oben, 186.0, 62.0)
    _tafel(kasten)
    _text(kasten.position + Vector2(14.0, 22.0), "HULL", 11, LEISE)
    if lauf.huelle_voll > SEGMENTE_HOECHSTENS:
        _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 22.0),
            "%d / %d" % [int(lauf.huelle), int(lauf.huelle_voll)], 11,
            LEISE, false, true)
    _balken(Rect2(kasten.position + Vector2(14.0, 28.0),
        Vector2(158.0, 7.0)), lauf.huelle, lauf.huelle_voll,
        HELL if lauf.huelle > 3 else WARNUNG)
    _text(kasten.position + Vector2(14.0, 50.0), "BURST", 11, LEISE)
    var ladung: float = lauf.stoss_ladung()
    var leiste := Rect2(kasten.position + Vector2(56.0, 44.0),
        Vector2(116.0, 5.0))
    _flaeche.draw_rect(leiste, Color(WARM.r, WARM.g, WARM.b, 0.14))
    _flaeche.draw_rect(Rect2(leiste.position,
        Vector2(leiste.size.x * ladung, leiste.size.y)),
        WARM if ladung >= 1.0 else Color(WARM.r, WARM.g, WARM.b, 0.55))


## Rechts oben: Welle, Auftrag, Zeit.
func _welle(breite: float) -> void:
    var kasten := Rect2(breite - RAND - _rand_seite - 150.0,
        RAND + _rand_oben, 150.0, 62.0)
    _tafel(kasten)
    _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 26.0),
        "WAVE %d" % int(lauf.welle_nummer), 20, SCHRIFT, false, true)
    _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 44.0),
        "%d LEFT" % int(lauf.offen()), 11, LEISE, false, true)
    # Die Stroemung steht unter der Welle und nicht neben ihr: sie gehoert
    # zu dieser Welle und nicht zum Bild.
    if lauf.stroemung:
        _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 78.0),
            "DAY CURRENT x2", 11, WARM, false, true)


## Darunter: Punkte und der Kettenfaktor.
func _punkte(breite: float, versatz: float) -> void:
    var y := RAND + _rand_oben + 74.0 + versatz
    var rechts := breite - RAND - _rand_seite - 4.0
    _text(Vector2(rechts, y + 14.0), "SCORE", 11, LEISE, false, true)
    _text(Vector2(rechts, y + 44.0),
        Zahl.kurz(int(lauf.punkte)), 28, SCHRIFT, false, true)
    var kette: int = lauf.kette
    if kette >= Graben.KETTE_AB:
        # Der Faktor pulst, solange die Kette laeuft - er ist das Einzige im
        # Bild, das man verlieren kann, ohne getroffen zu werden.
        var puls := 0.5 + 0.5 * sin(_zeit * 6.0)
        _text(Vector2(rechts, y + 66.0),
            "x%.1f" % Graben.kette_faktor(kette), 17,
            Color(WARM.r, WARM.g, WARM.b, 0.7 + 0.3 * puls), false, true)


## Links unten: die Uebersichtskarte.
##
## **Vorher stand hier ein Balken mit einer Prozentzahl, und das war keine
## Karte.** Man sah einen Ausschnitt von 900 Einheiten in einem Feld von
## 1500 und wusste nie, wo man ist: nicht, in welcher Richtung noch Dunkel
## liegt, nicht, wo der Rand ist, nicht, wohin man zurueckmuss. Eine Zahl,
## die sagt "fuenfzehn Prozent", beantwortet keine einzige dieser Fragen.
##
## Was sie zeigt und was nicht:
##
##   * **Das aufgedeckte Feld** als helle Flaeche, der Rest bleibt leer. Das
##     ist dieselbe `Karte`, aus der auch der Nebel kommt - zwei
##     Beschreibungen desselben Wissens waeren zwei, die auseinanderlaufen.
##   * **Das Boot mit Blickrichtung.** Ohne die Richtung ist ein Punkt auf
##     einer runden Karte nur die halbe Auskunft.
##   * **Fundstellen, die man schon gesehen hat.** Wer eine liegen laesst,
##     findet sie wieder - das ist der Unterschied zwischen einer Karte und
##     einer Anzeige.
##   * **Raeuber in Reichweite**, und nur die. Eine Karte, auf der jedes
##     Tier der Welle steht, nimmt dem Dunkel seinen Sinn: man faehrt dann
##     nach der Karte statt nach dem, was man sieht.
const KARTE_GROSS := 128.0

## Wie weit ein Raeuber sein darf, um auf die Karte zu kommen. Etwas mehr als
## die Sicht - gerade so viel, dass man merkt, was gleich ins Bild kommt.
const KARTE_TIERE := 1150.0


func _karte(hoehe: float) -> void:
    var karte: Karte = lauf.karte
    var r := KARTE_GROSS * 0.5
    var mitte := Vector2(RAND + _rand_seite + r,
        hoehe - RAND - _rand_unten - r - 28.0)
    var welt := Rundum.FELD_RADIUS
    var faktor := r / welt

    # Der Rand des Feldes: die Karte ist rund, weil das Feld rund ist.
    _flaeche.draw_circle(mitte, r, Color(0.010, 0.030, 0.042, 0.62))

    if karte != null:
        _karte_aufgedeckt(karte, mitte, faktor)

    _flaeche.draw_arc(mitte, r, 0.0, TAU, 48,
        Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.40), 1.2, true)

    for f in lauf.gesehene_funde():
        var p: Vector2 = Vector2(f[&"ort"]) * faktor + mitte
        if bool(f[&"geholt"]):
            _flaeche.draw_arc(p, 2.6, 0.0, TAU, 8,
                Color(WARM.r, WARM.g, WARM.b, 0.30), 1.0, true)
        else:
            _flaeche.draw_circle(p, 2.6, WARM)

    for ort in lauf.nahe_tiere(KARTE_TIERE):
        _flaeche.draw_circle(Vector2(ort) * faktor + mitte, 1.6,
            Color(WARNUNG.r, WARNUNG.g, WARNUNG.b, 0.85))

    # Das Boot zuletzt, damit nichts darauf liegt.
    var b: Vector2 = Vector2(lauf.boot_ort()) * faktor + mitte
    var blick: Vector2 = Vector2(lauf.boot_blick()).normalized()
    var quer := blick.orthogonal()
    _flaeche.draw_colored_polygon(PackedVector2Array([
        b + blick * 5.5, b - blick * 3.0 + quer * 3.4,
        b - blick * 3.0 - quer * 3.4]), HELL)

    var anteil: float = karte.anteil() if karte != null else 0.0
    _text(Vector2(mitte.x, mitte.y + r + 14.0),
        "%d%% SCANNED  ·  %d SITES" % [int(round(anteil * 100.0)),
        int(lauf.funde)], 10, LEISE, true)


## Das aufgedeckte Feld, zeilenweise zusammengefasst.
##
## **Nicht Feld fuer Feld.** Das Raster hat gut zwoelfhundert Felder, und
## zwoelfhundert Rechtecke je Bild fuer eine Anzeige von 128 Punkten Breite
## waeren teurer als der ganze Meeresgrund. Zusammenhaengende Felder einer
## Zeile werden deshalb zu einem Rechteck - der aufgedeckte Teil ist ein
## Fleck, also bleiben ein paar Dutzend uebrig.
func _karte_aufgedeckt(karte: Karte, mitte: Vector2, faktor: float) -> void:
    var farbe := Color(HELL.r, HELL.g, HELL.b, 0.16)
    var kante := Karte.ZELLE * faktor
    for zy in karte.seite:
        var lauf_von := -1
        for zx in range(karte.seite + 1):
            var offen := zx < karte.seite \
                and karte.zelle_bekannt(Vector2i(zx, zy))
            if offen and lauf_von < 0:
                lauf_von = zx
            elif not offen and lauf_von >= 0:
                var a := karte.mitte_von(Vector2i(lauf_von, zy))
                var breit := float(zx - lauf_von) * kante
                _flaeche.draw_rect(Rect2(
                    Vector2(a.x, a.y) * faktor + mitte
                        - Vector2.ONE * (kante * 0.5),
                    Vector2(breit, kante)), farbe)
                lauf_von = -1


## Oben in der Mitte: die Pause. Klein, weit weg vom Daumen, und ohne Ton -
## ein Knopf, den man versehentlich trifft, waere schlimmer als keiner.
func _pause(breite: float) -> void:
    var kasten := Rect2(breite * 0.5 - 21.0, RAND + _rand_oben, 42.0, 34.0)
    pausenknopf = kasten.grow(8.0)
    _tafel(kasten, RAHMEN, 0.30, 8.0)
    for i in 2:
        var x := kasten.position.x + 15.0 + float(i) * 8.0
        _flaeche.draw_rect(Rect2(x, kasten.position.y + 10.0, 3.0, 14.0),
            Color(LEISE.r, LEISE.g, LEISE.b, 0.85))


## Rechts unten: das Stosslicht.## Rechts unten: das Stosslicht. Ein runder Knopf mit einem Ladering, wie im
## Schlund - der Daumen liegt dort ohnehin.
func _knoepfe(breite: float, hoehe: float) -> void:
    var mitte := Vector2(breite - RAND - _rand_seite - 44.0,
        hoehe - RAND - _rand_unten - 44.0)
    stossknopf = Rect2(mitte - Vector2(44.0, 44.0), Vector2(88.0, 88.0))
    var bereit: bool = lauf.stoss_bereit()
    var ladung: float = lauf.stoss_ladung()

    _flaeche.draw_circle(mitte, 40.0, Color(0.020, 0.052, 0.066, 0.66))
    _flaeche.draw_arc(mitte, 40.0, 0.0, TAU, 40,
        Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.34), 1.3, true)
    _flaeche.draw_arc(mitte, 34.0, -PI * 0.5, -PI * 0.5 + TAU * ladung, 36,
        WARM if bereit else Color(WARM.r, WARM.g, WARM.b, 0.45), 2.6, true)
    # Drei Ringe als Sinnbild: ein Stoss, der nach aussen laeuft.
    for i in 3:
        var r := 8.0 + float(i) * 7.0
        _flaeche.draw_arc(mitte, r, 0.0, TAU, 24,
            Color(HELL.r, HELL.g, HELL.b, (0.55 - 0.13 * float(i))
                * (1.0 if bereit else 0.35)), 1.4, true)


## Zwischen zwei Wellen: eine Zeile in der oberen Bildhaelfte, die aufblendet
## und wieder verschwindet.
##
## **Nicht in der Mitte und nicht als Tafel.** Dort steht das Boot, und die
## Pause ist kurz - eine Tafel, die man wegtippen muesste, waere laenger im
## Bild als der Anlass.
func _atem(breite: float, hoehe: float) -> void:
    var rest: float = lauf.atem
    if rest <= 0.0:
        return
    # Voll in der Mitte der Pause, an beiden Enden aus: eine Zeile, die
    # hart einsetzt, liest sich wie ein Fehler.
    var t: float = 1.0 - absf(rest / lauf.ATEM - 0.5) * 2.0
    var a := clampf(t * 2.2, 0.0, 1.0)
    var y := hoehe * 0.32
    _text(Vector2(breite * 0.5, y),
        "WAVE %d CLEARED" % (int(lauf.welle_nummer) - 1), 22,
        Color(HELL.r, HELL.g, HELL.b, a), true)
    _text(Vector2(breite * 0.5, y + 22.0),
        "%d OF %d THIS DIVE" % [int(lauf.welle_in_sitzung),
        Graben.WELLEN_JE_SITZUNG], 12,
        Color(LEISE.r, LEISE.g, LEISE.b, a * 0.9), true)


## Der Name eines neuen Abschnitts, wenn einer beginnt.
##
## Er steht dort, wo sonst die Wellenmeldung steht, und blendet genauso aus -
## zwei Meldungen an zwei Orten waeren zwei Dinge, auf die man achten muss.
## Sie koennen sich nicht ueberschneiden: der Abschnitt beginnt mit einer
## Welle, die Wellenmeldung steht davor.
func _abschnitt(breite: float, hoehe: float) -> void:
    var rest: float = lauf.abschnitt_zeit
    if rest <= 0.0 or lauf.abschnitt_nummer < 0:
        return
    var a: int = lauf.abschnitt_nummer
    var t: float = 1.0 - absf(rest / lauf.ABSCHNITT_ZEIT - 0.5) * 2.0
    var deckung := clampf(t * 3.0, 0.0, 1.0)
    var y := hoehe * 0.30
    _text(Vector2(breite * 0.5, y), Regeln.name_von(a).to_upper(), 22,
        Color(WARM.r, WARM.g, WARM.b, deckung), true)
    _text(Vector2(breite * 0.5, y + 24.0), Regeln.hinweis(a), 12,
        Color(LEISE.r, LEISE.g, LEISE.b, deckung * 0.9), true)


## Der Einstieg: zwei Zeilen ueber der unteren Kante.
##
## **Unten, nicht in der Mitte.** In der Mitte steht das Boot, und ein
## Hinweis, der genau das verdeckt, worauf er zeigt, ist keiner. Und ohne
## Tafel dahinter: er soll wie eine Beschriftung wirken und nicht wie ein
## Fenster, das man wegtippen muss.
func _lehre(breite: float, hoehe: float) -> void:
    var schritt: int = lauf.lehr_schritt
    if schritt >= lauf.LEHRE.size():
        return
    var eintrag: Dictionary = lauf.LEHRE[schritt]
    var puls := 0.6 + 0.4 * sin(_zeit * 2.6)
    # Ueber der Uebersichtskarte, nicht neben ihr: die Karte ist rund und
    # links, der Hinweis mittig - auf einem schmalen Schirm beruehren sie
    # sich sonst.
    var y := hoehe - RAND - _rand_unten - 186.0
    _text(Vector2(breite * 0.5, y), String(eintrag[&"text"]), 21,
        Color(HELL.r, HELL.g, HELL.b, 0.55 + 0.45 * puls), true)
    _text(Vector2(breite * 0.5, y + 22.0), String(eintrag[&"leise"]), 12,
        LEISE, true)


## Ein Band, wenn ein Leitwesen im Feld steht. Es ist der Hoehepunkt eines
## Abschnitts, und ein Hoehepunkt, den man erst am Schaden merkt, ist keiner.
func _warnung(breite: float, _hoehe: float) -> void:
    if not lauf.leitwesen_da():
        return
    var puls := 0.5 + 0.5 * sin(_zeit * 4.0)
    # Unter den Kopfzeilen, nicht in der Bildmitte: dort steht das Boot,
    # und ein Warnband quer darueber verdeckt genau das, was man
    # ansehen muss.
    var kasten := Rect2(breite * 0.5 - 130.0, RAND + _rand_oben + 92.0,
        260.0, 30.0)
    _tafel(kasten, WARNUNG, 0.25 + 0.35 * puls, 10.0)
    _text(Vector2(breite * 0.5, kasten.position.y + 20.0),
        "WARDEN IN THE FIELD", 14,
        Color(WARNUNG.r, WARNUNG.g, WARNUNG.b, 0.7 + 0.3 * puls), true)
