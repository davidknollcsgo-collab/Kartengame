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
]

const HINWEISE: PackedStringArray = [
    "Calm water. The cone obeys.",
    "A current tugs at the light. Hold against it.",
    "Murky water swallows the range. Let them come closer.",
    "The light organ cuts out. Count the pauses.",
    "Only the middle of the cone still burns. Aim precisely.",
    "Everything at once - and the current runs crosswise.",
]

## --- Stroemung: der Kegel wird abgetrieben ---
##
## Zwei ueberlagerte Schwingungen mit unrundem Verhaeltnis, damit sich das
## Muster nicht in wenigen Sekunden wiederholt und auswendig lernen laesst.
const STROM_AB := 1          ## ab Abschnitt 2 (Index 1)
const STROM_WEITE := 0.155
const STROM_WEITE_STURM := 0.245
const STROM_TAKT_A := 0.41
const STROM_TAKT_B := 0.97

## --- Dunkelphasen: das Leuchtorgan setzt aus ---
const DUNKEL_AB := 3
const DUNKEL_ZYKLUS := 7.4
const DUNKEL_DAUER := 1.25
const DUNKEL_ZYKLUS_STURM := 5.6
const DUNKEL_TIEFE := 0.22    ## Restlicht waehrend der Pause

## --- Truebe Tiefe: die Reichweite verliert frueher an Kraft ---
const TRUEB_AB := 2
const TIEFE_KERN_TRUEB := 0.26

## --- Streulicht: nur die Mitte des Kegels brennt ---
const STREU_AB := 4
const RAND_KERN_STREU := 0.30

const STURM := 5              ## Abschnitt 6 (Index 5)


static func name_von(abschnitt: int) -> String:
    return NAMEN[clampi(abschnitt, 0, NAMEN.size() - 1)]


static func hinweis(abschnitt: int) -> String:
    return HINWEISE[clampi(abschnitt, 0, HINWEISE.size() - 1)]


## Ablenkung des Kegels in Bogenmass. 0.0 heisst ruhiges Wasser.
static func stroemung(nummer: int, zeit: float) -> float:
    var a := Graben.abschnitt(nummer)
    if a < STROM_AB:
        return 0.0
    var weite := STROM_WEITE_STURM if a >= STURM else STROM_WEITE
    return weite * (0.68 * sin(zeit * STROM_TAKT_A)
        + 0.32 * sin(zeit * STROM_TAKT_B + 1.9))


## Wieviel Licht das Leuchtorgan gerade abgibt: 1.0 voll, weniger waehrend
## einer Dunkelphase. Multipliziert die Helligkeit - und damit auch den
## Schaden, denn beide kommen aus derselben Zahl.
static func helligkeit(nummer: int, zeit: float) -> float:
    var a := Graben.abschnitt(nummer)
    if a < DUNKEL_AB:
        return 1.0
    var zyklus := DUNKEL_ZYKLUS_STURM if a >= STURM else DUNKEL_ZYKLUS
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
    if Graben.abschnitt(nummer) < TRUEB_AB:
        return Schlund.TIEFE_KERN
    return TIEFE_KERN_TRUEB


## Wie breit der volle Kern des Kegels ist, als Anteil der Halbbreite.
static func rand_kern(nummer: int) -> float:
    if Graben.abschnitt(nummer) < STREU_AB:
        return Schlund.RAND_KERN
    return RAND_KERN_STREU


## Ob dieser Abschnitt gegenueber dem vorigen etwas Neues mitbringt. Nur dann
## lohnt es, den Spieler darauf hinzuweisen.
static func neu_in(abschnitt: int) -> bool:
    return abschnitt in [0, STROM_AB, TRUEB_AB, DUNKEL_AB, STREU_AB, STURM]


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
    if a < DUNKEL_AB:
        return 1.0
    var zyklus := DUNKEL_ZYKLUS_STURM if a >= STURM else DUNKEL_ZYKLUS
    var summe := 0.0
    for i in TAKTE:
        summe += helligkeit(nummer, (float(i) + 0.5) / float(TAKTE) * zyklus)
    return summe / float(TAKTE)


static func _stroemungsverlust(nummer: int) -> float:
    var a := Graben.abschnitt(nummer)
    if a < STROM_AB:
        return 1.0
    return STROM_VERLUST_STURM if a >= STURM else STROM_VERLUST
