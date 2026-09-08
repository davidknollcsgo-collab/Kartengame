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


## Der **Geisterbalken**: wo die Huelle eben noch stand.
##
## **Ein Treffer war eine Zahl, die sich aendert.** Wer im Augenblick des
## Treffers auf sein Ziel sah - und das tut man immer -, merkte davon
## nichts; er sah spaeter eine kleinere Zahl und wusste nicht, wann sie
## kleiner geworden war. Die Huelle ist der einzige Grund, warum eine Fahrt
## endet, und sie war die leiseste Anzeige im Bild.
##
## Der volle Teil des Balkens faellt sofort, ein blasser Rest bleibt kurz
## stehen und laeuft ihm dann nach. Das kostet keinen Platz, keinen Ton und
## keine Unterbrechung - und es ist auch dann noch zu sehen, wenn man
## eineinhalb Sekunden spaeter hinsieht.
var _geist := -1.0
var _geist_halt := 0.0
var _huelle_zuletzt := -1

## Wie lange der Rest stehen bleibt, bevor er nachlaeuft, und wie lange er
## dann braucht.
##
## **Die Dauer haengt an der Luecke, nicht an der vollen Huelle.** Der erste
## Anlauf liess ihn mit 0,85 vollen Huellen je Sekunde fallen - bei einem
## Punkt von neunzehn sind das sechs Hundertstel, und damit war der Rest
## unsichtbar, also nutzlos. Ein Treffer kostet meistens genau einen Punkt;
## wenn ausgerechnet der nicht zu sehen ist, zeigt die Anzeige nur die
## seltenen Faelle.
const GEIST_HALT := 0.22
const GEIST_DAUER := 0.40


func _process(delta: float) -> void:
    _zeit += delta
    _geist_nach(delta)
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


## **Grund und Rand als Verlauf, nicht als Flaeche mit Rahmen.**
##
## Das Sechseck bleibt - es ist die Handschrift dieses Bedienbildes und
## unterscheidet es vom runden Graben dahinter. Was sich aendert, ist alles
## darin: der Grund war eine Farbe, der Rand eine Linie mit ueberall
## derselben Deckung. Ein Koerper unter Licht ist oben heller als unten, und
## seine Unterkante leuchtet nicht.
##
## Dieselbe Regel wie im Ausbau (`kolonie_schirm.gd::_tafelgrund`) und
## draussen im Graben. Sie ist hier nur ueber ein Sechseck gelegt statt ueber
## eine gerundete Karte.
func _tafel(kasten: Rect2, farbe := RAHMEN, deckung := 0.42,
        schraege := 12.0) -> void:
    var weg := _hexweg(kasten, schraege)
    var grund := PackedColorArray()
    var rand := PackedColorArray()
    for punkt in weg:
        var t := clampf((punkt.y - kasten.position.y)
            / maxf(1.0, kasten.size.y), 0.0, 1.0)
        var st := lerpf(1.85, 0.50, t * t)
        grund.append(Color(0.020 * st, 0.052 * st, 0.066 * st, 0.78))
        rand.append(Color(farbe.r, farbe.g, farbe.b,
            deckung * lerpf(1.0, 0.22, t * t)))
    _flaeche.draw_polygon(weg, grund)
    rand.append(rand[0])
    _flaeche.draw_polyline_colors(weg + PackedVector2Array([weg[0]]),
        rand, 1.3, true)


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
## **Zwoelf, nicht zweiundzwanzig.** Bei neunzehn Segmenten auf 158 Punkten
## ist jedes sechs Punkte breit mit zwei Punkten Luft - im Bild eine
## Schraffur, die man zaehlen muesste. Ein glatter Balken mit der Zahl
## daneben sagt dasselbe in einem Blick. Segmente lohnen nur dort, wo jeder
## einzelne Treffer sichtbar wegfaellt.
const SEGMENTE_HOECHSTENS := 12


func _geist_nach(delta: float) -> void:
    if lauf == null or lauf.huelle_voll <= 0:
        _geist = -1.0
        _huelle_zuletzt = -1
        return
    var ist := float(lauf.huelle)
    if _geist < 0.0 or ist > _geist:
        # Aufgefuellt oder neue Fahrt: kein Nachlauf, sondern gleichstehen.
        _geist = ist
        _geist_halt = 0.0
        _huelle_zuletzt = lauf.huelle
        return
    # Ein frischer Treffer haelt den Rest an, wo er steht. Der Halt wird bei
    # jedem weiteren Treffer neu gesetzt: wer dreimal hintereinander
    # getroffen wird, soll einen Rest sehen und nicht drei.
    if _huelle_zuletzt >= 0 and lauf.huelle < _huelle_zuletzt:
        _geist_halt = GEIST_HALT
    _huelle_zuletzt = lauf.huelle
    if _geist_halt > 0.0:
        _geist_halt = maxf(0.0, _geist_halt - delta)
        return
    _geist = maxf(ist, _geist
        - maxf(1.0, _geist - ist) * delta / GEIST_DAUER)


## Ein Balken mit runden Enden.
##
## **Er war das einzige Rechteck im Bild.** Alles andere in dieser Welt hat
## keine geraden Kanten; zwei Balken mit vier scharfen Ecken lasen sich als
## Formular. Zwei Halbkreise an den Enden kosten nichts und nehmen ihm das.
func _riegel(kasten: Rect2, farbe: Color) -> void:
    if kasten.size.x <= 0.0 or kasten.size.y <= 0.0:
        return
    var r := kasten.size.y * 0.5
    _flaeche.draw_rect(kasten, farbe)
    _flaeche.draw_circle(kasten.position + Vector2(0.0, r), r, farbe)
    _flaeche.draw_circle(Vector2(kasten.end.x, kasten.position.y + r),
        r, farbe)


func _balken(kasten: Rect2, ist: int, voll: int, farbe: Color,
        geist := -1.0) -> void:
    if voll <= 0:
        return
    if voll > SEGMENTE_HOECHSTENS:
        _riegel(kasten, Color(farbe.r, farbe.g, farbe.b, 0.14))
        # Der Rest zuerst, damit der volle Teil darauf liegt.
        if geist > float(ist):
            _riegel(Rect2(kasten.position, Vector2(kasten.size.x
                * clampf(geist / float(voll), 0.0, 1.0), kasten.size.y)),
                Color(WARNUNG.r, WARNUNG.g, WARNUNG.b, 0.62))
        _riegel(Rect2(kasten.position, Vector2(kasten.size.x
            * clampf(float(ist) / float(voll), 0.0, 1.0), kasten.size.y)),
            farbe)
        return
    var breit := kasten.size.x / float(voll)
    for i in voll:
        var teil := Rect2(kasten.position + Vector2(breit * float(i), 0.0),
            Vector2(breit - 2.0, kasten.size.y))
        if i < ist:
            _riegel(teil, farbe)
        elif float(i) < geist:
            _riegel(teil, Color(WARNUNG.r, WARNUNG.g, WARNUNG.b, 0.62))
        else:
            _riegel(teil, Color(farbe.r, farbe.g, farbe.b, 0.14))


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
    _karte(hoehe)
    _knoepfe(breite, hoehe)
    _pause(breite)
    _warnung(breite, hoehe)
    _lehre(breite, hoehe)
    _atem(breite, hoehe)
    _abschnitt(breite, hoehe)
    _treffer(breite, hoehe)


## Links oben: Huelle und Ladung des Stosslichts.
func _zustand(_breite: float) -> void:
    var kasten := Rect2(RAND + _rand_seite, RAND + _rand_oben, 186.0, 62.0)
    _tafel(kasten)
    _text(kasten.position + Vector2(14.0, 22.0), "HULL", 11, LEISE)
    # **Die Zahl steht immer da.** Sie stand nur oberhalb der Segmentgrenze,
    # und darunter musste man Striche zaehlen, um zu wissen, wieviel man noch
    # hat. Ein Balken sagt "ungefaehr so viel"; in dem Augenblick, in dem es
    # darauf ankommt, will man es genau wissen.
    _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 22.0),
        "%d / %d" % [int(lauf.huelle), int(lauf.huelle_voll)], 12,
        SCHRIFT if lauf.huelle > 3 else WARNUNG, false, true)
    _balken(Rect2(kasten.position + Vector2(14.0, 28.0),
        Vector2(158.0, 7.0)), lauf.huelle, lauf.huelle_voll,
        HELL if lauf.huelle > 3 else WARNUNG, _geist)
    _text(kasten.position + Vector2(14.0, 50.0), "BURST", 11, LEISE)
    var ladung: float = lauf.stoss_ladung()
    var leiste := Rect2(kasten.position + Vector2(56.0, 44.0),
        Vector2(116.0, 5.0))
    _riegel(leiste, Color(WARM.r, WARM.g, WARM.b, 0.14))
    _riegel(Rect2(leiste.position,
        Vector2(leiste.size.x * ladung, leiste.size.y)),
        WARM if ladung >= 1.0 else Color(WARM.r, WARM.g, WARM.b, 0.55))


## Rechts oben: Welle, Rest, Punkte - in **einer** Tafel.
##
## **Vorher waren es eine Tafel und zwei freistehende Zahlenbloecke.** Die
## Welle stand in einem Kasten, Punkte und Kettenfaktor schwebten darunter im
## Bild, und die Stroemungszeile schob beides gegeneinander. Drei Dinge, die
## alle "wie steht es gerade" beantworten, in drei verschiedenen Formen - das
## liest sich als drei Meldungen und nicht als ein Stand.
func _welle(breite: float) -> void:
    var kette: int = lauf.kette
    var mit_kette := kette >= Graben.KETTE_AB
    var hoch := 106.0
    if lauf.stroemung:
        hoch += 20.0
    if mit_kette:
        hoch += 20.0
    var kasten := Rect2(breite - RAND - _rand_seite - 156.0,
        RAND + _rand_oben, 156.0, hoch)
    _tafel(kasten)
    var rechts := kasten.end.x - 14.0
    _text(Vector2(rechts, kasten.position.y + 26.0),
        "WAVE %d" % int(lauf.welle_nummer), 20, SCHRIFT, false, true)
    _text(Vector2(rechts, kasten.position.y + 44.0),
        "%d LEFT" % int(lauf.offen()), 11, LEISE, false, true)

    var y := kasten.position.y + 56.0
    _flaeche.draw_line(Vector2(kasten.position.x + 14.0, y),
        Vector2(rechts, y), Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.26), 1.0)

    _text(Vector2(kasten.position.x + 14.0, y + 16.0), "SCORE", 11, LEISE)
    _text(Vector2(rechts, y + 40.0), Zahl.kurz(int(lauf.punkte)), 26,
        SCHRIFT, false, true)
    y += 44.0
    if mit_kette:
        # Der Faktor pulst, solange die Kette laeuft - er ist das Einzige im
        # Bild, das man verlieren kann, ohne getroffen zu werden.
        var puls := 0.5 + 0.5 * sin(_zeit * 6.0)
        _text(Vector2(rechts, y + 16.0),
            "CHAIN x%.1f" % Graben.kette_faktor(kette), 13,
            Color(WARM.r, WARM.g, WARM.b, 0.7 + 0.3 * puls), false, true)
        y += 20.0
    # Die Stroemung gehoert zu dieser Welle und nicht zum Bild, also steht
    # sie mit in der Tafel.
    if lauf.stroemung:
        _text(Vector2(rechts, y + 16.0), "DAY CURRENT x2", 11, WARM,
            false, true)


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

    # **Die Zeile braucht einen Grund.** Sie stand blank ueber der Welt, und
    # wenn dort gerade ein Tier im Strahl leuchtete, war sie nicht mehr zu
    # lesen - heller Text auf hellem Grund. Ein Sechseck darunter ist
    # dieselbe Form wie bei jeder anderen Angabe im Bedienbild, nur schmal.
    var anteil: float = karte.anteil() if karte != null else 0.0
    var zeile := "%d%% SCANNED  ·  %d SITES" % [
        int(round(anteil * 100.0)), int(lauf.funde)]
    var zeilenbreit := _schrift.get_string_size(zeile,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
    var unten := mitte.y + r + 9.0
    _tafel(Rect2(mitte.x - zeilenbreit * 0.5 - 10.0, unten - 12.0,
        zeilenbreit + 20.0, 20.0), RAHMEN, 0.22, 6.0)
    _text(Vector2(mitte.x, unten + 2.0), zeile, 10, LEISE, true)


## Das aufgedeckte Feld, zeilenweise zusammengefasst.
##
## **Nicht Feld fuer Feld.** Das Raster hat gut zwoelfhundert Felder, und
## zwoelfhundert Rechtecke je Bild fuer eine Anzeige von 128 Punkten Breite
## waeren teurer als der ganze Meeresgrund. Zusammenhaengende Felder einer
## Zeile werden deshalb zu einem Rechteck - der aufgedeckte Teil ist ein
## Fleck, also bleiben ein paar Dutzend uebrig.
## **Ein Saum um jeden Lauf geht hier nicht.** Der Versuch lag nahe - jeden
## Lauf zweimal zeichnen, einmal breit und blass darunter -, und im Bild kam
## eine Schraffur heraus: die Saeume zweier uebereinanderliegender Zeilen
## ueberdecken sich, und wo sich zwei Deckungen addieren, steht ein heller
## Streifen. Weich wird eine Flaeche aus Rechtecken nur, wenn die weiche
## Kante **einmal** um das Ganze laeuft und nicht um jedes Stueck - und dafuer
## muesste man den Rand des Flecks kennen, nicht seine Zeilen. Fuer eine
## Anzeige von 128 Punkten ist das den Aufwand nicht wert; die Treppe darin
## liest sich als Raster, die Schraffur las sich als Fehler.
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
                var ecke := Vector2(a.x, a.y) * faktor + mitte \
                    - Vector2.ONE * (kante * 0.5)
                _flaeche.draw_rect(Rect2(ecke, Vector2(breit, kante)), farbe)
                lauf_von = -1


## Woher der letzte Treffer kam: ein Saum am Bildrand auf dieser Seite.
##
## **Kein Vollbildschleier.** Ein gleichmaessiger roter Blitz sagt nur
## "getroffen" - das weiss man schon, es hat gewackelt und gebrummt. Was man
## nicht weiss, ist die Richtung, und die steht in einem Rundumspiel
## zwischen Weiterfahren und noch einem Treffer.
##
## Gezeichnet als Keil vom Rand nach innen, in der Bildrichtung des
## Angreifers - **die Kamera schaut nach Norden**, das Boot dreht sich, also
## ist die Weltrichtung hier zugleich die Bildrichtung.
func _treffer(breite: float, hoehe: float) -> void:
    var rest: float = lauf.treffer_zeit
    if rest <= 0.0:
        return
    var r: Vector2 = Vector2(lauf.treffer_richtung)
    if r.length_squared() < 0.001:
        return
    var f := clampf(rest / lauf.TREFFER_ZEIGT, 0.0, 1.0)
    var mitte := Vector2(breite, hoehe) * 0.5

    # **Ein Saum, der von der Kante hereinblutet, kein Keil zur Mitte.** Der
    # erste Anlauf zeichnete ein Dreieck von der Bildkante zum Mittelpunkt:
    # im Bild war das ein Speer quer ueber den halben Schirm, der genau das
    # verdeckte, was man nach einem Treffer ansehen muss.
    #
    # Jetzt ein Kreisausschnitt, dessen innerer Rand durchsichtig ist und
    # dessen aeusserer weit **ausserhalb** des Bildes liegt. Was uebrig
    # bleibt, ist ein Glimmen an der Kante in der Richtung des Angreifers -
    # und weil die Kamera nach Norden schaut, ist die Weltrichtung hier
    # zugleich die Bildrichtung.
    # **Der Saum haengt an der Bildkante, nicht an einem festen Radius.**
    # Ein Kreisring auf einem 9:20-Schirm ist an den langen Seiten weit
    # drinnen und an den kurzen weit draussen; im Bild war das ein rotes
    # Tortenstueck ueber einem Viertel des Schirms. Deshalb wird je Winkel
    # ausgerechnet, wo die Kante liegt, und der Saum davor gelegt.
    #
    # Zwei Lagen statt eines Verlaufs: breit und blass, schmal und hell -
    # dieselbe Machart wie bei den Leuchtroehren. Der Grund ist hier
    # allerdings ein technischer: **`draw_polygon()` mit Farbe je Ecke
    # zeichnet auf dieser Ebene nichts**, und ein Dreiecksnetz ueber
    # `canvas_item_add_triangle_array` ebenso wenig. Dieselbe Flaeche mit
    # *einer* Farbe erscheint sofort - nachgemessen mit einem
    # vollflaechigen Gruen.
    var halb := Vector2(breite, hoehe) * 0.5
    var stufen := 12
    # Vier Lagen statt zweier: jede naeher am Rand, schmaler und heller. Bei
    # zweien blieb eine harte gerade Kante mitten im Bild stehen - vier
    # ergeben eine Treppe, die bei diesen Deckungen als Verlauf durchgeht.
    var lagen := 4
    for lage in lagen:
        var t_lage := float(lage) / float(lagen - 1)
        var sp := lerpf(0.95, 0.40, t_lage)
        var tief := lerpf(0.34, 0.09, t_lage)
        var a := lerpf(0.07, 0.30, t_lage) * f * f
        var aussen := PackedVector2Array()
        var innen := PackedVector2Array()
        for i in stufen + 1:
            var w := lerpf(r.angle() - sp, r.angle() + sp,
                float(i) / float(stufen))
            var d := Vector2.RIGHT.rotated(w)
            var t := minf(halb.x / maxf(0.001, absf(d.x)),
                halb.y / maxf(0.001, absf(d.y)))
            aussen.append(mitte + d * t * 1.6)
            innen.append(mitte + d * t * (1.0 - tief))
        innen.reverse()
        _flaeche.draw_colored_polygon(aussen + innen,
            Color(WARNUNG.r, WARNUNG.g, WARNUNG.b, a))


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
    _meldung(breite, y, "WAVE %d CLEARED" % (int(lauf.welle_nummer) - 1),
        "%d OF %d THIS DIVE" % [int(lauf.welle_in_sitzung),
        Graben.WELLEN_JE_SITZUNG], HELL, a)


## Eine **Meldung**: zwei Zeilen auf einer Tafel, mittig.
##
## **Warum sie eine Tafel braucht.** Die Wellenmeldung und der Abschnittsname
## standen als blanker Text ueber der Welt, waehrend jede andere Angabe im
## Bedienbild auf einem Sechseck sitzt - zwei Sprachen auf einem Schirm. Und
## sie waren stellenweise nicht zu lesen: heller Text ueber einem hellen Tier
## ist heller Text auf hellem Grund. Dieselbe Falle wie bei der Zeile unter
## der Uebersichtskarte, und dieselbe Loesung.
##
## **Der Einstieg bekommt bewusst keine.** Er soll wie eine Beschriftung
## wirken und nicht wie ein Fenster, das man wegtippen muss - das steht bei
## `_lehre()` und gilt weiter.
##
## Die Tafel richtet sich nach der breiteren der beiden Zeilen. Eine feste
## Breite waere entweder fuer "STROM" zu gross oder fuer "TRENCH STORM" zu
## klein, und beides sieht man sofort.
func _meldung(breite: float, y: float, gross: String, klein: String,
        farbe: Color, deckung: float) -> void:
    if deckung <= 0.01:
        return
    var b_gross := _schrift.get_string_size(gross,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
    var b_klein := _schrift.get_string_size(klein,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
    var b := maxf(b_gross, b_klein) + 46.0
    _tafel(Rect2(breite * 0.5 - b * 0.5, y - 26.0, b,
        (54.0 if klein != "" else 34.0)),
        farbe, 0.30 * deckung, 12.0)
    _text(Vector2(breite * 0.5, y), gross, 22,
        Color(farbe.r, farbe.g, farbe.b, deckung), true)
    if klein != "":
        _text(Vector2(breite * 0.5, y + 22.0), klein, 12,
            Color(LEISE.r, LEISE.g, LEISE.b, deckung * 0.9), true)


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
    _meldung(breite, hoehe * 0.30, Regeln.name_von(a).to_upper(),
        Regeln.hinweis(a), WARM, deckung)


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
