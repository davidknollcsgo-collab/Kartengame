## Namen und Zeichen der drei Spielwährungen.
##
## Zentral gehalten, damit eine Umbenennung eine Datei betrifft und nicht
## dreißig. Alle drei sind frei erfunden - **kein Zeichen darf an eine echte
## Währung erinnern**. Der ursprüngliche Entwurf verwendete das Cent-Zeichen
## für die Grundwährung; bei einer App mit In-App-Käufen ist das nicht nur
## unschön, sondern verstößt gegen Googles Vorgabe, dass Spielwährung nicht
## mit echtem Geld verwechselbar sein darf.
class_name Waehrung
extends RefCounted

## Grundwährung, von den Baugruppen erzeugt.
const PLASMA := "Plasma"
const PLASMA_ZEICHEN := "◆"

## Premiumwährung aus Errungenschaften und später aus Käufen und Werbung.
const QUANTEN := "Quanten"
const QUANTEN_ZEICHEN := "✦"

## Prestigewährung, überlebt jeden Reset.
const PROTOKOLLE := "Protokolle"
const PROTOKOLL_ZEICHEN := "⬡"


static func plasma(wert: float) -> String:
    return Zahl.kurz(wert) + " " + PLASMA_ZEICHEN


## Ertrag je Sekunde, wie er im Kopfbereich steht.
static func plasma_rate(wert: float) -> String:
    return "+" + Zahl.kurz(wert) + " " + PLASMA_ZEICHEN + "/s"


static func quanten(wert: int) -> String:
    return str(wert) + " " + QUANTEN_ZEICHEN


static func protokolle(wert: int) -> String:
    return str(wert) + " " + PROTOKOLL_ZEICHEN
