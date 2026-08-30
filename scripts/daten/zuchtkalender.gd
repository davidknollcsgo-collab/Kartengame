class_name Zuchtkalender
extends RefCounted

## Sieben Tage Anwesenheit, und am siebten steht eine Brutlinie.
##
## Aus dem Plan, Abschnitt Content-Gating. Er laeuft **genau einmal** - das ist
## keine Sparmassnahme, sondern der Entwurf: ein Kalender, der sich alle sieben
## Tage neu auffuellt, verschenkt Brutlinien am laufenden Band und entwertet
## damit die einzige Waehrung, um die es hier geht. Sieben Tage, ein Geschenk,
## fertig.
##
## Und er verfaellt nicht. Wer einen Tag auslaesst, verliert den Tag, nicht den
## Kalender - dieselbe Regel wie beim Tagesziel. Eine Strecke, die bei einem
## verpassten Tag auf null faellt, erzeugt Druck statt Gewohnheit.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

const TAGE := 7

## Was die ersten sechs Tage einbringen. Der siebte steht nicht in der Liste -
## er gibt eine Brutlinie, und die kostet keinen Naehrstoff, sondern beendet
## den Kalender.
const NAEHRSTOFF: PackedInt32Array = [70, 110, 160, 230, 320, 460, 0]

## Derselbe Zuwachs wie beim Tagesziel: was an Tag 1 grosszuegig ist, waere an
## Welle 40 ein Almosen.
const LOHN_JE_WELLE := 0.06


static func ist_linientag(index: int) -> bool:
    return index == TAGE - 1


static func naehrstoff(index: int, hoechste_welle: int) -> int:
    if index < 0 or index >= NAEHRSTOFF.size() or ist_linientag(index):
        return 0
    return int(round(float(NAEHRSTOFF[index])
        * (1.0 + LOHN_JE_WELLE * float(maxi(0, hoechste_welle - 1)))))


## Was in dem kleinen Kasten des Tages steht.
static func kurz(index: int, hoechste_welle: int) -> String:
    if ist_linientag(index):
        return "LINE"
    return "+%d" % naehrstoff(index, hoechste_welle)
