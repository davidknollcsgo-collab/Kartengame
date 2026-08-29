class_name Tagesstroemung
extends RefCounted

## Drei Wellen je Tag, die mehr abwerfen.
##
## Aus dem Plan, Abschnitt Content-Gating: *drei Bonuswellen taeglich mit
## erhoehter Ausbeute*. Der Sinn ist nicht mehr Naehrstoff, sondern ein Grund,
## **heute** wiederzukommen.
##
## Deshalb ist die Zahl je Tag gedeckelt und nicht je Sitzung: wer eine Stunde
## am Stueck spielt, bekommt genau so viele Stroemungswellen wie wer dreimal
## fuenf Minuten spielt. Ein Bonus, der mit der Spieldauer waechst, belohnt
## Sitzen; einer, der mit dem Tag kommt, belohnt Wiederkommen. Das zweite ist
## das, was ein Spiel am Leben haelt.
##
## Was uebrig bleibt, verfaellt am Tageswechsel - aber es verfaellt nichts
## anderes. Dieselbe Regel wie beim Tagesziel: ein verpasster Tag kostet den
## Tag, nicht die Strecke.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Wie viele Stroemungswellen ein Tag hergibt.
const JE_TAG := 3

## Womit ihre Ausbeute malgenommen wird.
##
## Zwei ist bewusst eine Zahl, die man im Kopf nachrechnet. Ein Bonus, den man
## erst ausrechnen muss, wird nicht als Bonus empfunden.
const FAKTOR := 2.0


## Was eine Welle abwirft, wenn die Stroemung mitlaeuft.
static func ausbeute(grund: int, mit_stroemung: bool) -> int:
    if not mit_stroemung:
        return grund
    return maxi(grund, int(round(float(grund) * FAKTOR)))


## Der Hinweis fuer die Anzeige. Leer, wenn heute nichts mehr laeuft.
static func hinweis(offen: int) -> String:
    if offen <= 0:
        return ""
    return "Tagesstroemung x%d - noch %d" % [int(FAKTOR), offen]
