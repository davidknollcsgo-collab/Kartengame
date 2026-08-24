## Errungenschaften und ihre Belohnungen.
##
## Zwei Aufgaben zugleich: langfristige Ziele über den reinen Zahlenanstieg
## hinaus, und die einzige Quelle für Quanten, die weder Werbung noch Kauf
## verlangt. Ohne sie wäre der Ausbau-Bildschirm für einen neuen Spieler
## unerreichbar - und für mich nicht testbar.
##
## Bedingungen sind Daten, keine Funktionen: so lässt sich die Tabelle als
## Konstante halten und im Testlauf durchrechnen.
class_name Errungenschaft
extends RefCounted

## art: Bedingungsart | wert: Schwelle | index: nur bei art "modul"
const TABELLE: Array[Dictionary] = [
    {"id": "start", "name": "Erste Handgriffe", "text": "Baue deine erste Baugruppe",
     "art": "bestand", "wert": 1.0, "quanten": 2},
    {"id": "zehn", "name": "Kleine Werft", "text": "Zehn Baugruppen in Betrieb",
     "art": "bestand", "wert": 10.0, "quanten": 3},
    {"id": "hundert", "name": "Betriebsam", "text": "Hundert Baugruppen in Betrieb",
     "art": "bestand", "wert": 100.0, "quanten": 5},
    {"id": "fuenfhundert", "name": "Großwerft", "text": "Fünfhundert Baugruppen",
     "art": "bestand", "wert": 500.0, "quanten": 10},
    {"id": "segel_zehn", "name": "Sonnenernte", "text": "Zehn Solarsegel",
     "art": "modul", "index": 0, "wert": 10.0, "quanten": 3},
    {"id": "alle_arten", "name": "Vollausbau", "text": "Von jeder Art mindestens eine",
     "art": "alle_arten", "wert": 1.0, "quanten": 15},
    {"id": "ertrag_m", "name": "Erste Million", "text": "Eine Million Plasma gefördert",
     "art": "lebenszeit", "wert": 1.0e6, "quanten": 3},
    {"id": "ertrag_b", "name": "Milliardenwerk", "text": "Eine Milliarde Plasma gefördert",
     "art": "lebenszeit", "wert": 1.0e9, "quanten": 8},
    {"id": "ertrag_t", "name": "Billionenwerk", "text": "Eine Billion Plasma gefördert",
     "art": "lebenszeit", "wert": 1.0e12, "quanten": 20},
    {"id": "rate_k", "name": "Dauerlauf", "text": "Tausend Plasma je Sekunde",
     "art": "rate", "wert": 1000.0, "quanten": 5},
    {"id": "reset_eins", "name": "Neuanfang", "text": "Die Station einmal zurücksetzen",
     "art": "prestige", "wert": 1.0, "quanten": 10},
    {"id": "reset_fuenf", "name": "Kreislauf", "text": "Fünf Zurücksetzungen",
     "art": "prestige", "wert": 5.0, "quanten": 25},
]


## Summe aller erreichbaren Quanten. Muss über dem Preis des Verstärkers
## liegen, sonst ist der ohne Kauf oder Werbung unerreichbar.
static func quanten_gesamt() -> int:
    var summe := 0
    for e in TABELLE:
        summe += int(e["quanten"])
    return summe


## Prüft eine Bedingung gegen einen Satz Messwerte.
##
## [param werte] erwartet die Schlüssel bestand (Array), lebenszeit, rate und
## prestige. Bewusst ein einfaches Dictionary statt des Spielstands: so bleibt
## diese Datei frei von Autoload-Bezügen und im Testlauf ladbar.
static func erfuellt(eintrag: Dictionary, werte: Dictionary) -> bool:
    var schwelle: float = eintrag["wert"]
    match String(eintrag["art"]):
        "bestand":
            return _summe(werte.get("bestand", [])) >= schwelle
        "modul":
            var bestand: Array = werte.get("bestand", [])
            var i: int = eintrag["index"]
            return i < bestand.size() and float(bestand[i]) >= schwelle
        "alle_arten":
            var alle: Array = werte.get("bestand", [])
            if alle.size() < Modul.ANZAHL:
                return false
            for i in Modul.ANZAHL:
                if int(alle[i]) < 1:
                    return false
            return true
        "lebenszeit":
            return float(werte.get("lebenszeit", 0.0)) >= schwelle
        "rate":
            return float(werte.get("rate", 0.0)) >= schwelle
        "prestige":
            return float(werte.get("prestige", 0)) >= schwelle
    return false


static func _summe(bestand: Array) -> float:
    var n := 0.0
    for k in bestand:
        n += float(k)
    return n
