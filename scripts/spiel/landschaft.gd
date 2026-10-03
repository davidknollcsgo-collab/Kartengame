class_name Landschaft
extends RefCounted

## **Was auf dem Boden steht, als Pixel-Sprites.**
##
## Bis Oktober 2026 zeichnete `feld.gd` Baeume, Buesche und Steine mit
## `Tusche`: weiche Kleckse mit durchsichtigem Rand, im Pixelbild ein
## verwaschener Fleck neben scharfen Soldaten. Jetzt sind es Sprites wie die
## Figuren - dieselben Rollen (`Pixel`), derselbe Atlas.
##
## **Kronen und Steine werden gerechnet, nicht gemalt.** Eine Krone ist eine
## Vereinigung von Kreisen, jeder Kreis von links oben beleuchtet
## (`Palette.LICHT`) - so hat sie Bauschen und nicht eine Flaeche. Daraus
## entstehen Zeilen aus Rollen, und die gehen denselben Weg wie jede Figur.
## Gesaet mit fester Zahl: dieselbe Sorte Baum sieht in jedem Lauf gleich aus.
##
## **Die Kante ist halb so dunkel wie die einer Figur.** Eine volle Kante
## waere eine Figur; der Boden soll hinter der Horde liegen, nicht in ihr.

## Wie viele Fassungen je Sorte gerechnet werden.
const BAEUME := 4
const KIEFERN := 2
const BUESCHE := 3
const STEINE := 3

## Die Rollen der Landschaft. `o` ist die Kante, je Ding eigens gesetzt.
static func kleid(kante: Color) -> Dictionary:
    var k := Pixel.grund()
    k["o"] = kante
    k["1"] = Palette.LAUB.lightened(0.24)
    k["2"] = Palette.LAUB
    k["3"] = Palette.LAUB_TIEF
    k["4"] = Palette.LAUB_TIEF.darkened(0.28)
    k["5"] = Palette.HOLZ.lightened(0.12)
    k["6"] = Palette.HOLZ.darkened(0.28)
    k["7"] = Palette.STEIN.lightened(0.22)
    k["8"] = Palette.STEIN
    k["9"] = Palette.STEIN.darkened(0.22)
    k["0"] = Palette.STEIN.darkened(0.48)
    k["t"] = Palette.HOLZ_HELL.lightened(0.30)
    k["T"] = Palette.HOLZ_HELL
    k["h"] = Palette.HALM
    k["H"] = Palette.WIESE.lightened(0.16)
    k["p"] = Palette.BLUETE
    k["P"] = Palette.BLUETE_ZART
    return k


static func kante_laub() -> Color:
    return Palette.LAUB_TIEF.darkened(0.55)


static func kante_stein() -> Color:
    return Palette.STEIN.darkened(0.62)


static func kante_holz() -> Color:
    return Palette.HOLZ.darkened(0.55)


# --- Gerechnet -------------------------------------------------------------

## Eine Rolle aus dem Licht eines Kreises: `n` ist der Ort im Kreis, von -1
## bis 1. Zugewandt hell, abgewandt dunkel, mit etwas Rauschen, damit die
## Grenze zwischen zwei Toenen ausfranst wie Laub und nicht wie ein Zirkel.
static func _ton(n: Vector2, rauschen: float, hell: String) -> String:
    var l := -n.dot(Palette.LICHT) * 0.85 + rauschen
    if l > 0.38:
        return hell[0]
    if l > -0.05:
        return hell[1]
    if l > -0.50:
        return hell[2]
    return hell[3]


## **Eine Krone aus Bauschen**: `breite` x `hoehe` Bildpunkte. Die hinteren
## Bauschen zuerst, die vorderen darueber; ein Punkt nimmt das Licht des
## vordersten Bauschs, der ihn deckt.
static func _krone(rng: RandomNumberGenerator, breite: int, hoehe: int,
        bausche: int) -> Array:
    var kreise: Array = []
    var mitte := Vector2(breite * 0.5, hoehe * 0.52)
    # Hinten und oben, dann die Seiten, zuletzt vorn unten.
    for i in bausche:
        var w := PI * (1.05 + float(i) / float(maxi(1, bausche - 1)) * 0.9)
        var r := float(breite) * (0.22 + rng.randf() * 0.07)
        var o := mitte + Vector2(cos(w) * breite * 0.24, sin(w) * hoehe * 0.20)
        kreise.append([o, r])
    for i in 2:
        var o := mitte + Vector2((float(i) - 0.5) * breite * 0.34,
            hoehe * 0.14 + rng.randf() * 1.5)
        kreise.append([o, float(breite) * (0.24 + rng.randf() * 0.05)])
    kreise.append([mitte + Vector2(-breite * 0.06, -hoehe * 0.06),
        float(breite) * 0.30])
    var zeilen: Array = []
    for y in hoehe:
        var z := ""
        for x in breite:
            var p := Vector2(x + 0.5, y + 0.5)
            var rolle := "."
            for k in kreise:
                var o: Vector2 = k[0]
                var r: float = k[1]
                var d := (p - o) / Vector2(r, r * 0.86)
                if d.length() <= 1.0:
                    # Unten liegt die Krone im eigenen Schatten.
                    var tief := clampf((p.y - mitte.y) / float(hoehe) * 0.9, 0.0, 0.5)
                    rolle = _ton(d, (rng.randf() - 0.5) * 0.30 - tief, "1234")
            z += rolle
        zeilen.append(z)
    return zeilen


## **Ein Laubbaum**: Krone aus Bauschen, darunter der Stamm mit Lichtkante.
static func baum(nummer: int) -> PackedStringArray:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7001 + nummer * 31
    var breite := baum_breite(nummer)
    var hoehe := 20 + (nummer % 2) * 3
    var krone := _krone(rng, breite, hoehe, 5 + nummer % 2)
    var stamm := 5 + nummer % 2
    var mitte := breite / 2
    var zeilen := PackedStringArray()
    for z in krone:
        zeilen.append(z)
    # Der Stamm ragt unten aus der Krone: die letzten Kronenzeilen bekommen
    # ihn dort, wo sie leer sind.
    for y in range(zeilen.size() - 3, zeilen.size()):
        var z: String = zeilen[y]
        for x in [mitte - 1, mitte, mitte + 1]:
            if z[x] == ".":
                z = z.substr(0, x) + ("6" if x > mitte else "5") + z.substr(x + 1)
        zeilen[y] = z
    for i in stamm:
        var z := ""
        for x in breite:
            if x == mitte - 1 or x == mitte:
                z += "5"
            elif x == mitte + 1:
                z += "6"
            elif i == stamm - 1 and (x == mitte - 2 or x == mitte + 2):
                # Wurzelanlauf.
                z += "5" if x < mitte else "6"
            else:
                z += "."
        zeilen.append(z)
    return zeilen


static func baum_breite(nummer: int) -> int:
    return 24 + (nummer % 3) * 3


static func baum_anker(nummer: int) -> int:
    return baum_breite(nummer) / 2


## **Eine Kiefer**: drei Etagen, jede ein Dreieck, links im Licht.
static func kiefer(nummer: int) -> PackedStringArray:
    var rng := RandomNumberGenerator.new()
    rng.seed = 9101 + nummer * 17
    var breite := kiefer_breite(nummer)
    var mitte := breite / 2
    var zeilen := PackedStringArray()
    var etagen := 3
    for e in etagen:
        var hoch := 6 + e
        for y in hoch:
            var halb := 1 + int(float(y + 1) / float(hoch) * (3.2 + float(e) * 2.6))
            halb = mini(halb, mitte)
            var z := ""
            for x in breite:
                var dx := x - mitte
                if absi(dx) > halb:
                    z += "."
                    continue
                var rolle := "3"
                if dx < -halb * 0.4:
                    rolle = "2"
                if dx < -halb * 0.6 and y < hoch - 1 and rng.randf() < 0.6:
                    rolle = "1"
                if dx > halb * 0.45:
                    rolle = "4"
                if y == hoch - 1:
                    rolle = "4" if dx > -halb * 0.5 else "3"
                z += rolle
            zeilen.append(z)
    for i in 4:
        var z := ""
        for x in breite:
            z += "5" if x == mitte else ("6" if x == mitte + 1 else ".")
        zeilen.append(z)
    return zeilen


static func kiefer_breite(nummer: int) -> int:
    return 19 + nummer * 2


static func kiefer_anker(nummer: int) -> int:
    return kiefer_breite(nummer) / 2


## Ein Busch: eine flache Krone ohne Stamm, mal mit Blueten.
static func busch(nummer: int) -> PackedStringArray:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4401 + nummer * 13
    var breite := 13 + nummer * 2
    var zeilen := _krone(rng, breite, 9 + nummer % 2, 3)
    var aus := PackedStringArray()
    for y in zeilen.size():
        var z: String = zeilen[y]
        if nummer == 1 and y > 0 and y < 4:
            for x in z.length():
                if z[x] == "2" and rng.randf() < 0.18:
                    z = z.substr(0, x) + "p" + z.substr(x + 1)
        aus.append(z)
    return aus


static func busch_anker(nummer: int) -> int:
    return (13 + nummer * 2) / 2


## **Eine Steingruppe**: zwei, drei flache Rundungen, die groesste hinten,
## jede im Licht von links oben, unten ein dunkler Saum, wo sie aufliegt.
static func stein(nummer: int) -> PackedStringArray:
    var rng := RandomNumberGenerator.new()
    rng.seed = 3301 + nummer * 19
    var breite := 10 + nummer * 3
    var hoehe := 6 + nummer
    var brocken: Array = []
    brocken.append([Vector2(breite * 0.45, hoehe * 0.55), Vector2(breite * 0.36, hoehe * 0.55)])
    if nummer > 0:
        brocken.append([Vector2(breite * 0.78, hoehe * 0.72),
            Vector2(breite * 0.20, hoehe * 0.36)])
    if nummer > 1:
        brocken.append([Vector2(breite * 0.16, hoehe * 0.80),
            Vector2(breite * 0.14, hoehe * 0.26)])
    var zeilen := PackedStringArray()
    for y in hoehe:
        var z := ""
        for x in breite:
            var p := Vector2(x + 0.5, y + 0.5)
            var rolle := "."
            for b in brocken:
                var d := (p - (b[0] as Vector2)) / (b[1] as Vector2)
                if d.length() <= 1.0:
                    rolle = _ton(d, (rng.randf() - 0.5) * 0.2, "7889")
                    if d.y > 0.72:
                        rolle = "9"
            z += rolle
        zeilen.append(z)
    # Ein Riss im grossen Stein.
    var rx := int(breite * 0.42)
    for y in range(1, mini(hoehe - 1, 4)):
        var z: String = zeilen[y]
        var x := rx + (y % 2)
        if z[x] != ".":
            zeilen[y] = z.substr(0, x) + "0" + z.substr(x + 1)
    return zeilen


static func stein_anker(nummer: int) -> int:
    return (10 + nummer * 3) / 2


## **Ein Mauerstueck**: Bloecke im Verband, nach rechts eingebrochen, oben
## Zinnen. Jeder Block hat oben links Licht und unten Fuge.
static func mauer() -> PackedStringArray:
    var breite := 26
    var hoehe := 16
    var zeilen := PackedStringArray()
    for y in hoehe:
        var z := ""
        for x in breite:
            # Die Krone faellt nach rechts ab; vorn liegen Truemmer.
            var oben := 2 + int(float(x) * 0.42)
            var zinne := x < 14 and (x / 3) % 2 == 0
            if zinne:
                oben -= 2
            if y < oben:
                z += "."
                continue
            var reihe := y / 3
            var versatz := 2 if reihe % 2 == 1 else 0
            var bx := (x + versatz) % 5
            var by := y % 3
            if by == 2 or bx == 4:
                z += "9"
            elif by == 0 and bx == 0:
                z += "7"
            elif bx == 3:
                z += "9" if y % 2 == 0 else "8"
            else:
                z += "8"
        zeilen.append(z)
    return zeilen


## **Ein Turmstumpf**: rund, oben offen. Licht links, Schatten rechts - wie
## bei jeder Figur.
static func turm() -> PackedStringArray:
    var breite := 18
    var hoehe := 16
    var zeilen := PackedStringArray()
    var r := breite * 0.5
    for y in hoehe:
        var z := ""
        for x in breite:
            var dx := (float(x) + 0.5 - r) / r
            # Die Oeffnung oben: eine flache Ellipse.
            var oben := 3.0 * sqrt(maxf(0.0, 1.0 - dx * dx))
            if y < 3.0 - oben or absf(dx) > 1.0:
                z += "."
                continue
            if y < 3.0 + oben * 0.55 and absf(dx) < 0.72 and y > 3.0 - oben * 0.55:
                z += "0"
                continue
            if y < 3.0 + oben:
                z += "7" if dx < 0.0 else "8"
                continue
            var reihe := y / 3
            var bx := (x + (2 if reihe % 2 == 1 else 0)) % 5
            if y % 3 == 2 or bx == 4:
                z += "0" if dx > 0.5 else "9"
            elif dx < -0.4:
                z += "7"
            elif dx > 0.45:
                z += "9"
            else:
                z += "8"
        zeilen.append(z)
    return zeilen


# --- Nach Namen -------------------------------------------------------------

## **Was hoch steht**, verdeckt, was dahinter laeuft: diese Dinge zeichnet der
## Figurenpuffer, nach y sortiert mit der Horde, und nicht der Boden.
static func ist_hoch(name: String) -> bool:
    var art := name.split(":")[0]
    return art == "baum" or art == "kiefer" or art == "turm"


## **Was sich bewegt** (Gras, Schilf): zeichnet ein eigener Knoten jedes Bild
## neu, damit es sich im Wind wiegen kann. Der gemerkte Boden steht still.
static func ist_lebend(name: String) -> bool:
    var art := name.split(":")[0]
    return art == "gras" or art == "schilf"


## Zeilen, Ankerspalte, Kante und ob ein Umriss eingebrannt wird - je Name
## wie `"baum:2"`. Eine Stelle fuer Boden, Figurenpuffer und lebenden Boden.
static func bild_von(name: String) -> Array:
    var teile := name.split(":")
    var nr := int(teile[1]) if teile.size() > 1 else 0
    match teile[0]:
        "baum":
            return [baum(nr), baum_anker(nr), kante_laub(), true]
        "kiefer":
            return [kiefer(nr), kiefer_anker(nr), kante_laub(), true]
        "busch":
            return [busch(nr), busch_anker(nr), kante_laub(), true]
        "stein":
            return [stein(nr), stein_anker(nr), kante_stein(), true]
        "mauer":
            return [mauer(), 13, kante_stein(), true]
        "turm":
            return [turm(), 9, kante_stein(), true]
        "stumpf":
            return [STUMPF, 3, kante_holz(), true]
        "zaun":
            return [ZAUN, 9, kante_holz(), true]
        "gras":
            return [PackedStringArray(GRAS[nr]), 2, kante_laub(), false]
        "schilf":
            return [SCHILF, 2, kante_laub(), false]
        "kiesel":
            return [PackedStringArray(KIESEL[nr]), 1, kante_stein(), false]
    return [PackedStringArray(["."]), 0, kante_laub(), false]


## **Im Wind**: das obere `anteil` des Bildes einen Bildpunkt nach rechts.
## Rechts steht dafuer immer eine Spalte frei, damit beide Fassungen gleich
## breit sind und der Anker bleibt.
static func wiege(zeilen: PackedStringArray, ausschlag: bool,
        anteil := 0.45) -> PackedStringArray:
    var aus := PackedStringArray()
    var grenze := int(float(zeilen.size()) * anteil)
    for y in zeilen.size():
        var z: String = zeilen[y] + "."
        if ausschlag and y < grenze:
            z = "." + z.substr(0, z.length() - 1)
        aus.append(z)
    return aus


# --- Gemalt ----------------------------------------------------------------

const STUMPF: PackedStringArray = [
    "..ttt..",
    ".tTtTt.",
    ".5ttt6.",
    ".55566.",
    ".55566.",
    "5555666",
]

const ZAUN: PackedStringArray = [
    ".5.......5.......5.",
    ".56......56......56",
    "5555555555555555556",
    ".56......56......56",
    "5555555555555555556",
    ".56......56......56",
    ".56......56......56",
]

const GRAS: Array = [
    [".h.H.",
     "hH.hH",
     ".hHh."],
    ["..H..",
     "h.H.h",
     "hHhHh"],
    [".p...",
     ".h.Hp",
     "hHhh."],
    ["P..p.",
     "hP.hH",
     ".hHh."],
]

## Schilf am Ufer: hoch und duenn.
const SCHILF: PackedStringArray = [
    ".T...",
    ".h.T.",
    ".hHh.",
    "hHhH.",
    ".hHh.",
]

## Kiesel: winzig, zwei Toene.
const KIESEL: Array = [
    ["78", "99"],
    ["7.", "89"],
    [".78", "899"],
]
