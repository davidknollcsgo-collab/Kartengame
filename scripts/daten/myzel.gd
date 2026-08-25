## Das Myzel: der Fortschrittsbaum, bezahlt mit Biomasse.
##
## Alle Knoten **helfen nur** - keiner macht etwas schwerer. Das ist keine
## Bequemlichkeit, sondern eine Zusicherung: die Lösbarkeit aller dreißig
## Kammern wurde mit den Grundwerten geprüft. Ein Knoten, der etwa die
## Lebensdauer der Spuren verlängert, könnte eine geprüfte Kammer unlösbar
## machen - und niemand würde es merken, bis ein Spieler feststeckt.
class_name Myzel
extends RefCounted

## ast | name | text | stufen | kosten der ersten Stufe | Steigerung
const TABELLE: Array[Dictionary] = [
    {"id": "wurf", "ast": "Wurf", "name": "Weitsicht",
     "text": "Die Zielhilfe zeigt einen Abprall mehr voraus",
     "stufen": 2, "basis": 40.0, "wachstum": 6.0},
    {"id": "wucht", "ast": "Wucht", "name": "Nachdruck",
     "text": "Die Spore prallt einmal öfter ab, bevor sie liegen bleibt",
     "stufen": 3, "basis": 90.0, "wachstum": 5.0},
    {"id": "zerfall", "ast": "Zerfall", "name": "Streuflug",
     "text": "Größerer Wirkradius der Spore",
     "stufen": 3, "basis": 65.0, "wachstum": 4.5},
    {"id": "vorrat", "ast": "Vorrat", "name": "Sporenlager",
     "text": "Eine Spore mehr in jeder Kammer",
     "stufen": 3, "basis": 150.0, "wachstum": 6.5},
    {"id": "ernte", "ast": "Ernte", "name": "Zersetzung",
     "text": "Mehr Biomasse aus jeder geräumten Kammer",
     "stufen": 4, "basis": 55.0, "wachstum": 3.6},
]


static func eintrag(id: String) -> Dictionary:
    for e in TABELLE:
        if String(e["id"]) == id:
            return e
    return {}


## Preis für den Sprung von [param stufe] auf die nächste; 0 bei Höchststufe.
static func kosten(id: String, stufe: int) -> float:
    var e := eintrag(id)
    if e.is_empty() or stufe >= int(e["stufen"]):
        return 0.0
    return float(e["basis"]) * pow(float(e["wachstum"]), float(stufe))


static func max_stufe(id: String) -> int:
    var e := eintrag(id)
    return 0 if e.is_empty() else int(e["stufen"])


static func voll(id: String, stufe: int) -> bool:
    return stufe >= max_stufe(id)


# --- Wirkungen --------------------------------------------------------------

## Wie viele Abpraller die Zielhilfe voraus zeigt.
static func vorschau_abpraller(stufe: int) -> int:
    return Werfer.VORSCHAU_ABPRALLER + maxi(stufe, 0)


## Zusätzliche Abpraller je Schuss.
static func mehr_abpraller(stufe: int) -> int:
    return maxi(stufe, 0)


## Wirkradius der Spore.
static func spore_radius(stufe: int) -> float:
    return Spore.RADIUS + 2.2 * float(maxi(stufe, 0))


## Zusätzliche Sporen je Kammer.
static func mehr_sporen(stufe: int) -> int:
    return maxi(stufe, 0)


## Faktor auf den Biomasse-Ertrag.
static func ertrag_faktor(stufe: int) -> float:
    return 1.0 + 0.25 * float(maxi(stufe, 0))
