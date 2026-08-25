## Der Sporenwerfer am unteren Rand.
##
## Zeigt die Zielrichtung, die Spannung und - über [Ballistik] - die Bahn der
## nächsten Abpraller. Die Vorschau ruft dieselbe Funktion wie der echte Flug
## auf; eine Zielhilfe, die etwas anderes zeigt als das, was dann passiert,
## macht ein Puzzlespiel unspielbar.
class_name Werfer
extends Node2D

## Wie viele Abpraller die Vorschau zeigt.
##
## Zwei ist bewusst wenig: Zeigte sie alles, wäre das Spiel ein Ablesen statt
## eines Vorausdenkens. Der Myzel-Ast "Wurf" hebt diesen Wert später an.
const VORSCHAU_ABPRALLER := 2

## Kürzeste und längste Zugstrecke.
const ZUG_MIN := 26.0
const ZUG_MAX := 190.0

var spannung := 0.0          ## 0 bis 1
var richtung := Vector2.UP
var zieht := false

## Die Bahn, die die Vorschau zeigt. Wird von aussen gesetzt.
var vorschau: PackedVector2Array = []

var _zeit := 0.0


func _process(delta: float) -> void:
    _zeit += delta
    queue_redraw()


## Rechnet eine Zugbewegung in Richtung und Spannung um.
##
## Gezogen wird **entgegen** der Schussrichtung, wie bei einer Schleuder - das
## ist die Geste, die Spieler ohne Erklärung verstehen.
func setze_zug(von: Vector2, nach: Vector2) -> void:
    var zug := von - nach
    var laenge := zug.length()
    if laenge < 0.001:
        return
    richtung = zug.normalized()
    spannung = clampf((laenge - ZUG_MIN) / (ZUG_MAX - ZUG_MIN), 0.0, 1.0)


func genug_gezogen() -> bool:
    return spannung > 0.02


func _draw() -> void:
    _zeichne_vorschau()
    _zeichne_werfer()


## Gepunktete Bahn. Die Punkte wandern nach vorn, damit die Richtung auch im
## Standbild eindeutig ist.
func _zeichne_vorschau() -> void:
    if vorschau.size() < 2 or not zieht:
        return

    var lauf := fmod(_zeit * 90.0, 22.0)
    for i in range(vorschau.size() - 1):
        var a := to_local(vorschau[i])
        var b := to_local(vorschau[i + 1])
        var strecke := a.distance_to(b)
        var dir := (b - a) / maxf(strecke, 0.001)
        # Spätere Abschnitte blasser: die Vorhersage wird mit jedem Abprall
        # unsicherer, und das soll man sehen.
        var kraft := 1.0 - float(i) * 0.28

        var t := lauf
        while t < strecke:
            var p := a + dir * t
            draw_circle(p, 3.4, Color(0.58, 0.98, 0.90, 0.85 * kraft))
            t += 22.0
        if i > 0:
            draw_circle(a, 6.0, Color(0.68, 1.0, 0.94, 0.70 * kraft))


## Der Werfer: eine organische Knolle mit einem Schlund, der in Zielrichtung
## zeigt und sich mit der Spannung weitet.
##
## Der erste Entwurf zeichnete zwei geschwungene Arme - gedreht sah das aus wie
## ein Ei, und die Zielrichtung war nicht ablesbar. Eine klare Achse in
## Schussrichtung liest sich sofort.
func _zeichne_werfer() -> void:
    var winkel := richtung.angle()
    draw_set_transform(Vector2.ZERO, winkel, Vector2.ONE)

    var laenge := 34.0 + spannung * 22.0
    var glut := Color(0.50, 1.0, 0.90)

    # Wurzelanker nach hinten - verankert die Knolle sichtbar im Boden.
    for i in 5:
        var a := PI * (0.35 + 0.325 * float(i) / 4.0)
        var richtung_a := Vector2(cos(a), sin(a))
        draw_line(richtung_a * 14.0, richtung_a * 30.0,
            Color(0.20, 0.38, 0.35), 3.0, true)

    # Schlund: ein sich oeffnender Trichter in Schussrichtung.
    var trichter := PackedVector2Array([
        Vector2(6.0, -11.0),
        Vector2(laenge, -13.0 - spannung * 7.0),
        Vector2(laenge + 4.0, 0.0),
        Vector2(laenge, 13.0 + spannung * 7.0),
        Vector2(6.0, 11.0),
    ])
    draw_colored_polygon(trichter, Color(0.07, 0.14, 0.13))
    var u := PackedVector2Array(trichter)
    u.append(trichter[0])
    draw_polyline(u, Color(0.32, 0.66, 0.60), 2.6, true)

    # Knolle.
    draw_circle(Vector2.ZERO, 19.0, Color(0.09, 0.17, 0.16))
    draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 26, Color(0.28, 0.54, 0.50), 2.4, true)

    # Geladene Spore, wandert mit der Spannung nach hinten in den Schlund.
    var sitz := Vector2(lerpf(16.0, 4.0, spannung), 0.0)
    draw_circle(sitz, 11.0 + 5.0 * spannung,
        Color(glut.r, glut.g, glut.b, 0.16 + 0.26 * spannung))
    draw_circle(sitz, 5.5, glut)

    # Spannungsbogen um die Knolle - sagt ohne Zahl, wie weit gezogen ist.
    if spannung > 0.02:
        draw_arc(Vector2.ZERO, 25.0, -PI * 0.6 * spannung, PI * 0.6 * spannung,
            20, Color(glut.r, glut.g, glut.b, 0.85), 3.0, true)

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
