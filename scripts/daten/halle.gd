class_name Halle
extends RefCounted

## **Die Burg zwischen zwei Läufen.**
##
## Vier Bauten, vier Zahlen, und jede greift genau eine Stelle des Gefechts
## an. Die Bedingung, unter der ein Aufbauspiel vor einem Geschicklichkeits-
## spiel überhaupt erlaubt ist, gilt hier wie überall: **jede Stufe muss sich
## im Lauf anfühlen**, sonst kauft man Zahlen statt Können.
##
## **Und keine davon gibt eine Waffe.** Was man führt, entscheidet sich im
## Lauf bei den Aufstiegen - sonst wäre der interessanteste Teil des Spiels
## schon vor dem Start entschieden.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezüge.

enum Bau { MAUER, SCHMIEDE, STALL, MUENZE }

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = ["Wall", "Forge", "Stable", "Mint"]

const BESCHREIBUNG: PackedStringArray = [
    "You set out with more life in you.",
    "Every weapon you carry bites harder.",
    "You cover ground faster.",
    "The slain leave more coin behind.",
]

const HOECHSTSTUFE := 25

const GRUNDKOSTEN: PackedFloat32Array = [40.0, 55.0, 48.0, 70.0]
const WACHSTUM: PackedFloat32Array = [1.33, 1.36, 1.34, 1.40]

## Wie viele Läufe eine volle Runde durch alle vier Bauten kosten darf. Aus
## dieser einen Zahl fällt der Ertrag eines Laufs - beide Seiten wachsen
## damit mit derselben Rate, und das Spiel bleibt auch im fünfzigsten Lauf
## rechenbar.
const LAEUFE_JE_RUNDE := 7.0


static func name_von(b: int) -> String:
    return NAMEN[clampi(b, 0, NAMEN.size() - 1)]


static func beschreibung_von(b: int) -> String:
    return BESCHREIBUNG[clampi(b, 0, BESCHREIBUNG.size() - 1)]


static func kosten(b: int, stufe: int) -> int:
    var i := clampi(b, 0, NAMEN.size() - 1)
    return int(ceil(GRUNDKOSTEN[i] * pow(WACHSTUM[i], float(maxi(0, stufe)))))


static func rundenkosten(stufe: int) -> float:
    var summe := 0.0
    for b in NAMEN.size():
        summe += float(kosten(b, stufe))
    return summe


static func _kurve(stufe: int) -> float:
    var t := clampf(float(stufe) / float(HOECHSTSTUFE), 0.0, 1.0)
    return 1.0 - pow(1.0 - t, 1.6)


const LEBEN_GRUND := 100.0
const LEBEN_HOECHST := 260.0

static func leben(stufe: int) -> float:
    return lerpf(LEBEN_GRUND, LEBEN_HOECHST, _kurve(stufe))


const SCHMIEDE_HOECHST := 1.85

static func schaden_faktor(stufe: int) -> float:
    return lerpf(1.0, SCHMIEDE_HOECHST, _kurve(stufe))


const TEMPO_GRUND := 200.0
const TEMPO_HOECHST := 272.0

static func tempo(stufe: int) -> float:
    return lerpf(TEMPO_GRUND, TEMPO_HOECHST, _kurve(stufe))


const MUENZE_HOECHST := 2.4

static func sold_faktor(stufe: int) -> float:
    return lerpf(1.0, MUENZE_HOECHST, _kurve(stufe))


## Die Sollkurve: welche Stufe ein Spieler nach `lauf` Läufen haben sollte.
static func stufe_soll(lauf: int) -> int:
    return clampi(int(floor(float(maxi(1, lauf) - 1) / 1.8)), 0, HOECHSTSTUFE)


## **Was ein Lauf einbringen soll** - abgeleitet aus den Baukosten, nicht
## frei gewählt. Ein Einkommen, das langsamer wächst als geometrische
## Kosten, holt sie nie wieder ein.
static func ertrag(lauf: int) -> int:
    return maxi(1, int(round(rundenkosten(stufe_soll(lauf)) / LAEUFE_JE_RUNDE)))
