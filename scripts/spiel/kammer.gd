## Eine Kammer: Wände, Befallsknoten und die liegen gebliebenen Wurzelspuren.
##
## Hält den Zustand und zeichnet ihn. Die Abprallrechnung selbst steckt in
## [Ballistik] und bleibt frei von Szenenbezügen - nur so ist sie testbar.
class_name Kammer
extends Node2D

## Wie viele Schüsse eine Wurzelspur liegen bleibt.
##
## Der wichtigste Balancewert des ganzen Spiels. Zu lang, und Spieler bauen
## sich die Kammer zu, bis nichts mehr geht. Zu kurz, und der Kniff des Spiels
## verpufft - dann ist es ein Abprallspiel wie tausend andere.
const SPUR_LEBEN := 3

## Halbe Dicke einer Spur; zugleich ihr Trefferradius.
const SPUR_DICKE := 3.0

signal knoten_getroffen(ort: Vector2)
signal geraeumt

var bauplan: KammerDaten.Bauplan

## Feste Wände: Feldbegrenzung und Hindernisse.
var _fest: PackedVector2Array = []

## Liegen gebliebene Spuren, je Eintrag ein Streckenzug und sein Alter.
var _spuren: Array[Dictionary] = []

## Knotenorte; zerstörte werden entfernt.
var _knoten: PackedVector2Array = []

var _zeit := 0.0


func _process(delta: float) -> void:
    _zeit += delta
    queue_redraw()


## Baut die Kammer nach [param plan] auf.
func setze(plan: KammerDaten.Bauplan) -> void:
    bauplan = plan
    _fest = KammerDaten.waende(plan)
    _knoten = PackedVector2Array(plan.knoten)
    _spuren.clear()
    queue_redraw()


## Alle Wände, an denen abgeprallt wird - feste und gewachsene zusammen.
##
## Genau hier steckt der Kniff des Spiels: die eigene Spur des letzten Schusses
## ist beim nächsten eine ganz normale Wand.
func alle_waende() -> PackedVector2Array:
    var w := PackedVector2Array(_fest)
    for eintrag in _spuren:
        w.append_array(eintrag["waende"])
    return w


## Legt den Streckenzug eines Schusses als neue Spur ab und lässt die
## vorhandenen altern.
##
## Das Altern findet auch dann statt, wenn der Streckenzug selbst entartet ist:
## gezählt wird der Schuss, nicht die entstandene Spur. Sonst könnte ein
## wirkungsloser Schuss die Kammer beliebig lange einfrieren.
func lege_spur(punkte: PackedVector2Array) -> void:
    for eintrag in _spuren:
        eintrag["alter"] = int(eintrag["alter"]) + 1
    # Von hinten löschen, sonst verschieben sich die Indizes unter der Schleife.
    for i in range(_spuren.size() - 1, -1, -1):
        if int(_spuren[i]["alter"]) >= SPUR_LEBEN:
            _spuren.remove_at(i)

    var w := Ballistik.als_waende(punkte)
    if w.is_empty():
        return
    _spuren.append({"punkte": PackedVector2Array(punkte), "waende": w, "alter": 0})


func knoten_uebrig() -> int:
    return _knoten.size()


## Prüft, ob ein Knoten am Ort [param p] getroffen wird, und entfernt ihn.
##
## Knoten lenken die Spore **nicht** ab. Das ist Absicht: eine Ablenkung würde
## die Zielhilfe zur Lüge machen, sobald ein Knoten mitten im Flug verschwindet.
## So lassen sich stattdessen mehrere Knoten in einer Linie aufreihen.
func pruefe_treffer(p: Vector2, radius: float) -> bool:
    var reichweite := KammerDaten.KNOTEN_R + radius
    for i in _knoten.size():
        if _knoten[i].distance_to(p) <= reichweite:
            var ort := _knoten[i]
            var neu := PackedVector2Array()
            for k in _knoten.size():
                if k != i:
                    neu.append(_knoten[k])
            _knoten = neu
            knoten_getroffen.emit(ort)
            if _knoten.is_empty():
                geraeumt.emit()
            return true
    return false


## Prueft einen ganzen Streckenzug und gibt die Zahl der Treffer zurueck.
##
## Nutzt dieselbe Abtastung wie der Flug, damit der Loesbarkeitspruefer nicht
## zu anderen Ergebnissen kommt als das laufende Spiel.
func pruefe_bahn(punkte: PackedVector2Array, radius: float) -> int:
    var treffer := 0
    for p in Ballistik.abtasten(punkte, radius):
        if pruefe_treffer(p, radius):
            treffer += 1
    return treffer


# --- Zeichnen ---------------------------------------------------------------

func _draw() -> void:
    _zeichne_feld()
    _zeichne_spuren()
    _zeichne_hindernisse()
    _zeichne_knoten()


## Feldbegrenzung: dunkler Stein mit leuchtender Innenkante.
func _zeichne_feld() -> void:
    var f := KammerDaten.FELD
    draw_rect(f, Color(0.043, 0.059, 0.051))
    # Drei Lagen: breiter Saum aussen, kraeftige Kante, feine Innenlinie. So
    # bekommt die Wand Tiefe, ohne dass eine Textur noetig waere - und sie ist
    # auf einem Handydisplay eindeutig als Bande zu erkennen.
    draw_rect(f, Color(0.10, 0.20, 0.19), false, 14.0)
    draw_rect(f, Color(0.26, 0.46, 0.43), false, 4.0)
    draw_rect(f.grow(-9.0), Color(0.15, 0.28, 0.26), false, 1.6)

    # Sporenlicht in den Ecken - macht die Kammer bewohnt statt leer.
    for ecke in [f.position, Vector2(f.end.x, f.position.y), f.end,
            Vector2(f.position.x, f.end.y)]:
        var puls := 0.5 + 0.5 * sin(_zeit * 0.9 + ecke.x * 0.01)
        draw_circle(ecke, 26.0, Color(0.24, 0.56, 0.52, 0.05 + 0.04 * puls))


func _zeichne_hindernisse() -> void:
    var h := bauplan.hindernisse if bauplan != null else PackedVector2Array()
    for i in h.size() / 2:
        var a := h[i * 2]
        var b := h[i * 2 + 1]
        # Kern und Saum: der Saum lässt die Kante weich wirken, ohne Shader.
        # Drei Lagen wie bei der Aussenwand, damit ein Hindernis eindeutig als
        # Bande zu erkennen ist und nicht als Zierstrich.
        draw_line(a, b, Color(0.09, 0.18, 0.17), 20.0, true)
        draw_line(a, b, Color(0.20, 0.36, 0.34), 12.0, true)
        draw_line(a, b, Color(0.34, 0.58, 0.54), 4.0, true)
        draw_circle(a, 4.0, Color(0.34, 0.58, 0.54))
        draw_circle(b, 4.0, Color(0.34, 0.58, 0.54))


## Wurzelspuren. Ältere verblassen sichtbar, damit man ihr Ende kommen sieht.
func _zeichne_spuren() -> void:
    for eintrag in _spuren:
        var alter := int(eintrag["alter"])
        var frisch := 1.0 - float(alter) / float(SPUR_LEBEN)
        var punkte: PackedVector2Array = eintrag["punkte"]
        if punkte.size() < 2:
            continue

        var saum := Color(0.31, 0.84, 0.75, 0.10 * frisch)
        var kern := Color(0.45, 0.95, 0.86, 0.30 + 0.55 * frisch)
        draw_polyline(punkte, saum, SPUR_DICKE * 5.0, true)
        draw_polyline(punkte, kern, SPUR_DICKE * 2.0, true)

        # Knotenpunkte der Spur markieren die Abpraller.
        for i in range(1, punkte.size() - 1):
            draw_circle(punkte[i], SPUR_DICKE * 1.6,
                Color(0.62, 1.0, 0.92, 0.45 * frisch))


## Befallsknoten: violett, atmend, mit dunklem Kern.
func _zeichne_knoten() -> void:
    for i in _knoten.size():
        var p := _knoten[i]
        var puls := 0.5 + 0.5 * sin(_zeit * 2.1 + float(i) * 0.7)
        var r := KammerDaten.KNOTEN_R

        draw_circle(p, r * 2.1, Color(0.51, 0.31, 0.72, 0.07 + 0.05 * puls))
        draw_circle(p, r, Color(0.20, 0.13, 0.28))
        draw_arc(p, r, 0.0, TAU, 26, Color(0.66, 0.44, 0.92, 0.75 + 0.25 * puls),
            2.4, true)
        # Innenleben: drei kurze Bögen, die sich langsam drehen.
        for k in 3:
            var a0 := _zeit * 0.6 + TAU * float(k) / 3.0
            draw_arc(p, r * 0.52, a0, a0 + 1.1, 8,
                Color(0.78, 0.58, 1.0, 0.55 + 0.35 * puls), 2.0, true)
