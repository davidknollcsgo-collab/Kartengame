class_name Figuren
extends RefCounted

## **Die Figuren, Pixel fuer Pixel.**
##
## Jede Zeile ist eine Bildzeile, jedes Zeichen eine **Rolle** (siehe
## `Pixel.kleid`): `.` leer, `a/b/c/d` Rock hell bis tief in der Farbe der
## Sorte, `h/H` Hose, `f/F` Stiefel, `s/S` Haut, `m/M/n` Stahl, `w/W` Holz,
## `l/L` Leder, `e`/`o` dunkel (Auge, Schlitz, Kante), `x` Weiss, `u/U`
## Umhang, `q` Glanz des Helden, `y` helles Fell. Alle Figuren schauen nach
## **rechts**; links ist gespiegelt.
##
## Kein aeusserer Umriss: den zieht der Shader (`umriss.gdshader`) um jede
## Figur. Innen steht `o`/`n`, wo zwei Teile sich trennen muessen.
##
## **Masse**: ein Bildpunkt sind 3,75 Punkte des Feldes (`Pixel.P`). Die
## halbe Breite einer Sorte ist ihr `Feinde.ABSTAND` - was die Simulation
## fuer breit haelt, zeichnet das Bild auch so (Zusicherung 23).

# --- Beine: ein Laufzyklus fuer alle Zweibeiner ----------------------------

## Elf breit, die Huefte in den Spalten 3 bis 8, die Fussmitte in Spalte 5.
const BEIN_STEH: PackedStringArray = [
    "...hhhhhh..",
    "...hhhhhh..",
    "...HHh.hh..",
    "...HH..hh..",
    "...HH..hh..",
    "...HH..hh..",
    "...FF..ff..",
    "..FFF..fff.",
]
const BEIN_WEIT: PackedStringArray = [
    "...hhhhhh..",
    "...hhhhhh..",
    "..HHH..hhh.",
    "..HH....hh.",
    ".HH.....hh.",
    ".HH......hh",
    ".FF......ff",
    "FFF......ff",
]
const BEIN_ZUG: PackedStringArray = [
    "...hhhhhh..",
    "...hhhhhh..",
    "...hhhHH...",
    "...hh.HH...",
    "...hh..HH..",
    "...hh..FF..",
    "...hh......",
    "...ffff....",
]
const BEIN_ANKER := 5

# --- Oberkoerper der Sorten ------------------------------------------------

const STROLCH: PackedStringArray = [
    "....cbbb....",
    "...cbbbba...",
    "..cbbbbbaa..",
    "..cbSSssse..",
    "..cbSsssss..",
    "..ccbSsss...",
    "...cbbbbb...",
    "..cbbaaabbs.",
    ".cbbaaaabbsm",
    ".cbbaabbb.mm",
    ".cbbbbbbb...",
    "..lLlllll...",
    "..cbbbbbbb..",
]

const SPIESSER: PackedStringArray = [
    "..........m.",
    ".........mmm",
    "..........M.",
    "..........w.",
    "..........w.",
    "..........w.",
    "...nMMMMn.w.",
    "..nMmmMMMMnw",
    "....SSsss.w.",
    "....Sssse.w.",
    ".....SSs..w.",
    "...cbbbbbsw.",
    "..cbbaabbbw.",
    "..cbaaabbbw.",
    "..cbbbbbbbw.",
    "..lLlllllLw.",
    "..cbbbbbbbw.",
    "..ccbbbbbcw.",
]

const ARMBRUSTER: PackedStringArray = [
    "...cccc......",
    "..cdddddd....",
    "...SSssse....",
    "...SSssss....",
    "....SSss.....",
    "...cbbbbb....",
    "..cbaaabbb..M",
    "..cbaabbbsWWM",
    "..cbbaabbb..M",
    "..cbbbbbbb...",
    "..lLllllll...",
    "..cbbbbbbb...",
    "..ccbbbbbc...",
]

const TREIBER: PackedStringArray = [
    ".........w.....",
    ".........wbbbbb",
    ".........wbaxab",
    ".........wbxxxb",
    ".........wbaxab",
    ".........wbbbbc",
    ".........wcbc..",
    ".........wc.c..",
    "...cbbb..w.....",
    "..cbbbba.w.....",
    "..cbSsse.w.....",
    "..cbSsss.w.....",
    "...cSss..w.....",
    "..cbbbbbsw.....",
    ".cbbaabbbw.....",
    ".cbaabbbbw.....",
    ".cbbbbbbbw.....",
    ".clLllllLw.....",
    ".cbbbbbbbw.....",
    ".ccbbbbbbw.....",
]

const RITTER: PackedStringArray = [
    "...nMMMn....",
    "..nMmmmMn...",
    "..nMmmmMn...",
    "..nMooooo...",
    "..nMMmMMn...",
    "...nMMMn....",
    ".mMcbbbcnmMn",
    "mMcbbabbnbab",
    ".ncbbabbnbxb",
    ".ncbbbbbnxxx",
    "..cbbbbbnbxb",
    "..lLlllLnbxb",
    "..cbbbbb.nbn",
    "..ccbbbc..n.",
]

## **Der Warlord**: fast doppelt so gross, dunkle Platte, Hoernerhelm,
## Umhang und ein Zweihaender. Er hat eigene, doppelt breite Beine
## (`gross()` der gemeinsamen).
const WARLORD: PackedStringArray = [
    "....x..........x......",
    "....xx........xx......",
    ".....xx......xx.......",
    "......xnnnnnnx........",
    ".....nnMMMMMMnn.......",
    ".....nMmmmmMMMn.......",
    ".....nMmmmmMMMn.......",
    ".....nMoooooooo.......",
    ".....nMMMmMMMMn.......",
    ".....nnMMMMMMnn.......",
    "......nnnnnnnn........",
    "...ddcnMMMMMMnc...m...",
    "..ddcnMmMMMMMMnc..m...",
    ".ddcnMmmMbbbMMMnc.m...",
    ".ddcnMmMbbabbMMnc.m...",
    "dddcnMMMbbabbMMns.m...",
    "ddccnMMMbbbbbMMnsMmM..",
    "ddccnnMMbbbbbMMnn.n...",
    "ddcc.nnMMMMMMMnn..n...",
    "ddcc.lLllllllLl.......",
    "dddc.cbbbbbbbbbc......",
    "dddc.cbbbbbbbbbc......",
    ".ddd.ccbbbbbbbcc......",
    "..dd..cbbbbbbbc.......",
]
const WARLORD_ANKER := 11

# --- Die Helden ------------------------------------------------------------
#
# Ohne den vorderen Arm: Arm und Waffe zeichnet `zug_lauf` als Pixellinie in
# die Richtung, in die gerechnet wurde - ein gedrehtes Pixelbild zerfiele.
# `b` ist das Gewand (Skin), `q` sein Glanz, `u/U` der Umhang.

const HELD_SCHWERT: PackedStringArray = [
    ".....qqq.....",
    "....nMMMq....",
    "...nMmmMMn...",
    "...nMmmMMn...",
    "...nMoooo....",
    "...nMMMMMn...",
    "....nMMMn....",
    ".uuUcbbbbc...",
    "uuUcbaabbbc..",
    "uuUcbaabnMMn.",
    "uUUcbbbnMbbMn",
    "uUUcbbbnbqqbn",
    "uUUclLlnMbbMn",
    "uUU.cbbbnMMn.",
    ".UU.cbbbb....",
    "..U.ccbbc....",
]
const HELD_BOGEN: PackedStringArray = [
    "....cbbb.....",
    "...cbbbba....",
    "..cbbSsse....",
    "..cbbSsss....",
    "..ccbbSs.....",
    ".x.cbbbbb....",
    ".xlcbaabbb...",
    ".llcbaabbbc..",
    "ullcbbabbb...",
    "uUlcbbbbbb...",
    "uUlcbbbbbb...",
    "uUUclLllll...",
    "uUU.cbbbbb...",
    ".UU.cbbbbb...",
    "..U.ccbbbc...",
]
const HELD_SPEER: PackedStringArray = [
    "....lLll.....",
    "...lllllL....",
    "..LLLLLLLL...",
    "...SSssse....",
    "...SSssss....",
    "....SSss.....",
    ".uuUcbbbb....",
    "uuUcbaabbb...",
    "uUUcbaabbb...",
    "uUUcbbabbb...",
    "uUUcbbbbbb...",
    "uUUclLllll...",
    "uUU.cbbbbb...",
    ".UU.cbbbbb...",
    "..U.ccbbbc...",
]
const HELD_HAMMER: PackedStringArray = [
    "...nMMMMMn....",
    "..nMmmmMMMn...",
    "..nMmmqMMMn...",
    "..nMoooooon...",
    "..nMMMqMMMn...",
    "...nnMMMnn....",
    ".uuUcbbbbbc...",
    "uuUcbbaabbbc..",
    "uUUcbaaabbbbc.",
    "uUUcbaabbbbbc.",
    "uUUcbbbbbbbbc.",
    "uUUclLlllllLc.",
    "uUU.cbbbbbbb..",
    ".UU.cbbbbbbb..",
    "..U.ccbbbbbc..",
]
## Wo die Schulter des vorderen Arms sitzt, vom Fuss aus in Bildpunkten.
const HELD_SCHULTER := Vector2i(2, -15)

## **Der Gefaehrte**: kleiner, Nasalhelm, kein Umhang - er traegt deine
## Farben und ist doch sichtbar nicht du (Zusicherung 10).
const GEFAEHRTE: PackedStringArray = [
    "...nMMn..",
    "..nMmMMn.",
    "..nMMnSo.",
    "..nMSse..",
    "...SSs...",
    "..cbbbbs.",
    ".cbaabbs.",
    ".cbbbbb..",
    ".clLlll..",
    ".cbbbbb..",
]
const GEFAEHRTE_BEINE: Array[PackedStringArray] = [
    [
        "..hhhh.",
        "..Hh.h.",
        "..H..h.",
        "..F..f.",
        ".FF..ff",
    ],
    [
        "..hhhh.",
        ".HH..hh",
        ".H....h",
        "FF....f",
        "F.....f",
    ],
]
const GEFAEHRTE_ANKER := 3
const GEFAEHRTE_HAND := Vector2i(3, -9)

## Der Wolf: kein Zweibeiner, eigener Galopp in vier Bildern.
const WOLF: Array[PackedStringArray] = [
    [
        "..........c.c",
        ".........cbcb",
        "c.......cbbbb",
        ".c.aaaaabbeby",
        "..bbbbbbbbbyo",
        "..bbbbbbbbb..",
        "..cyyyyyybc..",
        ".cc......cb..",
        "cc........cb.",
        "c..........c.",
    ],
    [
        "..........c.c",
        ".........cbcb",
        "c.......cbbbb",
        ".c.aaaaabbeby",
        "..bbbbbbbbbyo",
        "..bbbbbbbbb..",
        "..cyyyyyybc..",
        "...cc...cb...",
        "...cc...cb...",
        "....c....c...",
    ],
    [
        "..........c.c",
        ".........cbcb",
        "........cbbbb",
        "c..aaaaabbeby",
        ".cbbbbbbbbbyo",
        "..bbbbbbbbb..",
        "..cyyyyyybc..",
        "...cc...cc...",
        "....cc.cc....",
        ".....c.c.....",
    ],
    [
        "..........c.c",
        ".........cbcb",
        "c.......cbbbb",
        ".c.aaaaabbeby",
        "..bbbbbbbbbyo",
        "..bbbbbbbbb..",
        "..cyyyyyybc..",
        "..cc.....cb..",
        "..c.......c..",
        "..c........c.",
    ],
]
const WOLF_ANKER := 6


# --- Zusammensetzen --------------------------------------------------------

## Tauscht vordere und hintere Seite eines Beinbilds: aus dem ausgreifenden
## Schritt mit dem rechten Bein wird der mit dem linken.
static func _tausche(zeilen: PackedStringArray) -> PackedStringArray:
    var aus := PackedStringArray()
    for z in zeilen:
        var n := ""
        for ch in z:
            match ch:
                "h": n += "H"
                "H": n += "h"
                "f": n += "F"
                "F": n += "f"
                _: n += ch
        aus.append(n)
    return aus


## Die vier Laufbilder und das Stehen.
static func beine(bild: int) -> PackedStringArray:
    match bild:
        0: return BEIN_WEIT
        1: return BEIN_ZUG
        2: return _tausche(BEIN_WEIT)
        3: return _tausche(BEIN_ZUG)
    return BEIN_STEH


## **Oberkoerper auf Beine.** Die Huefte des Oberkoerpers steht ueber der
## Huefte der Beine; was breiter ist, wird aufgefuellt. `stange` fuehrt eine
## Stange (Pike, Fahne) durch die Beine bis zum Boden.
static func stapel(oben: PackedStringArray, unten: PackedStringArray,
        stange := -1) -> PackedStringArray:
    var breit := 0
    for z in oben:
        breit = maxi(breit, z.length())
    for z in unten:
        breit = maxi(breit, z.length())
    var aus := PackedStringArray()
    for z in oben:
        aus.append(z.rpad(breit, "."))
    for i in unten.size():
        var z: String = unten[i].rpad(breit, ".")
        if stange >= 0 and stange < breit and z[stange] == "." and i < unten.size() - 1:
            z = z.substr(0, stange) + "w" + z.substr(stange + 1)
        aus.append(z)
    return aus


## Verdoppelt ein Bild in beide Richtungen.
static func gross(zeilen: PackedStringArray) -> PackedStringArray:
    var aus := PackedStringArray()
    for z in zeilen:
        var n := ""
        for ch in z:
            n += ch + ch
        aus.append(n)
        aus.append(n)
    return aus


## **Liegend**: das stehende Bild um eine Vierteldrehung, Kopf nach vorn.
## Eine Drehung um 90 Grad ist im Raster verlustfrei - jede andere nicht.
static func liegend(zeilen: PackedStringArray) -> PackedStringArray:
    var h := zeilen.size()
    var w := 0
    for z in zeilen:
        w = maxi(w, z.length())
    var aus := PackedStringArray()
    for x in w:
        var n := ""
        for y in range(h - 1, -1, -1):
            var z: String = zeilen[y]
            n += z[x] if x < z.length() else "."
        aus.append(n)
    # Gedreht steht der Kopf oben rechts; gelegt wird er nach unten.
    var gekippt := PackedStringArray()
    for i in range(aus.size() - 1, -1, -1):
        gekippt.append(aus[i])
    return _ohne_leere(gekippt)


static func _ohne_leere(zeilen: PackedStringArray) -> PackedStringArray:
    var aus := PackedStringArray()
    for z in zeilen:
        if z.replace(".", "") != "":
            aus.append(z)
    return aus


static func held(klasse: int, bild: int) -> PackedStringArray:
    var oben: PackedStringArray = [HELD_SCHWERT, HELD_BOGEN, HELD_SPEER,
        HELD_HAMMER][clampi(klasse, 0, 3)]
    return stapel(oben, beine(bild))


static func gefaehrte(bild: int) -> PackedStringArray:
    return stapel(GEFAEHRTE, GEFAEHRTE_BEINE[posmod(bild, 2)])


## Ein Schatten unter der Figur: eine flache Ellipse, `breite` Bildpunkte.
static func schatten(breite: int) -> PackedStringArray:
    var hoch := maxi(2, breite / 4)
    var aus := PackedStringArray()
    for y in hoch:
        var t := (float(y) + 0.5) / float(hoch) * 2.0 - 1.0
        var halb := int(round(float(breite) * 0.5 * sqrt(maxf(0.0, 1.0 - t * t))))
        var n := ""
        for x in breite:
            n += "~" if absi(x - breite / 2) < halb else "."
        aus.append(n)
    return aus


## Das ganze Bild einer Sorte in einem Laufbild (`bild` 0..3, -1 steht).
static func feind(art: int, bild: int) -> PackedStringArray:
    match art:
        Feinde.Art.WOLF:
            return WOLF[posmod(bild, 4)]
        Feinde.Art.SPIESSER:
            return stapel(SPIESSER, beine(bild), 10)
        Feinde.Art.ARMBRUSTER:
            return stapel(ARMBRUSTER, beine(bild))
        Feinde.Art.TREIBER:
            return stapel(TREIBER, beine(bild), 9)
        Feinde.Art.RITTER:
            return stapel(RITTER, beine(bild))
        Feinde.Art.WARLORD:
            return stapel(WARLORD, gross(beine(bild)))
    return stapel(STROLCH, beine(bild))


static func anker(art: int) -> int:
    if art == Feinde.Art.WOLF:
        return WOLF_ANKER
    if art == Feinde.Art.WARLORD:
        return WARLORD_ANKER
    return BEIN_ANKER
