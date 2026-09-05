class_name Mutationen
extends RefCounted

## Damit auch die Raeuber nicht ausgehen.
##
## Der Graben hat keinen Boden mehr - die Wellen laufen weiter, solange jemand
## spielt. Neun gezeichnete Arten laufen aber sehr wohl aus: wer die zweite
## Umdrehung beginnt, hat jede von ihnen hundertmal gesehen. Neue Arten
## nachzuzeichnen ist der teuerste denkbare Weg, mehr vom Gleichen zu
## erzeugen, und irgendwann ist auch er zu Ende.
##
## Stattdessen mutiert der Graben, was schon da ist. Eine Mutation ist ein
## Zug, den eine ganze Welle traegt: ihre Raeuber sind gepanzert, oder sie
## meiden Licht, oder sie treiben quer. Die Bausteine dafuer gibt es alle
## schon - `panzer`, `mindest_licht`, `drift`, `stoss` sind die vier
## Eigenschaften, mit denen die spaeten Arten gebaut sind. Sie auf eine
## fruehe Art zu legen, macht aus einem bekannten Tier ein neues Problem,
## ohne einen einzigen neuen Strich zu zeichnen.
##
## **Die erste Umdrehung bleibt frei davon.** Wer die Arten noch nicht kennt,
## kann nicht sehen, was an ihnen anders ist - eine Mutation waere dann keine
## Abwechslung, sondern eine unerklaerliche Niederlage.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Mutation {
    PANZERUNG,      ## Haut, die Licht abweist
    LICHTSCHEU,     ## nimmt erst ab einer Helligkeit ueberhaupt Schaden
    UNSTET,         ## treibt quer aus dem Kegel
    SCHUB,          ## stoesst sich stossweise vorwaerts
    HAST,           ## schlicht schneller
    AUFGEDUNSEN,    ## weniger, dafuer groesser und zaeher
}

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "Plated", "Lightshy", "Erratic", "Surging", "Swift", "Bloated",
]

## Ein Satz, der sagt, was zu tun ist. Steht im Wellenkopf, bevor es losgeht -
## eine Regel, die man sich erspielen muss, ist keine Regel, sondern eine
## Falle.
const HINWEISE: PackedStringArray = [
    "Their skin turns light aside. Hold the cone still.",
    "Dim light does nothing to them. Keep them in the core.",
    "They drift sideways out of the beam. Lead them.",
    "They surge forward in bursts. Do not follow, wait.",
    "Everything comes faster. Sweep less, hold longer.",
    "Fewer, larger, tougher. One at a time.",
]

## Ab der zweiten Umdrehung. Davor bleibt der Graben so, wie man ihn lernt.
const AB_ZYKLUS := 1

## Mehr als drei Zuege auf einmal sind kein Charakter mehr, sondern Rauschen.
const HOECHSTENS := 3

## Eigene Saat, damit sich die Mutationen aendern lassen, ohne dass sich die
## Zusammensetzung jeder Welle mitverschiebt.
const SAAT := 0x4d555400


## --- Wie stark ---
##
## Alle Staerken sind Anteile, keine festen Zahlen. Ein fester Panzerwert
## waere in Welle 70 eine Wand und in Welle 700 nicht mehr zu bemerken.

## Panzer als Anteil der Leistung, die der Kegel bei voller Helligkeit auf ein
## Ziel bringt. Abgeleitet aus der Sollkurve, nicht gewaehlt - genau wie das
## Leben eines Leitwesens.
##
## **Hier stand 0,14, und das war die teuerste Zahl im Graben.** Sie klingt
## nach vierzehn Prozent; sie ist es aber nur am hellsten Punkt des Kegels.
## Ein Panzer zieht einen **festen** Betrag ab, und die Helligkeit, bei der
## ein Tier wirklich brennt, liegt im Rundumlauf weit darunter - der Kegel
## schwenkt, die meisten Ziele stehen im Halbschatten, und ein Abschnitt
## nimmt noch einmal davon weg. Vierzehn Prozent vom Maximum waren damit ueber
## die Haelfte des tatsaechlichen Schadens.
##
## Gemessen mit `tools/mutationskosten.gd`, gleiche Welle, gleiche
## Zusammensetzung, nur diese Zahl geaendert: **868 Huellenpunkte bei 0,14,
## 453 bei 0,045.** Der Zug allein kostete mehr als die ganze uebrige Welle.
const PANZER_ANTEIL := 0.045

## Helligkeit, unter der eine lichtscheue Welle gar nichts abbekommt.
const LICHT_SCHWELLE := 0.42

## **Drift und Schub kosten nichts, und das ist gemessen.** Ein Fuenftel
## weniger Drift (0,55 auf 0,45) aendert den Huellenverlust ueber achtzig
## Wellen von 344 auf 350, ein Sechstel weniger Schub (0,45 auf 0,38) von 337
## auf 337. Beide Zuege aendern, **wie** eine Welle sich anfuehlt, und nicht,
## was sie kostet - genau das soll eine Mutation tun. Sie bleiben deshalb
## dort, wo sie stehen; die kleinen Abschlaege sind mitgemessen und schaden
## nicht.
const DRIFT_ZUSATZ := 0.45
const STOSS_ZUSATZ := 0.38

## **Tempo kostet sehr wohl.** 1,22 auf 1,10 gemessen: 621 Huelle auf 440.
## Der Grund ist derselbe wie beim Panzer und faellt nur im Rundumlauf an -
## der Kegel ist immer bei jemand anderem, und wer schneller ist, hat weniger
## Sekunden im Licht, bevor er am Boot steht. Am einzelnen Tier gemessen
## kostet Tempo gar nichts (der Kegel liegt dann ja durchgehend darauf); das
## war der blinde Fleck des ersten Messstands.
const HAST_FAKTOR := 1.10

## **Der leere Zielplatz, gemessen.** 1,6/1,35 auf 1,25/1,20: 759 Huelle auf
## 420. Der Kegel fasst `Ausbau.ziele()` Ziele gleichzeitig, und weniger,
## zaehere Koerper heisst leere Plaetze - dieselbe Begruendung wie unten beim
## Wirkungsgrad, jetzt mit einer Zahl dahinter.
const AUFGEDUNSEN_LEBEN := 1.25
const AUFGEDUNSEN_RADIUS := 1.20


## Was jede Mutation den Spieler an Wirkungsgrad kostet.
##
## **Ohne das ist jede Mutation eine Wand.** `Wellen.staerke()` leitet das
## Budget einer Welle aus dem ab, was ein Spieler leisten kann; kennt sie die
## Mutationen nicht, bekommt eine gepanzerte Welle genauso viele Raeuber wie
## eine nackte. Bei den Abschnittsregeln hat genau dieses Versaeumnis fuenf
## gefallene Sitzungen ab Welle 36 gekostet - siehe `Regeln.wirkungsgrad`.
##
## Gemessen am Wellenpruefer, nicht geschaetzt - und seit es
## `tools/mutationskosten.gd` gibt, auch einzeln. Die sechs Zahlen selbst
## bleiben, wo sie stehen: gedreht wurde an den **Staerken** darueber, bis
## jede Mutation ungefaehr das kostet, was hier eingepreist ist. Das ist die
## richtige Reihenfolge - ein Zug, den man nur durch eine Drittelung des
## Wellenbudgets bezahlen kann, ist keine Abwechslung mehr, sondern eine
## andere Welle.
##
## Ergebnis am Wellenpruefer ueber 240 Wellen: **von zwoelf gefallenen
## Sitzungen auf zwei.**
##
## `AUFGEDUNSEN` stand hier auf 1.0, weil ein groesseres Ziel leichter im
## Kegel zu halten sei, als ein zaeheres schwer zu toeten. Das war falsch, und
## der Wellenpruefer hat es sofort gezeigt: **jede einzelne gefallene Sitzung
## lag auf einer aufgedunsenen Welle.** Der Grund liegt nicht am einzelnen
## Tier, sondern an der Zahl: das Budget einer Welle ist Lebenspunkte, also
## bringt zaeheres Leben weniger Tiere. Der Kegel fasst aber `Ausbau.ziele()`
## Ziele gleichzeitig - stehen weniger davon im Wasser, verfaellt der Rest
## seiner Leistung ungenutzt. Genau das kostet eine aufgedunsene Welle.
const WIRKUNGSGRAD: PackedFloat32Array = [0.87, 0.88, 0.93, 0.94, 0.90, 0.80]


static func name_von(m: int) -> String:
    return NAMEN[clampi(m, 0, NAMEN.size() - 1)]


static func hinweis(m: int) -> String:
    return HINWEISE[clampi(m, 0, HINWEISE.size() - 1)]


## Wie viele Zuege eine Welle dieser Tiefe traegt: einer je Umdrehung, bis
## `HOECHSTENS`.
static func zahl_in(nummer: int) -> int:
    return clampi(Graben.zyklus(nummer) - AB_ZYKLUS + 1, 0, HOECHSTENS)


## Welche Mutationen Welle `nummer` traegt - gerechnet, nicht gewuerfelt, aus
## demselben Grund wie die Zusammensetzung der Welle selbst: der Wellenpruefer
## muss dieselbe Welle durchrechnen koennen, die beim Spieler ankommt, und
## alle Spieler sollen dieselbe Welle 137 sehen.
## Ein Platz Gedaechtnis, und der ist noetig.
##
## `in_welle()` haengt an `Wellen.panzer_in()` und funf Geschwistern, und die
## fragt das Spiel fuer **jedes Tier in jedem Bild** - zweihundert Raeuber mal
## sechs Eigenschaften mal sechzig Bilder. Ohne diesen einen Platz baute es
## siebzigtausend Zufallsgeneratoren in der Sekunde auf, und zwar auf einem
## Telefon. Mehr als ein Platz braucht es nicht: es laeuft immer genau eine
## Welle.
static var _letzte_nummer := -1
static var _letzte_liste := PackedInt32Array()

## **Nur fuer den Messstand.** Ist etwas gesetzt, traegt jede Welle genau
## diese Zuege - `tools/mutationskosten.gd` misst damit dieselbe Welle einmal
## mit und einmal ohne einen Zug. Anders geht es nicht: `in_welle()` haengt
## an der Wellennummer, und wer eine Mutation einzeln anschauen will, kann
## sie nicht herbeiwuenschen, indem er die Nummer wechselt - dann wechselt
## die ganze Welle mit.
##
## Im Spiel bleibt es leer, und `_test_mutationszwang_bleibt_im_werkzeug`
## liest den Quelltext daraufhin: ausserhalb von `tools/` darf `erzwinge()`
## nirgends stehen. Eine Schraube, die nur ein Werkzeug drehen darf, muss
## festgeschraubt sein.
static var _zwang := PackedInt32Array()
static var _zwang_an := false


## Setzt den Zwang und wirft das Gedaechtnis weg.
##
## **Die leere Liste ist ein gueltiger Zwang** und heisst "gar keine
## Mutation" - nicht "kein Zwang". Der erste Anlauf hat beides
## zusammengeworfen, und dann war der Nullfall des Messstands in Wahrheit die
## gewachsene Welle mit ihren zwei bis drei Zuegen: gemessen wurde jede
## Mutation gegen eine haertere Welle als sich selbst, und alle sechs kamen
## billiger heraus, als sie eingepreist sind. Zum Aufheben gibt es `frei()`.
##
## Wer danach `Wellen.staerke()` fragt, muss auch dort vergessen lassen -
## `Wellen.vergiss_umgebung()`. Zwei Gedaechtnisse, zwei Handgriffe; sie hier
## zusammenzufassen hiesse, dass diese Datei `Wellen` kennt, und dann zeigen
## die Abhaengigkeiten im Kreis.
static func erzwinge(liste: PackedInt32Array) -> void:
    _zwang = liste
    _zwang_an = true
    _letzte_nummer = -1
    _letzte_liste = PackedInt32Array()


## Hebt den Zwang auf: die Wellen tragen wieder, was ihre Nummer hergibt.
static func frei() -> void:
    _zwang = PackedInt32Array()
    _zwang_an = false
    _letzte_nummer = -1
    _letzte_liste = PackedInt32Array()


static func in_welle(nummer: int) -> PackedInt32Array:
    if _zwang_an:
        return _zwang
    if nummer == _letzte_nummer:
        return _letzte_liste

    var wieviele := zahl_in(nummer)
    var liste := PackedInt32Array()
    if wieviele <= 0:
        _letzte_nummer = nummer
        _letzte_liste = liste
        return liste

    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + nummer * 104729
    var uebrig: PackedInt32Array = []
    for m in Mutation.size():
        uebrig.append(m)
    for _i in wieviele:
        if uebrig.is_empty():
            break
        var w := rng.randi_range(0, uebrig.size() - 1)
        liste.append(uebrig[w])
        uebrig.remove_at(w)
    liste.sort()
    _letzte_nummer = nummer
    _letzte_liste = liste
    return liste


static func hat(nummer: int, m: int) -> bool:
    return m in in_welle(nummer)


## Der gemeinsame Wirkungsgrad aller Zuege dieser Welle.
static func wirkungsgrad(nummer: int) -> float:
    var f := 1.0
    for m in in_welle(nummer):
        f *= WIRKUNGSGRAD[clampi(m, 0, WIRKUNGSGRAD.size() - 1)]
    return f
