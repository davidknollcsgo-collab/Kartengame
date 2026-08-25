## Geometrie-Helfer fuer die prozedurale Darstellung.
##
## Alles im Spiel wird zur Laufzeit gezeichnet statt aus Bilddateien geladen -
## das haelt das Projekt klein und die Rechtelage eindeutig.
class_name Formen
extends RefCounted


## Rechteck mit abgeschraegten Ecken. Die Schraege gibt den Baugruppen ihre
## technische Anmutung, ohne dass eine Textur noetig waere.
static func kante(r: Rect2, schraege: float) -> PackedVector2Array:
    var c := minf(schraege, minf(r.size.x, r.size.y) * 0.5)
    return PackedVector2Array([
        Vector2(r.position.x + c, r.position.y),
        Vector2(r.end.x - c, r.position.y),
        Vector2(r.end.x, r.position.y + c),
        Vector2(r.end.x, r.end.y - c),
        Vector2(r.end.x - c, r.end.y),
        Vector2(r.position.x + c, r.end.y),
        Vector2(r.position.x, r.end.y - c),
        Vector2(r.position.x, r.position.y + c),
    ])


## Geschlossener Linienzug fuer [method kante], zum Nachziehen der Kontur.
static func kante_umriss(r: Rect2, schraege: float) -> PackedVector2Array:
    var p := kante(r, schraege)
    var u := PackedVector2Array(p)
    u.append(p[0])
    return u
