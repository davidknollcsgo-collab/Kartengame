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
    "Randschlucht",
    "Stroemungsspalte",
    "Truebe Tiefe",
    "Finsterband",
    "Streulichtzone",
    "Grabensturm",
]

const HINWEISE: PackedStringArray = [
    "Ruhiges Wasser. Der Kegel gehorcht.",
    "Eine Stroemung zerrt am Licht. Halte dagegen.",
    "Truebes Wasser schluckt die Reichweite. Lass sie naeher kommen.",
    "Das Leuchtorgan setzt aus. Zaehle die Pausen mit.",
    "Nur die Mitte des Kegels brennt noch. Ziele genau.",
    "Alles zugleich - und die Stroemung steht quer.",
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
