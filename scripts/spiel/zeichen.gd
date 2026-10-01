class_name Zeichen
extends RefCounted

## **Die Bilder in den Menues.**
##
## Bis Oktober 2026 waren alle Schirme reiner Text: eine Waffe war ihr Name,
## ein Bau seine Zahl. Man liest einen Namen, aber man *erkennt* ein Bild -
## und in einem Aufstieg, den man alle zwanzig Sekunden mitten im Gedraenge
## trifft, ist Erkennen schneller als Lesen.
##
## Alles hier ist mit `Tusche` gezeichnet wie die Figuren - Kante, Licht,
## dieselben Striche -, damit HUD und Lauf eine Hand haben. Jedes Zeichen
## steht mittig auf `ort` und fuellt ein Quadrat der halben Seite `g`.
##
## Farben: Stahl, Holz und Leder fuer Dinge, **Gold nur fuer Sold** (Muenze),
## Zinnober nur fuers eigene Leben (Herz).

const STAHL := Color(0.80, 0.81, 0.80)
const EISEN := Color(0.52, 0.54, 0.57)
const HOLZ := Color(0.50, 0.37, 0.23)
const LEDER := Color(0.45, 0.32, 0.21)
const STEIN := Color(0.64, 0.62, 0.57)
const KNOCHEN := Color(0.93, 0.90, 0.82)
const K := Palette.UMRISS


static func _p(ort: Vector2, g: float, x: float, y: float) -> Vector2:
    return ort + Vector2(x, y) * g


## Ein Block gleicher Breite: flache Enden, keine Linse.
static func _block(tu: Tusche, a: Vector2, b: Vector2, breite: float,
        farbe: Color) -> void:
    tu.strang(PackedVector2Array([a, b]), PackedFloat32Array([breite, breite]),
        farbe, 2, K)


# --- Waffen ----------------------------------------------------------------

static func waffe(tu: Tusche, art: int, ort: Vector2, g: float) -> void:
    match art:
        Waffen.Art.SCHWERT:
            tu.zug(_p(ort, g, -0.30, 0.30), _p(ort, g, 0.78, -0.78), g * 0.26,
                STAHL, 0.2, 0.0, 0.0, 6, K)
            _block(tu, _p(ort, g, -0.62, 0.02), _p(ort, g, -0.02, 0.62), g * 0.14, EISEN)
            _block(tu, _p(ort, g, -0.34, 0.34), _p(ort, g, -0.66, 0.66), g * 0.14, HOLZ)
            tu.klecks(_p(ort, g, -0.74, 0.74), g * 0.12, EISEN, 1, K)
        Waffen.Art.SPEER:
            _block(tu, _p(ort, g, -0.85, 0.85), _p(ort, g, 0.40, -0.40), g * 0.12, HOLZ)
            tu.zug(_p(ort, g, 0.30, -0.30), _p(ort, g, 0.88, -0.88), g * 0.34,
                STAHL, 0.35, 0.0, 0.0, 5, K)
        Waffen.Art.FLEGEL:
            _block(tu, _p(ort, g, -0.85, 0.85), _p(ort, g, -0.35, 0.35), g * 0.16, HOLZ)
            for i in 3:
                var t := float(i + 1) / 4.0
                tu.klecks(_p(ort, g, lerpf(-0.30, 0.25, t), lerpf(0.25, -0.15, t)),
                    g * 0.07, EISEN, i, K)
            var kopf := _p(ort, g, 0.42, -0.32)
            for i in 7:
                var w := TAU * float(i) / 7.0
                tu.zug(kopf, kopf + Vector2(cos(w), sin(w)) * g * 0.48, g * 0.10,
                    EISEN, 0.1, 0.0, 0.0, 3, K)
            tu.klecks(kopf, g * 0.30, EISEN, 3, K)
        Waffen.Art.ARMBRUST:
            _block(tu, _p(ort, g, 0.0, 0.88), _p(ort, g, 0.0, -0.50), g * 0.18, HOLZ)
            tu.zug(_p(ort, g, -0.80, -0.18), _p(ort, g, 0.0, 0.05), g * 0.04, K, 0.5, 0.0, 0.0, 2)
            tu.zug(_p(ort, g, 0.80, -0.18), _p(ort, g, 0.0, 0.05), g * 0.04, K, 0.5, 0.0, 0.0, 2)
            tu.strang(PackedVector2Array([_p(ort, g, -0.82, -0.16),
                _p(ort, g, 0.0, -0.78), _p(ort, g, 0.82, -0.16)]),
                PackedFloat32Array([g * 0.08, g * 0.18, g * 0.08]), EISEN, 8, K)
            tu.zug(_p(ort, g, 0.0, 0.05), _p(ort, g, 0.0, -0.92), g * 0.08,
                STAHL, 0.6, 0.0, 0.0, 3, K)
        Waffen.Art.HAMMER:
            var a := _p(ort, g, -0.70, 0.80)
            var b := _p(ort, g, 0.30, -0.36)
            _block(tu, a, b, g * 0.15, HOLZ)
            var quer := (b - a).normalized().orthogonal()
            _block(tu, b - quer * g * 0.48, b + quer * g * 0.48, g * 0.42, EISEN)
        Waffen.Art.AXT:
            _block(tu, _p(ort, g, -0.62, 0.82), _p(ort, g, 0.30, -0.62), g * 0.13, HOLZ)
            tu.strang(PackedVector2Array([_p(ort, g, 0.02, -0.82),
                _p(ort, g, 0.72, -0.52), _p(ort, g, 0.40, 0.05)]),
                PackedFloat32Array([g * 0.12, g * 0.62, g * 0.12]), STAHL, 8, K)


# --- Zuege -----------------------------------------------------------------

static func zug(tu: Tusche, z: int, ort: Vector2, g: float) -> void:
    match z:
        Gunst.Zug.RUESTUNG:
            _hemd(tu, ort, g, EISEN, false)
        Gunst.Zug.STIEFEL:
            _block(tu, _p(ort, g, -0.18, -0.78), _p(ort, g, -0.18, 0.40), g * 0.56, LEDER)
            tu.strang(PackedVector2Array([_p(ort, g, -0.46, 0.56),
                _p(ort, g, 0.20, 0.52), _p(ort, g, 0.78, 0.60)]),
                PackedFloat32Array([g * 0.40, g * 0.40, g * 0.26]), LEDER, 6, K)
            _block(tu, _p(ort, g, -0.52, -0.70), _p(ort, g, 0.16, -0.70), g * 0.20,
                LEDER.darkened(0.3))
            # Fluegel am Schaft: Tempo, nicht Wanderschaft.
            for i in 3:
                var y := -0.45 + float(i) * 0.17
                tu.zug(_p(ort, g, -0.50, y), _p(ort, g, -0.92, y - 0.12), g * 0.08,
                    KNOCHEN, 0.2, 0.3, 0.0, 3)
        Gunst.Zug.WETZSTEIN:
            _block(tu, _p(ort, g, -0.72, 0.42), _p(ort, g, 0.62, -0.02), g * 0.44, STEIN)
            for i in 3:
                var w := -1.9 + float(i) * 0.55
                var a := _p(ort, g, 0.52, -0.32)
                tu.zug(a, a + Vector2(cos(w), sin(w)) * g * 0.42, g * 0.07,
                    KNOCHEN, 0.1, 0.4, 0.0, 3)
            tu.zug(_p(ort, g, -0.60, 0.20), _p(ort, g, 0.50, -0.18), g * 0.05,
                Color(1, 1, 1, 0.55), 0.5, 0.0, 0.0, 3)
        Gunst.Zug.LATERNE:
            tu.klecks(_p(ort, g, 0.0, 0.05), g * 0.86,
                Color(KNOCHEN.r, KNOCHEN.g, KNOCHEN.b, 0.45), 2)
            tu.zug(_p(ort, g, -0.22, -0.70), _p(ort, g, 0.22, -0.70), g * 0.10,
                EISEN, 0.5, 0.0, -g * 0.25, 4, K)
            _block(tu, _p(ort, g, 0.0, -0.52), _p(ort, g, 0.0, 0.60), g * 0.66, EISEN)
            tu.klecks(_p(ort, g, 0.0, 0.05), g * 0.22, Color(1.0, 0.97, 0.86), 3)
            _block(tu, _p(ort, g, -0.40, -0.52), _p(ort, g, 0.40, -0.52), g * 0.14,
                EISEN.darkened(0.3))
            _block(tu, _p(ort, g, -0.40, 0.62), _p(ort, g, 0.40, 0.62), g * 0.14,
                EISEN.darkened(0.3))
        Gunst.Zug.ZEHRUNG:
            var brot := Color(0.78, 0.58, 0.34)
            tu.strang(PackedVector2Array([_p(ort, g, -0.80, 0.18),
                _p(ort, g, 0.0, -0.20), _p(ort, g, 0.80, 0.18)]),
                PackedFloat32Array([g * 0.56, g * 0.80, g * 0.56]), brot, 8, K)
            for i in 3:
                var x := -0.38 + float(i) * 0.38
                tu.zug(_p(ort, g, x - 0.10, -0.18), _p(ort, g, x + 0.12, 0.10),
                    g * 0.07, brot.darkened(0.4), 0.5, 0.0, 0.0, 3)
        Gunst.Zug.GEFAEHRTE:
            Streiter.gefaehrte(tu, _p(ort, g, 0.0, 0.90), g * 1.85, 1.0, 0.0, 0.0,
                Palette.HELD, Palette.HELD_GLANZ)


## Ein Hemd: Rumpf mit Aermeln. `platten` legt Querbaender darueber.
static func _hemd(tu: Tusche, ort: Vector2, g: float, farbe: Color,
        platten: bool) -> void:
    _block(tu, _p(ort, g, -0.40, -0.50), _p(ort, g, -0.82, 0.10), g * 0.32, farbe)
    _block(tu, _p(ort, g, 0.40, -0.50), _p(ort, g, 0.82, 0.10), g * 0.32, farbe)
    tu.strang(PackedVector2Array([_p(ort, g, 0.0, -0.62), _p(ort, g, 0.0, 0.05),
        _p(ort, g, 0.0, 0.78)]),
        PackedFloat32Array([g * 1.00, g * 0.86, g * 1.00]), farbe, 6, K)
    tu.klecks(_p(ort, g, 0.0, -0.60), g * 0.16, K, 1)
    var hell := farbe.lightened(0.35)
    for i in 3:
        var y := -0.20 + float(i) * 0.30
        if platten:
            tu.zug(_p(ort, g, -0.40, y), _p(ort, g, 0.40, y), g * 0.06,
                farbe.darkened(0.5), 0.5, 0.0, 0.0, 3)
        else:
            for j in 4:
                tu.klecks(_p(ort, g, -0.30 + float(j) * 0.20, y), g * 0.05, hell, j)


# --- Bauten ----------------------------------------------------------------

static func bau(tu: Tusche, b: int, ort: Vector2, g: float) -> void:
    match b:
        Halle.Bau.MAUER:
            _block(tu, _p(ort, g, -0.86, 0.36), _p(ort, g, 0.86, 0.36), g * 0.90, STEIN)
            for i in 3:
                var x := -0.62 + float(i) * 0.62
                _block(tu, _p(ort, g, x, -0.12), _p(ort, g, x, -0.66), g * 0.36, STEIN)
            for y in [0.10, 0.48]:
                tu.zug(_p(ort, g, -0.80, y), _p(ort, g, 0.80, y), g * 0.04,
                    STEIN.darkened(0.45), 0.5, 0.0, 0.0, 3)
            for x in [-0.30, 0.30]:
                tu.zug(_p(ort, g, x, -0.06), _p(ort, g, x, 0.10), g * 0.04,
                    STEIN.darkened(0.45), 0.5, 0.0, 0.0, 2)
            tu.zug(_p(ort, g, 0.0, 0.10), _p(ort, g, 0.0, 0.48), g * 0.04,
                STEIN.darkened(0.45), 0.5, 0.0, 0.0, 2)
        Halle.Bau.SCHMIEDE:
            _block(tu, _p(ort, g, -0.76, -0.02), _p(ort, g, 0.50, -0.02), g * 0.32, EISEN)
            tu.zug(_p(ort, g, 0.48, -0.06), _p(ort, g, 0.92, -0.12), g * 0.22,
                EISEN, 0.0, 0.0, 0.0, 3, K)
            _block(tu, _p(ort, g, -0.10, 0.14), _p(ort, g, -0.10, 0.52), g * 0.34,
                EISEN.darkened(0.2))
            _block(tu, _p(ort, g, -0.55, 0.66), _p(ort, g, 0.35, 0.66), g * 0.24,
                EISEN.darkened(0.2))
            for i in 3:
                var w := -2.4 + float(i) * 0.5
                var a := _p(ort, g, -0.10, -0.28)
                tu.zug(a, a + Vector2(cos(w), sin(w)) * g * 0.50, g * 0.08,
                    KNOCHEN, 0.1, 0.4, 0.0, 3)
        Halle.Bau.STALL:
            # Ein Hufeisen ist ein Kreis, der unten offen ist - kein Bogen.
            var bahn := PackedVector2Array()
            var halb := PackedFloat32Array()
            for i in 15:
                var w := lerpf(PI * 0.72, PI * 2.28, float(i) / 14.0)
                bahn.append(ort + Vector2(cos(w), sin(w)) * g * 0.62)
                halb.append(g * 0.16)
            tu.band(bahn, halb, EISEN, PackedFloat32Array(), K)
            for i in 6:
                var w := lerpf(PI * 0.92, PI * 2.08, float(i) / 5.0)
                tu.klecks(ort + Vector2(cos(w), sin(w)) * g * 0.62, g * 0.05, K, i)
        Halle.Bau.MUENZE:
            for i in 3:
                var y := 0.66 - float(i) * 0.22
                _block(tu, _p(ort, g, -0.62, y), _p(ort, g, 0.40, y), g * 0.22,
                    Palette.SOLD.darkened(0.15 * float(2 - i)))
            muenze(tu, _p(ort, g, 0.24, -0.28), g * 0.62)


# --- Ausruestung -----------------------------------------------------------

static func stueck(tu: Tusche, st: int, ort: Vector2, g: float) -> void:
    match st:
        Ausruestung.Stueck.KESSELHAUBE:
            tu.strang(PackedVector2Array([_p(ort, g, 0.0, -0.62),
                _p(ort, g, 0.0, -0.10), _p(ort, g, 0.0, 0.22)]),
                PackedFloat32Array([g * 0.56, g * 1.06, g * 1.10]), EISEN, 8, K)
            _block(tu, _p(ort, g, -0.92, 0.26), _p(ort, g, 0.92, 0.26), g * 0.20,
                EISEN.darkened(0.25))
        Ausruestung.Stueck.VISIERHELM:
            tu.strang(PackedVector2Array([_p(ort, g, 0.0, -0.78),
                _p(ort, g, 0.0, 0.0), _p(ort, g, 0.0, 0.76)]),
                PackedFloat32Array([g * 0.92, g * 1.20, g * 1.02]), EISEN, 8, K)
            _block(tu, _p(ort, g, -0.44, -0.08), _p(ort, g, 0.44, -0.08), g * 0.12, K)
            for i in 3:
                tu.klecks(_p(ort, g, -0.20 + float(i) * 0.20, 0.32), g * 0.05, K, i)
        Ausruestung.Stueck.KETTENHEMD:
            _hemd(tu, ort, g, EISEN, false)
        Ausruestung.Stueck.PLATTENROCK:
            _hemd(tu, ort, g, STAHL.darkened(0.12), true)
        Ausruestung.Stueck.SIEGELRING:
            tu.kranz(_p(ort, g, 0.0, 0.18), g * 0.42, g * 0.62, K, 3)
            tu.kranz(_p(ort, g, 0.0, 0.18), g * 0.46, g * 0.58, STAHL, 3)
            tu.klecks(_p(ort, g, 0.0, -0.46), g * 0.28, Color(0.24, 0.44, 0.36), 2, K)
        Ausruestung.Stueck.BLUTSTEIN:
            tu.klecks(ort, g * 0.66, Color(0.22, 0.33, 0.28), 4, K)
            for i in 4:
                var w := 0.8 + float(i) * 1.6
                tu.klecks(ort + Vector2(cos(w), sin(w)) * g * 0.30, g * 0.09,
                    Color(0.50, 0.14, 0.17), i)
            tu.klecks(_p(ort, g, -0.25, -0.30), g * 0.10, Color(1, 1, 1, 0.5), 5)
        Ausruestung.Stueck.REISEMANTEL:
            var stoff := Color(0.44, 0.46, 0.37)
            tu.strang(PackedVector2Array([_p(ort, g, 0.0, -0.72),
                _p(ort, g, -0.06, 0.08), _p(ort, g, 0.0, 0.84)]),
                PackedFloat32Array([g * 0.56, g * 1.10, g * 1.52]), stoff, 8, K)
            tu.zug(_p(ort, g, 0.0, -0.60), _p(ort, g, 0.0, 0.70), g * 0.05,
                stoff.darkened(0.4), 0.5, 0.0, 0.0, 3)
            tu.klecks(_p(ort, g, 0.0, -0.58), g * 0.12, STAHL, 2, K)
        Ausruestung.Stueck.BANNERTUCH:
            _block(tu, _p(ort, g, -0.62, 0.92), _p(ort, g, -0.62, -0.92), g * 0.10, HOLZ)
            var tuch := Color(0.86, 0.83, 0.74)
            tu.strang(PackedVector2Array([_p(ort, g, -0.58, -0.48),
                _p(ort, g, 0.10, -0.40), _p(ort, g, 0.78, -0.50)]),
                PackedFloat32Array([g * 0.80, g * 0.72, g * 0.60]), tuch, 8, K)
            tu.zug(_p(ort, g, -0.50, -0.46), _p(ort, g, 0.70, -0.48), g * 0.14,
                Palette.UMRISS.lerp(tuch, 0.3), 0.5, 0.0, 0.0, 4)


# --- Im Lauf ---------------------------------------------------------------

## Das eigene Leben: das einzige Herz im Spiel, in Zinnober wie sein Balken.
static func herz(tu: Tusche, ort: Vector2, g: float) -> void:
    var c := Palette.GEFAHR
    tu.strang(PackedVector2Array([_p(ort, g, 0.0, -0.20), _p(ort, g, 0.0, 0.24),
        _p(ort, g, 0.0, 0.80)]),
        PackedFloat32Array([g * 1.40, g * 0.90, g * 0.06]), c, 6, K)
    tu.klecks(_p(ort, g, -0.34, -0.30), g * 0.40, c, 1)
    tu.klecks(_p(ort, g, 0.34, -0.30), g * 0.40, c, 2)
    tu.klecks(_p(ort, g, -0.36, -0.38), g * 0.13, Color(1, 1, 1, 0.55), 3)


## Sold. Die einzige Stelle neben der Muenze am Boden, an der Gold steht.
static func muenze(tu: Tusche, ort: Vector2, g: float) -> void:
    tu.klecks(ort, g * 0.72, Palette.SOLD, 1, K)
    tu.kranz(ort, g * 0.44, g * 0.54, Palette.SOLD.darkened(0.35), 2)
    tu.klecks(_p(ort, g, -0.24, -0.26), g * 0.14, Color(1, 1, 1, 0.6), 3)


## Die Erschlagenen.
static func schaedel(tu: Tusche, ort: Vector2, g: float) -> void:
    tu.klecks(_p(ort, g, 0.0, -0.16), g * 0.60, KNOCHEN, 1, K)
    _block(tu, _p(ort, g, -0.30, 0.50), _p(ort, g, 0.30, 0.50), g * 0.36, KNOCHEN)
    tu.klecks(_p(ort, g, -0.24, -0.10), g * 0.19, K, 2)
    tu.klecks(_p(ort, g, 0.24, -0.10), g * 0.19, K, 3)
    tu.zug(_p(ort, g, 0.0, 0.14), _p(ort, g, 0.0, 0.28), g * 0.10, K, 0.5, 0.0, 0.0, 2)
    for i in 3:
        var x := -0.18 + float(i) * 0.18
        tu.zug(_p(ort, g, x, 0.36), _p(ort, g, x, 0.60), g * 0.04, K, 0.5, 0.0, 0.0, 2)


# --- Rahmen der Menues -----------------------------------------------------

## **Das Wappen**: ein Wimpel mit Schwalbenschwanz in der Farbe des Helden,
## an einer Stange, mit einem hellen Sparren. Es steht im Kopf jedes Schirms
## und links am Lebensbalken - die Fahne, unter der man kaempft.
static func wappen(tu: Tusche, ort: Vector2, g: float, farbe: Color,
        glanz: Color) -> void:
    _block(tu, _p(ort, g, -0.62, -0.95), _p(ort, g, -0.62, 0.95), g * 0.12, HOLZ)
    tu.klecks(_p(ort, g, -0.62, -0.98), g * 0.11, EISEN, 1, K)
    # Das Tuch: ein breites Band, das unten in zwei Spitzen auslaeuft.
    tu.strang(PackedVector2Array([_p(ort, g, -0.05, -0.80), _p(ort, g, -0.05, 0.10),
        _p(ort, g, -0.05, 0.62)]),
        PackedFloat32Array([g * 1.0, g * 1.0, g * 0.95]), farbe, 6, K)
    for s in [-1.0, 1.0]:
        tu.zug(_p(ort, g, -0.05 + s * 0.26, 0.55), _p(ort, g, -0.05 + s * 0.30, 0.92),
            g * 0.42, farbe, 0.0, 0.0, 0.0, 3, K)
    tu.zug(_p(ort, g, -0.40, -0.05), _p(ort, g, -0.05, 0.30), g * 0.16, glanz,
        0.5, 0.0, 0.0, 3)
    tu.zug(_p(ort, g, 0.30, -0.05), _p(ort, g, -0.05, 0.30), g * 0.16, glanz,
        0.5, 0.0, 0.0, 3)
    tu.klecks(_p(ort, g, -0.05, -0.38), g * 0.14, glanz, 2)


static func laut(tu: Tusche, ort: Vector2, g: float, an: bool) -> void:
    _block(tu, _p(ort, g, -0.70, 0.0), _p(ort, g, -0.30, 0.0), g * 0.50, K)
    tu.strang(PackedVector2Array([_p(ort, g, -0.35, 0.0), _p(ort, g, 0.10, 0.0)]),
        PackedFloat32Array([g * 0.50, g * 1.20]), K, 2)
    if an:
        for i in 2:
            var r := 0.38 + float(i) * 0.30
            tu.zug(ort + Vector2(0.25 * g + r * g * 0.4, -r * g),
                ort + Vector2(0.25 * g + r * g * 0.4, r * g), g * 0.10, K,
                0.5, 0.0, r * g * 0.45, 4)
    else:
        tu.zug(_p(ort, g, 0.30, -0.35), _p(ort, g, 0.80, 0.35), g * 0.12, K, 0.5, 0.0, 0.0, 2)
        tu.zug(_p(ort, g, 0.30, 0.35), _p(ort, g, 0.80, -0.35), g * 0.12, K, 0.5, 0.0, 0.0, 2)


static func ruettel(tu: Tusche, ort: Vector2, g: float, an: bool) -> void:
    _block(tu, _p(ort, g, 0.0, -0.75), _p(ort, g, 0.0, 0.75), g * 0.75, K)
    _block(tu, _p(ort, g, 0.0, -0.55), _p(ort, g, 0.0, 0.48), g * 0.50, STAHL)
    if an:
        for s in [-1.0, 1.0]:
            tu.zug(_p(ort, g, s * 0.65, -0.40), _p(ort, g, s * 0.65, 0.40), g * 0.10,
                K, 0.5, 0.0, s * g * 0.15, 3)


static func zurueck(tu: Tusche, ort: Vector2, g: float) -> void:
    _block(tu, _p(ort, g, -0.40, 0.0), _p(ort, g, 0.75, 0.0), g * 0.24, K)
    tu.zug(_p(ort, g, -0.75, 0.0), _p(ort, g, -0.15, -0.55), g * 0.24, K, 0.5, 0.0, 0.0, 2)
    tu.zug(_p(ort, g, -0.75, 0.0), _p(ort, g, -0.15, 0.55), g * 0.24, K, 0.5, 0.0, 0.0, 2)


static func nochmal(tu: Tusche, ort: Vector2, g: float) -> void:
    var bahn := PackedVector2Array()
    var halb := PackedFloat32Array()
    for i in 13:
        var w := lerpf(-PI * 0.35, PI * 1.45, float(i) / 12.0)
        bahn.append(ort + Vector2(cos(w), sin(w)) * g * 0.60)
        halb.append(g * 0.12)
    tu.band(bahn, halb, K, PackedFloat32Array())
    var spitze := ort + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * g * 0.60
    tu.zug(spitze + Vector2(-g * 0.45, -g * 0.05), spitze, g * 0.22, K, 0.5, 0.0, 0.0, 2)
    tu.zug(spitze + Vector2(g * 0.05, g * 0.45), spitze, g * 0.22, K, 0.5, 0.0, 0.0, 2)


static func schliessen(tu: Tusche, ort: Vector2, g: float, farbe: Color) -> void:
    tu.zug(_p(ort, g, -0.6, -0.6), _p(ort, g, 0.6, 0.6), g * 0.22, farbe, 0.5, 0.0, 0.0, 2)
    tu.zug(_p(ort, g, -0.6, 0.6), _p(ort, g, 0.6, -0.6), g * 0.22, farbe, 0.5, 0.0, 0.0, 2)


## **Die Burg im Banner des Aufstiegs**: Mauer mit Zinnen, zwei Tuerme,
## ein Bergfried, Fahnen in der Farbe des Helden, auf einem gruenen Huegel.
## `ort` ist der Fuss der Mauer in der Mitte, `g` die halbe Breite.
static func burg_bild(tu: Tusche, ort: Vector2, g: float, fahne: Color) -> void:
    var wiese := Palette.WIESE
    tu.strang(PackedVector2Array([ort + Vector2(-g * 1.1, g * 0.10),
        ort + Vector2(0.0, -g * 0.04), ort + Vector2(g * 1.1, g * 0.10)]),
        PackedFloat32Array([g * 0.20, g * 0.30, g * 0.20]), wiese, 8, K)
    var stein := STEIN
    # Mauer mit Zinnen.
    _block(tu, ort + Vector2(-g * 0.70, -g * 0.18), ort + Vector2(g * 0.70, -g * 0.18),
        g * 0.34, stein)
    for i in 7:
        var x := -0.60 + float(i) * 0.20
        _block(tu, ort + Vector2(x * g, -g * 0.36), ort + Vector2(x * g, -g * 0.44),
            g * 0.10, stein)
    # Tor.
    tu.strang(PackedVector2Array([ort + Vector2(0.0, -g * 0.01), ort + Vector2(0.0, -g * 0.22)]),
        PackedFloat32Array([g * 0.20, g * 0.16]), K, 2)
    # Zwei Tuerme und der Bergfried.
    for e in [[-0.70, 0.62, 0.22], [0.70, 0.62, 0.22], [0.0, 0.95, 0.30]]:
        var x: float = e[0]
        var hoch: float = e[1]
        var breit: float = e[2]
        var fuss := ort + Vector2(x * g, -g * 0.02)
        var kopf := ort + Vector2(x * g, -g * hoch)
        _block(tu, fuss, kopf, g * breit, stein.lightened(0.05 if x == 0.0 else 0.0))
        for k in 3:
            var zx := (float(k) - 1.0) * breit * 0.36
            _block(tu, kopf + Vector2(zx * g, 0.0), kopf + Vector2(zx * g, -g * 0.08),
                g * breit * 0.22, stein)
        tu.zug(kopf + Vector2(0.0, -g * 0.10), kopf + Vector2(0.0, -g * 0.32),
            g * 0.03, K, 0.5, 0.0, 0.0, 2)
        tu.strang(PackedVector2Array([kopf + Vector2(0.0, -g * 0.31),
            kopf + Vector2(g * 0.20, -g * 0.27)]),
            PackedFloat32Array([g * 0.12, g * 0.07]), fahne, 2, K)
        # Fensterschlitz.
        _block(tu, kopf + Vector2(0.0, g * 0.16), kopf + Vector2(0.0, g * 0.26),
            g * 0.05, K)
