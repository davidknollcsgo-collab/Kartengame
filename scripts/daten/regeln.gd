class_name Regeln
extends RefCounted

## Was jeden Grabenabschnitt anders macht.
##
## Sechs Abschnitte zu je zehn Wellen. Ohne eigene Regeln waeren es sechs
## Farben ueber derselben Welle - und sechzig Wellen desselben Handgriffs sind
## kein Inhalt, sondern eine Zahl, die hochlaeuft.
##
## **Alle vier Regeln sind reine Funktionen von Wellennummer und Zeit.** Das
## ist keine Stilfrage: der Wellenpruefer rechnet dieselben Funktionen und
## prueft dadurch das Spiel, das gespielt wird. Eine Regel, die nur im Spiel
## existiert, waere eine Regel, die niemand geprueft hat.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

const NAMEN: PackedStringArray = [
    "Rim Gorge",
    "Current Rift",
    "Murky Deep",
    "Dark Band",
    "Scatterlight Zone",
    "Trench Storm",
    "Still Trench",
    "The Weight",
]

const HINWEISE: PackedStringArray = [
    "Calm water. The cone obeys.",
    "A current tugs at the light. Hold against it.",
    "Murky water swallows the range. Let them come closer.",
    "The light organ cuts out. Count the pauses.",
    "Only the middle of the cone still burns. Aim precisely.",
    "Everything at once - and the current runs crosswise.",
    "Quiet water. They make up for it in numbers.",
    "Clear sight, heavy current, and the organ keeps failing.",
]

## --- Wie ein Abschnitt aussieht ---
##
## Sechs Abschnitte, die sich unterschiedlich spielen und identisch aussahen.
## Damit fuehlte sich Welle 55 an wie Welle 5 mit mehr Tieren - das Absteigen
## war eine Zahl in der Kopfzeile, kein Ort.
##
## Jeder Abschnitt hat deshalb eine eigene Wasserfarbe, einen eigenen
## Felston und eine eigene Schwebstoffdichte. Sie folgen dem, was der
## Abschnitt **tut**: die Truebe Tiefe ist wirklich truebe, das Finsterband
## wirklich finster, der Grabensturm wirklich aufgewuehlt.

## Die Dunkelheit oben im Bild.
## **Dunkel darf es sein, schwarz nicht.**
##
## Die Werte lagen bei acht Tausendsteln, und im Bild war der obere Teil des
## Grabens dadurch keine Tiefe, sondern ein Loch: eine schwarze Flaeche mit
## einer sichtbaren Kante dort, wo die Wand anfing. Tiefes Wasser ist nicht
## schwarz - es ist sehr dunkles Blau, und der Unterschied ist genau der,
## dass man in das eine hineinsieht und auf das andere schaut. Die Abstaende
## zwischen den Abschnitten bleiben, nur der Boden ist angehoben.
## **Sie waren richtig gemischt und viel zu dunkel.**
##
## Die Farbtoene stimmten - kaltes Blau, gruenlicher Schlamm, Eisenrot -, nur
## lagen sie alle zwischen 0.012 und 0.044. Nach der seitlichen Verdunkelung
## des Shaders kam davon RGB 2 bis 8 auf dem Bild an, und acht Abschnitte, die
## sich unterscheiden sollen, sahen alle schwarz aus. Eine Farbe, die man nur
## mit der Pipette findet, ist keine.
##
## Gehoben, nicht umgefaerbt: dieselben Toene, gut doppelt so hell. Das Bild
## bleibt dunkel - der Kegel und die Tiere sind additiv und liegen um ein
## Vielfaches darueber -, aber der Graben hat jetzt in jedem Abschnitt eine
## Farbe, die man beim Hinsehen sieht statt beim Messen.
const TIEF_FARBEN: PackedColorArray = [
    Color(0.034, 0.071, 0.122),   ## Rim Gorge - offenes, kaltes Blau
    Color(0.025, 0.076, 0.147),   ## Current Rift - klarer und kaelter
    Color(0.050, 0.092, 0.076),   ## Murky Deep - gruenlicher Schlamm
    Color(0.042, 0.034, 0.080),   ## Dark Band - fast schwarz, violett
    Color(0.071, 0.105, 0.143),   ## Scatterlight Zone - milchig aufgehellt
    Color(0.092, 0.055, 0.050),   ## Trench Storm - eisenrot und schwer
    Color(0.029, 0.088, 0.105),   ## Still Trench - klar und kuehl, viel Sicht
    Color(0.038, 0.029, 0.097),   ## The Weight - tiefes Indigo, schwer
]

## Das Wasser in mittlerer Hoehe.
const GRUND_FARBEN: PackedColorArray = [
    Color(0.039, 0.121, 0.166),
    Color(0.031, 0.113, 0.195),
    Color(0.066, 0.129, 0.090),
    Color(0.043, 0.035, 0.078),
    Color(0.101, 0.152, 0.183),
    Color(0.121, 0.062, 0.058),
    Color(0.035, 0.137, 0.152),   ## Still Trench
    Color(0.039, 0.031, 0.101),   ## The Weight
]

## Der Schein der Kolonie, der von unten heraufkommt.
const SCHEIN_FARBEN: PackedColorArray = [
    Color(0.067, 0.220, 0.232),
    Color(0.049, 0.207, 0.256),
    Color(0.085, 0.207, 0.134),
    Color(0.085, 0.061, 0.171),
    Color(0.134, 0.207, 0.232),
    Color(0.207, 0.098, 0.073),
    Color(0.061, 0.226, 0.220),   ## Still Trench
    Color(0.091, 0.055, 0.201),   ## The Weight
]

## Wieviel Schwebstoff im Wasser haengt. Mehr heisst weniger Sicht - und in
## der Truebe Tiefe und im Grabensturm ist das der Punkt.
## Still Trench ist der klarste Abschnitt des Grabens - das ist sein ganzer
## Charakter. The Weight liegt dazwischen: man sieht weit, aber nicht ruhig.
const SCHNEE_DICHTE: PackedFloat32Array = [1.0, 0.9, 1.7, 0.7, 1.3, 2.0, 0.5, 1.1]

## Der Fels. Er nimmt die Farbe des Wassers an, in dem er steht.
## **Dunkler als zuvor, und das ist die andere Haelfte derselben Sache.**
## Der naechste Fels muss deutlich unter dem Dunst liegen (`Kolonie.DUNST`),
## sonst kommen ferne und nahe Wand in derselben Farbe heraus und die
## Staffelung ist umsonst. Die Farbtoene bleiben, nur der Wert faellt.
const FELS_FARBEN: PackedColorArray = [
    Color(0.030, 0.050, 0.068),
    Color(0.026, 0.048, 0.074),
    Color(0.040, 0.054, 0.034),
    Color(0.030, 0.026, 0.050),
    Color(0.050, 0.062, 0.072),
    Color(0.062, 0.036, 0.032),
    Color(0.028, 0.052, 0.058),   ## Still Trench
    Color(0.028, 0.024, 0.056),   ## The Weight
]


static func tief_farbe(abschnitt: int) -> Color:
    return TIEF_FARBEN[clampi(abschnitt, 0, TIEF_FARBEN.size() - 1)]


static func grund_farbe(abschnitt: int) -> Color:
    return GRUND_FARBEN[clampi(abschnitt, 0, GRUND_FARBEN.size() - 1)]


static func schein_farbe(abschnitt: int) -> Color:
    return SCHEIN_FARBEN[clampi(abschnitt, 0, SCHEIN_FARBEN.size() - 1)]


static func schnee_dichte(abschnitt: int) -> float:
    return SCHNEE_DICHTE[clampi(abschnitt, 0, SCHNEE_DICHTE.size() - 1)]


## Wie stark der Schein der Kolonie in Saeulen steht, und wie eng sich das
## Bild zu den Seiten schliesst. Beides folgt dem Abschnitt: der Grabensturm
## ist aufgewuehlt und bedrueckend, die Randschlucht offen und ruhig.
const SAEULEN: PackedFloat32Array = [0.75, 0.55, 1.35, 0.35, 1.6, 1.9, 0.45, 1.15]
const ENGE: PackedFloat32Array = [0.0, 0.10, 0.45, 0.30, 0.20, 0.70, 0.05, 0.55]


static func saeulen(abschnitt: int) -> float:
    return SAEULEN[clampi(abschnitt, 0, SAEULEN.size() - 1)]


static func enge(abschnitt: int) -> float:
    return ENGE[clampi(abschnitt, 0, ENGE.size() - 1)]


static func fels_farbe(abschnitt: int) -> Color:
    return FELS_FARBEN[clampi(abschnitt, 0, FELS_FARBEN.size() - 1)]


## --- Stroemung: der Kegel wird abgetrieben ---
##
## Zwei ueberlagerte Schwingungen mit unrundem Verhaeltnis, damit sich das
## Muster nicht in wenigen Sekunden wiederholt und auswendig lernen laesst.
const STROM_WEITE := 0.155
const STROM_WEITE_STURM := 0.245
const STROM_TAKT_A := 0.41
const STROM_TAKT_B := 0.97

## --- Dunkelphasen: das Leuchtorgan setzt aus ---
const DUNKEL_ZYKLUS := 7.4
const DUNKEL_DAUER := 1.25
const DUNKEL_ZYKLUS_STURM := 5.6
const DUNKEL_TIEFE := 0.22    ## Restlicht waehrend der Pause

## --- Truebe Tiefe: die Reichweite verliert frueher an Kraft ---
const TIEFE_KERN_TRUEB := 0.26

## --- Streulicht: nur die Mitte des Kegels brennt ---
const RAND_KERN_STREU := 0.30

const STURM := 5              ## Abschnitt 6 (Index 5)

## --- Welcher Abschnitt welche Regel traegt ---
##
## **Vorher stand das als `if a < STROM_AB: return 0.0` in jeder Regel, und
## das war eine Sackgasse.** Die Schwellen sind kumulativ: wer eine Regel ab
## Abschnitt 1 hat, hat sie in allen folgenden auch. Solange es sechs
## Abschnitte gibt, liest sich das wie eine Steigerung. Sobald ein siebter
## dazukommt, ist er zwangslaeufig der bisher haerteste - mit **allem**, und
## wegen `a >= STURM` sogar in Sturmstaerke. Ein Graben, in dem jeder neue
## Abschnitt nur mehr Regeln auf einmal hat, kann nicht mehr atmen: er hat
## keine Ruhe, keinen Wechsel und keine Ueberraschung, nur Zuwachs.
##
## Eine Tabelle sagt dasselbe fuer die ersten sechs Abschnitte und laesst
## danach die Wahl. Sie ist bewusst so gefuellt, dass sich am bestehenden
## Spiel **nichts** aendert - der Wellenpruefer muss danach dieselbe Zeile
## ausgeben wie davor, sonst war es kein Umbau, sondern eine Aenderung.
enum Regel { STROM, DUNKEL, TRUEB, STREU }

## Je Abschnitt: welche Regeln gelten, und ob in Sturmstaerke.
const TAFEL: Array[Dictionary] = [
    {&"regeln": [], &"sturm": false},
    {&"regeln": [Regel.STROM], &"sturm": false},
    {&"regeln": [Regel.STROM, Regel.TRUEB], &"sturm": false},
    {&"regeln": [Regel.STROM, Regel.TRUEB, Regel.DUNKEL], &"sturm": false},
    {&"regeln": [Regel.STROM, Regel.TRUEB, Regel.DUNKEL, Regel.STREU],
        &"sturm": false},
    {&"regeln": [Regel.STROM, Regel.TRUEB, Regel.DUNKEL, Regel.STREU],
        &"sturm": true},
    # **Still Trench: der erste Abschnitt, der leichter wird.** Nach dem
    # Sturm nur noch Truebe - klares, ruhiges Wasser. Das ist keine
    # Nachlaessigkeit, sondern der Grund, warum der naechste Sturm wieder
    # trifft: ohne Atemzug dazwischen ist eine Steigerung nur noch Laerm.
    #
    # Leichter heisst nicht harmlos. `Wellen.staerke()` rechnet aus dem
    # Wirkungsgrad, also kauft ein ruhiger Abschnitt mehr Tiere fuer dasselbe
    # Budget - ruhiges Wasser, dafuer volle Wellen. Genau das steht im
    # Hinweis.
    {&"regeln": [Regel.TRUEB], &"sturm": false},
    # **The Weight: eine andere Mischung, kein weiterer Aufschlag.** Volle
    # Sicht und voller Kegel, dafuer Sturmstroemung und Dunkelphasen. Wer
    # hier ankommt, kann weit sehen und trotzdem nicht halten - das ist ein
    # anderer Griff als der Sturm, nicht mehr davon.
    {&"regeln": [Regel.STROM, Regel.DUNKEL], &"sturm": true},
]


## Ob dieser Abschnitt die Regel traegt.
static func hat(abschnitt: int, regel: int) -> bool:
    var i := clampi(abschnitt, 0, TAFEL.size() - 1)
    return (TAFEL[i][&"regeln"] as Array).has(regel)


## Ob dieser Abschnitt seine Regeln in Sturmstaerke fuehrt.
static func stuermisch(abschnitt: int) -> bool:
    return bool(TAFEL[clampi(abschnitt, 0, TAFEL.size() - 1)][&"sturm"])


static func name_von(abschnitt: int) -> String:
    return NAMEN[clampi(abschnitt, 0, NAMEN.size() - 1)]


static func hinweis(abschnitt: int) -> String:
    return HINWEISE[clampi(abschnitt, 0, HINWEISE.size() - 1)]


## Ablenkung des Kegels in Bogenmass. 0.0 heisst ruhiges Wasser.
static func stroemung(nummer: int, zeit: float) -> float:
    var a := Graben.abschnitt(nummer)
    if not hat(a, Regel.STROM):
        return 0.0
    var weite := STROM_WEITE_STURM if stuermisch(a) else STROM_WEITE
    return weite * (0.68 * sin(zeit * STROM_TAKT_A)
        + 0.32 * sin(zeit * STROM_TAKT_B + 1.9))


## Wieviel Licht das Leuchtorgan gerade abgibt: 1.0 voll, weniger waehrend
## einer Dunkelphase. Multipliziert die Helligkeit - und damit auch den
## Schaden, denn beide kommen aus derselben Zahl.
static func helligkeit(nummer: int, zeit: float) -> float:
    var a := Graben.abschnitt(nummer)
    if not hat(a, Regel.DUNKEL):
        return 1.0
    var zyklus := DUNKEL_ZYKLUS_STURM if stuermisch(a) else DUNKEL_ZYKLUS
    var seit := fmod(maxf(0.0, zeit), zyklus)
    if seit >= DUNKEL_DAUER:
        return 1.0
    # Weich ein- und ausblenden. Ein harter Schnitt saehe nach Fehler aus,
    # nicht nach einem Organ, das flackert.
    var t := seit / DUNKEL_DAUER
    var tiefe := sin(t * PI)
    return lerpf(1.0, DUNKEL_TIEFE, tiefe)


## Ab welchem Anteil der Reichweite der Kegel abfaellt.
static func tiefe_kern(nummer: int) -> float:
    if not hat(Graben.abschnitt(nummer), Regel.TRUEB):
        return Schlund.TIEFE_KERN
    return TIEFE_KERN_TRUEB


## Wie breit der volle Kern des Kegels ist, als Anteil der Halbbreite.
static func rand_kern(nummer: int) -> float:
    if not hat(Graben.abschnitt(nummer), Regel.STREU):
        return Schlund.RAND_KERN
    return RAND_KERN_STREU


## Ob dieser Abschnitt gegenueber dem vorigen etwas Neues mitbringt. Nur dann
## lohnt es, den Spieler darauf hinzuweisen.
##
## **Aus der Tafel abgelesen, nicht aufgezaehlt.** Vorher stand hier eine
## Liste der Schwellen - und die haette man bei jedem neuen Abschnitt von Hand
## nachziehen muessen, mit dem einzigen Hinweis darauf, dass irgendwann eine
## Tafel erscheint, die niemand ankuendigt. Neu ist ein Abschnitt, der eine
## Regel traegt, die der vorige nicht hatte, oder der als erster stuermt.
static func neu_in(abschnitt: int) -> bool:
    if abschnitt <= 0:
        return true
    for r in [Regel.STROM, Regel.DUNKEL, Regel.TRUEB, Regel.STREU]:
        if hat(abschnitt, r) and not hat(abschnitt - 1, r):
            return true
    return stuermisch(abschnitt) and not stuermisch(abschnitt - 1)


# --- Was die Regeln den Spieler kosten -------------------------------------
#
# `Wellen.staerke()` leitet die Wellenstaerke aus dem ab, was ein Spieler
# leisten kann. Kennt sie die Regeln nicht, wird jeder neue Abschnitt zur
# Wand: der Wellenpruefer meldete nach Einfuehrung der Regeln fuenf gefallene
# Sitzungen ab Welle 36. Diese Funktionen rechnen den Verlust aus, statt ihn
# zu schaetzen - wer an einer Regel dreht, dreht die Wellenstaerke mit.

## Aufloesung der Zahlenintegration. Grob genug, um billig zu sein, fein genug
## fuer einen Faktor, der ohnehin nur die Groessenordnung setzen muss.
const GITTER := 24
const TAKTE := 48

## Was das Gegenhalten gegen die Stroemung an Zielzeit kostet. Anders als die
## uebrigen drei laesst sich das nicht aus der Kegelform ableiten - es haengt
## am Drehtempo. Gemessen wurde es am Wellenpruefer.
const STROM_VERLUST := 0.93
const STROM_VERLUST_STURM := 0.87


## Wieviel von seiner Leistung ein Spieler in diesem Abschnitt ueberhaupt auf
## die Raeuber bringt, verglichen mit ruhigem Wasser. 1.0 heisst: kein Verlust.
static func wirkungsgrad(nummer: int) -> float:
    var form := _kegelanteil(rand_kern(nummer), tiefe_kern(nummer)) \
        / maxf(0.0001, _kegelanteil(Schlund.RAND_KERN, Schlund.TIEFE_KERN))
    return form * _mittlere_helligkeit(nummer) * _stroemungsverlust(nummer)


## Mittlere Helligkeit ueber die Kegelflaeche, bei gegebener Form.
##
## Ueber die Tiefe wird mit `laengs` gewichtet: ein Ring weit vorn ist laenger
## als einer nah an der Spitze und deckt entsprechend mehr Wasser ab.
static func _kegelanteil(rk: float, tk: float) -> float:
    var summe := 0.0
    var gewicht := 0.0
    for i in GITTER:
        var laengs := (float(i) + 0.5) / float(GITTER)
        var tiefe := 1.0 - smoothstep(clampf(tk, 0.0, 0.999), 1.0, laengs)
        for j in GITTER:
            var quer := (float(j) + 0.5) / float(GITTER)
            var rand := smoothstep(0.0, maxf(0.001, 1.0 - rk), quer)
            summe += rand * tiefe * laengs
            gewicht += laengs
    return summe / maxf(0.0001, gewicht)


## Mittlere Helligkeit ueber einen vollen Dunkelzyklus.
static func _mittlere_helligkeit(nummer: int) -> float:
    var a := Graben.abschnitt(nummer)
    if not hat(a, Regel.DUNKEL):
        return 1.0
    var zyklus := DUNKEL_ZYKLUS_STURM if stuermisch(a) else DUNKEL_ZYKLUS
    var summe := 0.0
    for i in TAKTE:
        summe += helligkeit(nummer, (float(i) + 0.5) / float(TAKTE) * zyklus)
    return summe / float(TAKTE)


static func _stroemungsverlust(nummer: int) -> float:
    var a := Graben.abschnitt(nummer)
    if not hat(a, Regel.STROM):
        return 1.0
    return STROM_VERLUST_STURM if stuermisch(a) else STROM_VERLUST
