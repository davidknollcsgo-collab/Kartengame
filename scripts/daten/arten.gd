class_name Arten
extends RefCounted

## Die Raeuber des Grabens.
##
## Erfundene Tiere, keine Vorlage. Die Namen sind deutsche Wortbildungen nach
## dem Muster echter Tiefseefauna - Aussehen und Werte stammen aus diesem
## Projekt. Gezeichnet wird jede Art im Code, es gibt keine Bilddateien.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Art {
    ZAHNKIEFER,     ## Grundgegner. Sinkt gerade, stirbt schnell.
    SCHLEIER,       ## Schwarmtier. Sehr schnell, fast kein Leben.
    PANZERKREBS,    ## Traeger Brocken. Zwingt zum Verweilen im Ziel.
    GRABNATTER,     ## Schlaengelt breit - schwer im Kegel zu halten.
    SCHILDKORALLE,  ## Panzer: schwache Quellen kommen gar nicht durch.
    GLUTQUALLE,     ## Brennt nur im Kern des Kegels, nicht am Rand.
    TREIBANKER,     ## Wandert quer durchs Bild, waehrend er sinkt.
    SPRUNGAAL,      ## Sinkt in Schueben - der Kegel laeuft ihm nach.
}

## --- Was die vier spaeten Arten anders machen ---
##
## Bis Welle 10 stand das ganze Bestiarium; danach kamen fuenfzig Wellen lang
## dieselben vier Tiere mit mehr Leben. Mehr Leben ist keine Tiefe, sondern
## eine groessere Zahl.
##
## Die vier Neuen aendern deshalb nicht die Zahl, sondern **wo der Kegel
## stehen muss**:
##
##   * Panzer zieht einen festen Betrag je Sekunde ab. Ein Wehrpolyp mit neun
##     Schaden kratzt an einer Schildkoralle mit Panzer sieben kaum noch - man
##     muss selbst hin.
##   * Mindesthelligkeit verlangt den Kern des Kegels. Wer die Glutqualle am
##     Rand mitlaufen laesst, tut ihr nichts.
##   * Querdrift traegt den Treibanker durchs Bild. Er verlaesst den Kegel von
##     selbst, auch wenn man stillhaelt.
##   * Schub laesst den Sprungaal ruckweise sinken - die Nachfuehrung, die bei
##     allen anderen sitzt, geht bei ihm daneben.

## Reihenfolge entspricht `Art`. Auf einen Wert je Feld verzichtet, weil eine
## Tabelle die Balance an einer Stelle sichtbar macht.
const TABELLE: Array[Dictionary] = [
    {
        &"name": "Zahnkiefer",
        &"regel": "Sinkt gerade und stirbt schnell. Der Massstab fuer alles andere.",
        &"leben": 22.0,
        &"tempo": 92.0,
        &"radius": 17.0,
        &"wert": 3,
        &"wucht": 1,
        &"schlaengel": 14.0,
        &"takt": 1.7,
        &"farbe": Color(0.62, 0.86, 0.95),
        &"ab_welle": 1,
    },
    {
        &"name": "Schleier",
        &"regel": "Kommt im Schwarm und ist sehr schnell. Einzeln fast nichts wert.",
        &"leben": 8.0,
        &"tempo": 168.0,
        &"radius": 12.0,
        &"wert": 2,
        &"wucht": 1,
        &"schlaengel": 26.0,
        &"takt": 3.1,
        &"farbe": Color(0.72, 0.62, 0.98),
        &"ab_welle": 3,
    },
    {
        &"name": "Panzerkrebs",
        &"regel": "Traege und zaeh. Zwingt den Kegel zum Verweilen.",
        &"leben": 74.0,
        &"tempo": 54.0,
        &"radius": 25.0,
        &"wert": 8,
        &"wucht": 3,
        &"schlaengel": 6.0,
        &"takt": 0.9,
        &"farbe": Color(0.98, 0.68, 0.42),
        &"ab_welle": 6,
    },
    {
        &"name": "Grabnatter",
        &"regel": "Schlaengelt breit aus. Wer nachfuehrt, verliert sie; wer vorhaelt, trifft.",
        &"leben": 34.0,
        &"tempo": 104.0,
        &"radius": 15.0,
        &"wert": 5,
        &"wucht": 2,
        &"schlaengel": 82.0,
        &"takt": 2.2,
        &"farbe": Color(0.55, 0.98, 0.72),
        &"ab_welle": 10,
    },
    {
        &"name": "Schildkoralle",
        &"regel": "Panzer: ein fester Betrag geht je Sekunde ab. Wehrpolypen kratzen nur.",
        &"leben": 58.0,
        &"tempo": 44.0,
        &"radius": 24.0,
        &"wert": 11,
        &"wucht": 3,
        &"schlaengel": 5.0,
        &"takt": 0.6,
        &"farbe": Color(0.46, 0.90, 0.86),
        &"ab_welle": 16,
        &"panzer": 7.0,
        &"aufwand": 1.60,
    },
    {
        &"name": "Glutqualle",
        &"regel": "Brennt nur im Kern des Kegels. Am Rand mitlaufen lassen nuetzt nichts.",
        &"leben": 38.0,
        &"tempo": 60.0,
        &"radius": 21.0,
        &"wert": 9,
        &"wucht": 2,
        &"schlaengel": 20.0,
        &"takt": 1.0,
        &"farbe": Color(1.00, 0.56, 0.62),
        &"ab_welle": 24,
        &"mindest_licht": 0.52,
        &"aufwand": 1.45,
    },
    {
        &"name": "Treibanker",
        &"regel": "Wandert quer durchs Bild. Verlaesst den Kegel, auch wenn man stillhaelt.",
        &"leben": 44.0,
        &"tempo": 56.0,
        &"radius": 19.0,
        &"wert": 9,
        &"wucht": 2,
        &"schlaengel": 9.0,
        &"takt": 1.3,
        &"farbe": Color(0.86, 0.82, 0.52),
        &"ab_welle": 32,
        &"drift": 27.0,
        &"aufwand": 1.30,
    },
    {
        &"name": "Sprungaal",
        &"regel": "Sinkt in Schueben. Die gewohnte Nachfuehrung geht bei ihm daneben.",
        &"leben": 28.0,
        &"tempo": 118.0,
        &"radius": 14.0,
        &"wert": 7,
        &"wucht": 2,
        &"schlaengel": 28.0,
        &"takt": 2.6,
        &"farbe": Color(0.60, 0.72, 1.00),
        &"ab_welle": 42,
        &"stoss": 0.85,
        &"aufwand": 1.22,
    },
]


static func zahl() -> int:
    return TABELLE.size()


static func art(index: int) -> Dictionary:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)]


static func leben(index: int) -> float:
    return art(index)[&"leben"]


static func tempo(index: int) -> float:
    return art(index)[&"tempo"]


static func radius(index: int) -> float:
    return art(index)[&"radius"]


static func wert(index: int) -> int:
    return art(index)[&"wert"]


static func wucht(index: int) -> int:
    return art(index)[&"wucht"]


static func farbe(index: int) -> Color:
    return art(index)[&"farbe"]


static func name_von(index: int) -> String:
    return art(index)[&"name"]


## Ein Satz, der sagt, was diese Art vom Spieler verlangt.
##
## Steht im Bestiarium und in der Ankuendigung beim ersten Auftreten. Eine
## Regel, die man sich erspielen muss, ist bei einem Gegner, der nach vierzig
## Sekunden bei der Brut ist, keine Regel, sondern eine Falle.
static func regel(index: int) -> String:
    return String(art(index).get(&"regel", ""))


# --- Die vier Eigenschaften der spaeten Arten ------------------------------
#
# Alle mit Standardwert, damit ein Eintrag nur schreiben muss, was er wirklich
# anders macht. Eine Tabelle, in der jede Zeile jedes Feld nennt, verbirgt
# genau das Besondere, das man sehen will.

static func panzer(index: int) -> float:
    return float(art(index).get(&"panzer", 0.0))


static func mindest_licht(index: int) -> float:
    return float(art(index).get(&"mindest_licht", 0.0))


static func drift(index: int) -> float:
    return float(art(index).get(&"drift", 0.0))


static func stoss(index: int) -> float:
    return float(art(index).get(&"stoss", 0.0))


## Wieviel schwerer eine Art ist, als ihre Lebenspunkte sagen.
##
## **Gemessen, nicht hergeleitet.** Panzer, Mindesthelligkeit, Drift und Schub
## kosten Zeit am Kegel, und Zeit laesst sich nicht in Lebenspunkte umrechnen,
## ohne den Spieler nachzubauen. Die Zahl steht deshalb so, dass der
## Wellenpruefer alle 60 Wellen traegt - wer sie aendert, muss ihn neu laufen
## lassen. `Wellen.auftritte()` rechnet mit ihr das Budget einer Welle ab;
## `leben_in()` bleibt davon unberuehrt, sonst waere die Anzeige falsch.
static func aufwand(index: int) -> float:
    return maxf(0.1, float(art(index).get(&"aufwand", 1.0)))


## Welche Arten in Welle `nummer` ueberhaupt auftreten duerfen.
static func verfuegbar(nummer: int) -> PackedInt32Array:
    var liste := PackedInt32Array()
    for i in TABELLE.size():
        if nummer >= int(TABELLE[i][&"ab_welle"]):
            liste.append(i)
    return liste
