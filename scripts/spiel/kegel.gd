extends Node2D

## Der Lichtkegel.
##
## **Zusicherung:** was hier hell gezeichnet wird, ist genau das, was Schaden
## macht. Beide Seiten fragen `Schlund.beleuchtung()`. Ein Kegel, der weiter
## reicht als er wirkt - oder umgekehrt - macht die Kernschleife unlernbar.
##
## Gezeichnet als Faecher aus Dreiecken mit Farbe je Eckpunkt: jeder Punkt
## bekommt genau die Helligkeit, die die Rechnung ihm gibt. Ein Shader waere
## huebscher, aber dann gaebe es zwei Beschreibungen desselben Kegels, und die
## zweite waere die falsche.

const RIPPEN := 26          ## Aufloesung quer
const RINGE := 9            ## Aufloesung in der Tiefe

## Kaltes Blaugruen mit weissem Kern. Ein grauer Kegel sah im ersten Bild aus
## wie Nebel; Licht braucht Saettigung, nicht nur Helligkeit.
const FARBE := Color(0.24, 0.86, 1.0)
const KERN := Color(0.82, 1.0, 0.96)
## **Der Keil ist leiser geworden, die Funken lauter.**
##
## Der Kegel war eine geschlossene helle Flaeche mit ein paar Punkten darin -
## im Bild ein Scheinwerfer. Was ihn zu Licht *im Wasser* macht, ist nicht die
## Flaeche, sondern das, was darin schwebt und funkelt: der Strahl selbst ist
## unsichtbar, man sieht nur, was er trifft. Also der Keil zurueck und dafuer
## dreimal so viel Staub, in mehr Groessen.
const STAERKE := 0.33

## --- Staub im Strahl ---
##
## Ein Lichtkegel im Wasser ist nur deshalb sichtbar, weil etwas darin
## schwebt. Ohne das ist er eine gefaerbte Flaeche; mit ihm ist er ein
## Volumen, durch das man hindurchsieht.
##
## Die Koerner stehen fest im Grabenraum und sinken langsam - sie gehoeren dem
## Wasser, nicht dem Kegel. Wer den Kegel schwenkt, sieht deshalb andere
## Koerner aufleuchten, und genau daran liest man die Bewegung ab.
##
## **Fein, nicht dick.** Der erste Anlauf gab jedem Korn einen Hof vom
## Vierfachen seines Radius und liess den Radius bis auf neun Pixel wachsen -
## ein Hof von neununddreissig Pixeln, und das viermalhundertsechzigfach. Im
## Bild war das kein Staub mehr, sondern ein Feld aus Ringen, jeder so gross
## wie ein Raeuber. Wer den Bildschirm ansah, zaehlte fuenfzig Kreise und
## suchte darin die zwoelf Tiere. Das ist genau die Unuebersichtlichkeit, die
## das Spiel unspielbar macht - und sie kam nicht von der Welle, sondern vom
## Schmuck.
##
## Ein Schwebstoffkorn ist ein **Punkt**. Es darf funkeln, es darf einen
## Hauch von Hof haben, aber es darf nie so gross werden, dass man es fuer
## ein Lebewesen haelt. Deshalb: der Kern bleibt unter zwei Pixeln, der Hof
## unter sieben, und die Anzahl darf hoch bleiben - viele winzige Punkte sind
## Wasser, wenige grosse sind Unrat.
const STAUB := 420
const STAUB_SINKEN := 16.0
const STAUB_HELL := 0.85

## Groesster Kernradius eines Korns in Pixeln. Alles hier haengt daran.
const KORN_GROESSTE := 1.7
const KORN_HOF := 3.6


var richtung := Vector2.UP
var halbwinkel := Graben.HALBWINKEL
var reichweite := Graben.REICHWEITE
var flackern := 0.0

## Von `wache.gd` je Bild aus `Regeln` gesetzt. Der Kegel sieht damit genau
## so aus, wie er wirkt - auch wenn ein Abschnitt seine Form veraendert oder
## das Leuchtorgan aussetzt.
var rand_kern := Schlund.RAND_KERN
var tiefe_kern := Schlund.TIEFE_KERN
var schein := 1.0

## Wie viele Staubkoerner gezeichnet werden. `wache.gd` senkt es, wenn viele
## Tiere im Bild sind - der Staub ist Beiwerk, die Raeuber sind es nicht.
var staub_anteil := 1.0

var _staub := PackedVector2Array()
var _staub_groesse := PackedFloat32Array()
var _staub_takt := PackedFloat32Array()


func _ready() -> void:
    # Additiv: Licht addiert sich zum Wasser, es deckt es nicht ab.
    var stoff := CanvasItemMaterial.new()
    stoff.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = stoff
    _streue_staub()


## Feste Saat: derselbe Staub in jeder Sitzung. Ein Wasser, dessen Schwebstoff
## bei jedem Start woanders haengt, wirkt nicht wie ein Ort.
func _streue_staub() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x4e454b21
    _staub.resize(STAUB)
    _staub_groesse.resize(STAUB)
    _staub_takt.resize(STAUB)
    for i in STAUB:
        _staub[i] = Vector2(
            rng.randf_range(Graben.FELD.position.x, Graben.FELD.end.x),
            rng.randf_range(Graben.FELD.position.y - 200.0, Graben.FELD.end.y))
        # Groessenspanne statt Einheitskorn: die wenigen grossen sind es,
        # die im Strahl aufblitzen, und die vielen kleinen sind das Wasser
        # dazwischen. Bei einer Spanne von 0.7 bis 2.3 sah alles gleich aus.
        _staub_groesse[i] = pow(rng.randf(), 2.2) * KORN_GROESSTE + 0.28
        _staub_takt[i] = rng.randf_range(0.3, 1.4)


func _process(delta: float) -> void:
    # Ein leises Atmen, damit der Kegel lebt. Rein optisch - die Rechnung
    # bekommt es nie zu sehen.
    flackern = fmod(flackern + delta * 2.3, TAU)
    queue_redraw()


func _draw() -> void:
    var spitze := Graben.WAECHTER
    var puls := 1.0 + 0.035 * sin(flackern)

    for ring in RINGE:
        var innen := reichweite * float(ring) / float(RINGE)
        var aussen := reichweite * float(ring + 1) / float(RINGE)

        for rippe in RIPPEN:
            var w0 := lerpf(-halbwinkel, halbwinkel, float(rippe) / float(RIPPEN))
            var w1 := lerpf(-halbwinkel, halbwinkel, float(rippe + 1) / float(RIPPEN))

            var punkte := PackedVector2Array([
                spitze + richtung.rotated(w0) * innen,
                spitze + richtung.rotated(w1) * innen,
                spitze + richtung.rotated(w1) * aussen,
                spitze + richtung.rotated(w0) * aussen,
            ])
            var farben := PackedColorArray()
            for p in punkte:
                farben.append(_farbe_an(spitze, p, puls))
            draw_polygon(punkte, farben)

    # Ein heller Streifen entlang der Achse. Im echten Strahl ist die Mitte
    # dichter als der Rand, weil man dort durch mehr beleuchtetes Wasser
    # sieht - ohne ihn wirkt der Kegel wie eine gleichmaessig gefaerbte
    # Flaeche und nicht wie ein Buendel.
    # Der Kern des Strahls, als weiche Bahnen quer zur Achse.
    #
    # Ein einzelner Streifen hatte eine sichtbare Kante mitten im Kegel: an
    # seinem Rand sprang die Deckung von voll auf null. Deshalb sechs Bahnen,
    # deren Deckung nach aussen auf null laeuft - benachbarte Bahnen teilen
    # sich denselben Wert an ihrer gemeinsamen Kante, und damit verschwindet
    # die Naht.
    const KERNBAHNEN := 6
    var kernweite := halbwinkel * 0.66
    for bahn in KERNBAHNEN:
        var a0 := lerpf(-kernweite, kernweite, float(bahn) / float(KERNBAHNEN))
        var a1 := lerpf(-kernweite, kernweite, float(bahn + 1) / float(KERNBAHNEN))
        var d0 := 1.0 - absf(a0) / kernweite
        var d1 := 1.0 - absf(a1) / kernweite
        for ring in RINGE:
            var innen := reichweite * float(ring) / float(RINGE)
            var aussen := reichweite * float(ring + 1) / float(RINGE)
            var ecken := PackedVector2Array([
                spitze + richtung.rotated(a0) * innen,
                spitze + richtung.rotated(a1) * innen,
                spitze + richtung.rotated(a1) * aussen,
                spitze + richtung.rotated(a0) * aussen,
            ])
            var anteile := PackedFloat32Array([d0, d1, d1, d0])
            var farben := PackedColorArray()
            for k in ecken.size():
                var c := _farbe_an(spitze, ecken[k], puls)
                farben.append(Color(KERN.r, KERN.g, KERN.b,
                    c.a * 0.34 * anteile[k] * anteile[k]))
            draw_polygon(ecken, farben)

    _zeichne_staub(spitze, puls)

    # Der Austritt am Waechter selbst - ein harter, heller Kern.
    draw_circle(spitze, 13.0, Color(KERN.r, KERN.g, KERN.b, 0.55 * puls * schein))
    draw_circle(spitze, 26.0, Color(FARBE.r, FARBE.g, FARBE.b, 0.16 * puls * schein))


## Die Koerner im Strahl. Gezeichnet wird nur, was der Kegel wirklich trifft -
## dieselbe `Schlund.beleuchtung()`, die auch den Schaden bestimmt. Ein
## Staubkorn, das ausserhalb des Kegels leuchtet, waere eine Luege ueber die
## Reichweite.
func _zeichne_staub(spitze: Vector2, puls: float) -> void:
    var zahl := int(float(STAUB) * clampf(staub_anteil, 0.0, 1.0))
    if zahl <= 0:
        return
    var hoehe := Graben.FELD.size.y + 200.0
    var sink := fmod(flackern * STAUB_SINKEN * 0.44, hoehe)

    for i in zahl:
        var p := _staub[i]
        # Sinken mit Umbruch am oberen Rand - so bleibt der Vorrat endlich.
        p.y = Graben.FELD.position.y - 200.0 \
            + fmod(p.y - Graben.FELD.position.y + 200.0 + sink, hoehe)

        var hell := Schlund.beleuchtung(spitze, richtung, halbwinkel, reichweite,
            p, rand_kern, tiefe_kern) * schein
        if hell <= 0.06:
            continue
        var funkeln := 0.55 + 0.45 * sin(flackern * _staub_takt[i] * 3.1 + float(i))
        # Die Helligkeit geht in die **Deckung**, nicht mehr in den Radius.
        # Vorher wuchs ein Korn im Kernstrahl auf das Zweieinhalbfache - und
        # weil der Kern des Kegels genau dort steht, wo der Spieler hinsieht,
        # wurden ausgerechnet die Koerner am groessten, die am meisten stoeren.
        var r := _staub_groesse[i] * puls
        var deckung := hell * hell * STAUB_HELL * funkeln
        # Zwei Kreise: ein knapper Hof und ein harter Kern. Der dritte war der
        # weite Hof - er hat aus jedem Punkt eine Scheibe gemacht.
        draw_circle(p, r * KORN_HOF, Color(FARBE.r, FARBE.g, FARBE.b, deckung * 0.11))
        draw_circle(p, r, Color(KERN.r, KERN.g, KERN.b, deckung))


func _farbe_an(spitze: Vector2, punkt: Vector2, puls: float) -> Color:
    var hell := Schlund.beleuchtung(spitze, richtung, halbwinkel, reichweite,
        punkt, rand_kern, tiefe_kern) * schein
    if hell <= 0.0:
        return Color(FARBE.r, FARBE.g, FARBE.b, 0.0)
    var mische := FARBE.lerp(KERN, hell * hell)
    return Color(mische.r, mische.g, mische.b,
        hell * STAERKE * puls * _schlieren(spitze, punkt))


## Wanderndes Streiflicht im Strahl.
##
## **Nur optisch, und das ist hier die ganze Kunst.** `Schlund.beleuchtung()`
## bestimmt den Schaden, und was hell gezeichnet wird, muss Schaden machen -
## also darf hier nichts hinein, was diese Zahl veraendert. Der Faktor
## schwankt deshalb eng um 1.0 und mittelt sich ueber die Kegelflaeche
## heraus: es ist Wasser vor dem Licht, nicht mehr Licht.
##
## Was man sieht, sind zwei Schwebungen unterschiedlicher Laenge, die nach
## aussen wandern - so, wie Licht durch bewegtes Wasser faellt. Eine allein
## sieht aus wie eine Zielscheibe.
## **Die Vielfachen von `flackern` sind ganzzahlig, und das ist kein Zufall.**
## `flackern` laeuft mit `fmod(..., TAU)` um. Bei einem krummen Faktor - 1.9
## etwa - springt das Argument bei jedem Umlauf um 1.9*TAU, also nicht um ein
## Vielfaches der Periode: alle 2.7 Sekunden liefe ein Riss durch den Kegel.
## Bei 2.0 und 1.0 ist der Umlauf nahtlos.
const SCHLIEREN_TIEFE := 0.075
const SCHLIEREN_TIEFE_FEIN := 0.035


func _schlieren(spitze: Vector2, punkt: Vector2) -> float:
    var weit := spitze.distance_to(punkt)
    return 1.0 \
        + SCHLIEREN_TIEFE * sin(weit * 0.026 - flackern * 1.0) \
        + SCHLIEREN_TIEFE_FEIN * sin(weit * 0.068 - flackern * 1.0 + 2.1)
