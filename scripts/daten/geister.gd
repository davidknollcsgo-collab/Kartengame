class_name Geister
extends RefCounted

## Gegner ohne Server.
##
## Der Plan sagt: Geisterdaten statt Echtzeit - kein Server, keine
## Chat-Moderation, keine DSGVO-Pflichten, keine Betriebskosten. Hier ist die
## Umsetzung dieses Versprechens.
##
## **Wie ein Geist entsteht.** Jede Welle ist gerechnet und damit fuer alle
## Spieler dieselbe. Der Simulator kann sie also mit einem beliebigen
## Koennensgrad durchspielen und bekommt eine Zahl heraus, die genau so
## zustande kaeme, wenn ein Mensch auf diesem Stand spielte. Das ist kein
## erfundener Bestenlisteneintrag, sondern ein nachvollziehbares Ergebnis.
##
## **Was das nicht ist.** Kein echter Mensch. Es steht auch nirgends etwas
## anderes: die Namen sind Kolonien, keine Spielernamen, und wer nachrechnen
## will, kann es. Eine Bestenliste, die vorgibt, echte Gegner zu haben, waere
## eine Luege - und sie fliegt auf, sobald jemand zwei Geraete vergleicht.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Namen der Nachbarkolonien. Erfunden nach demselben Muster wie alles andere
## hier: deutsche Wortbildungen aus der Tiefseewelt.
const NAMEN: PackedStringArray = [
    "Ashmaw", "Coldbed", "Deepmire", "Saltvein", "Nightreef",
    "Greylight", "Stonelung", "Murkrun", "Blackward", "Icefloor",
]

## Koennensgrade der Nachbarn, als Anteil des Sollausbaus.
##
## Die Leiter beginnt bewusst weit unten. Im ersten Entwurf lag der
## schwaechste Nachbar bei Welle 23 - ein neuer Spieler stand damit abgeschlagen
## Letzter, mit zweiundzwanzig Wellen bis zum naechsten Namen. Das ist der
## denkbar schlechteste erste Eindruck. Jetzt steht immer jemand in Reichweite:
## die Tiefen liegen bei rund 4, 10, 16, 23, 29, 35, 41, 47, 53 und 60.
const STAERKEN: PackedFloat32Array = [
    0.30, 0.38, 0.46, 0.55, 0.63, 0.72, 0.80, 0.88, 0.96, 1.06,
]


static func zahl() -> int:
    return NAMEN.size()


static func name_von(index: int) -> String:
    return NAMEN[clampi(index, 0, NAMEN.size() - 1)]


static func staerke(index: int) -> float:
    return STAERKEN[clampi(index, 0, STAERKEN.size() - 1)]


## Wie tief ein Nachbar gekommen ist.
##
## Nicht gewuerfelt: die Tiefe faellt aus seiner Staerke. Ein Nachbar mit 0.70
## des Sollausbaus kommt so weit, wie 0.70 des Sollausbaus tragen - und das
## laesst sich mit `tools/wellenpruefer.gd -- --spielraum` nachrechnen.
static func tiefe(index: int) -> int:
    var s := staerke(index)
    # Der Spielraum faellt von 0.25 in den ersten Sitzungen auf 1.00 in den
    # letzten. Wer Staerke s hat, kommt bis dorthin, wo der Spielraum s
    # erreicht - danach wird es fuer ihn zu eng.
    for n in range(1, Graben.WELLEN_GESAMT + 1):
        if _noetige_staerke(n) > s:
            return maxi(1, n - 1)
    return Graben.WELLEN_GESAMT


## Welchen Anteil des Sollausbaus Welle `nummer` mindestens verlangt.
## Naeherung an die Kurve, die der Wellenpruefer misst.
static func _noetige_staerke(nummer: int) -> float:
    var t := float(clampi(nummer, 1, Graben.WELLEN_GESAMT) - 1) \
        / float(maxi(1, Graben.WELLEN_GESAMT - 1))
    return lerpf(0.25, 1.05, t)


## Die Rangliste: alle Nachbarn und der Spieler, nach Tiefe sortiert.
##
## Jeder Eintrag: `name`, `tiefe`, `selbst`.
static func rangliste(eigene_tiefe: int) -> Array[Dictionary]:
    var liste: Array[Dictionary] = []
    for i in zahl():
        liste.append({
            &"name": name_von(i),
            &"tiefe": tiefe(i),
            &"selbst": false,
        })
    liste.append({
        &"name": "Your colony",
        &"tiefe": clampi(eigene_tiefe, 1, Graben.WELLEN_GESAMT),
        &"selbst": true,
    })

    liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if a[&"tiefe"] != b[&"tiefe"]:
            return a[&"tiefe"] > b[&"tiefe"]
        # Bei Gleichstand steht der Spieler oben - er hat es gerade erreicht.
        return a[&"selbst"] and not b[&"selbst"])
    return liste


## Der eigene Platz, ab 1 gezaehlt.
static func platz(eigene_tiefe: int) -> int:
    var liste := rangliste(eigene_tiefe)
    for i in liste.size():
        if liste[i][&"selbst"]:
            return i + 1
    return liste.size()


## Der naechste Nachbar ueber einem - der, den man als Naechstes einholt.
## Leerer Name, wenn man ganz oben steht.
static func naechster_vor(eigene_tiefe: int) -> Dictionary:
    var liste := rangliste(eigene_tiefe)
    for i in liste.size():
        if liste[i][&"selbst"] and i > 0:
            return liste[i - 1]
    return {&"name": "", &"tiefe": 0, &"selbst": false}
