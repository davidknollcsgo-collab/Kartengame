## Dauerhafte Ausbauten, bezahlt mit Protokollen.
##
## Protokolle gaben bisher nur einen pauschalen Multiplikator - ein Reset war
## damit eine reine Rechenoperation ohne Entscheidung. Diese Ausbauten geben
## ihm eine Richtung: schneller wieder anlaufen, länger offline sammeln, oder
## billiger ausbauen.
##
## Wichtig: der passive Multiplikator hängt an den **jemals verdienten**
## Protokollen, nicht am Guthaben. Sonst würde jeder Kauf den Multiplikator
## senken und sich wie ein Verlust anfühlen - das hält Spieler davon ab, das
## System überhaupt zu benutzen.
class_name ProtokollAusbau
extends RefCounted

## id | name | text | stufen | kosten der ersten Stufe | Steigerung je Stufe
const TABELLE: Array[Dictionary] = [
    {"id": "startkapital", "name": "Notreserve",
     "text": "Mehr Plasma direkt nach einem Reset",
     "stufen": 5, "basis": 5, "wachstum": 4.0},
    {"id": "anlauf", "name": "Anlaufhilfe",
     "text": "Baugruppen stehen nach einem Reset schon bereit",
     "stufen": 5, "basis": 10, "wachstum": 5.0},
    {"id": "hand", "name": "Handförderung",
     "text": "Antippen des Kerns bringt deutlich mehr",
     "stufen": 5, "basis": 3, "wachstum": 3.0},
    {"id": "speicher", "name": "Pufferzellen",
     "text": "Größerer Anteil der Förderung zählt offline",
     "stufen": 4, "basis": 25, "wachstum": 4.0},
    {"id": "feinbau", "name": "Feinbau",
     "text": "Ausbaustufen der Baugruppen kosten weniger",
     "stufen": 5, "basis": 15, "wachstum": 4.0},
]


static func eintrag(id: String) -> Dictionary:
    for e in TABELLE:
        if String(e["id"]) == id:
            return e
    return {}


## Preis für den Sprung von [param stufe] auf die nächste; 0 bei Höchststufe.
static func kosten(id: String, stufe: int) -> int:
    var e := eintrag(id)
    if e.is_empty() or stufe >= int(e["stufen"]):
        return 0
    return int(round(float(e["basis"]) * pow(float(e["wachstum"]), stufe)))


static func max_stufe(id: String) -> int:
    var e := eintrag(id)
    return 0 if e.is_empty() else int(e["stufen"])


static func voll(id: String, stufe: int) -> bool:
    return stufe >= max_stufe(id)


# --- Wirkungen --------------------------------------------------------------

## Startguthaben nach einem Reset.
static func startkapital(stufe: int) -> float:
    if stufe <= 0:
        return 0.0
    return pow(10.0, 1.0 + 2.0 * float(stufe))


## Wie viele Exemplare der ersten Baugruppen nach einem Reset schon stehen.
static func anlauf_stueck(stufe: int) -> int:
    return maxi(stufe, 0) * 5


## Wie viele Baugruppenarten die Anlaufhilfe abdeckt.
static func anlauf_arten(stufe: int) -> int:
    return mini(maxi(stufe, 0), 3)


## Faktor auf den Ertrag eines Antippens.
static func hand_faktor(stufe: int) -> float:
    return 1.0 + 4.0 * float(maxi(stufe, 0))


## Anteil der Förderung, der offline gutgeschrieben wird.
static func offline_anteil(stufe: int) -> float:
    return minf(Oekonomie.OFFLINE_ANTEIL + 0.10 * float(maxi(stufe, 0)), 0.90)


## Faktor auf die Kosten einer Baugruppen-Ausbaustufe.
static func ausbau_rabatt(stufe: int) -> float:
    return pow(0.92, float(maxi(stufe, 0)))
