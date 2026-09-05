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
    SPIEGLER,       ## Brennt nur im Randlicht - der Kern prallt ab.
    LAICHWOLKE,     ## Grosser Schwarm winziger Tiere. Viele Koerper, wenig Leben.
    KREISER,        ## Kommt nicht heran - er umkreist das Boot.
    LICHTSCHEU,     ## Weicht dem Kegel aus, solange er brennt.
    SCHLUNDMUTTER,  ## Leitwesen. Steht am Ende jedes Abschnitts, sonst nie.
    KALKROCHEN,     ## Leitwesen. Dicke Haut - nur der Kern des Kegels beisst.
    SCHWARMHERZ,    ## Leitwesen. Schnell und ausweichend statt gepanzert.
    RINGMAUL,       ## Leitwesen. Umkreist - man muss ihm nachfahren.
    BRUTSTOCK,      ## Leitwesen. Setzt Junge ab, solange es lebt.
}

## --- Warum es drei Leitwesen gibt und nicht eines ---
##
## Es gab genau eines, und es stand am Ende **jedes** Abschnitts. Der Graben
## hat keinen Boden; wer ihn zwei Umdrehungen weit spielt, hat sechzehnmal
## dieselbe Schlundmutter erlegt, und zwar an genau der Stelle, die der
## Hoehepunkt sein soll. Ein Hoehepunkt, der immer derselbe ist, ist eine
## Wiederholung mit Musik.
##
## Die drei verlangen Verschiedenes, und zwar nicht "mehr Leben", sondern
## einen anderen Umgang mit dem Kegel:
##
##   * **Schlundmutter** - langsam, riesig, kaum Panzer. Man haelt drauf.
##   * **Kalkrochen** - dicke Haut. Am Rand des Kegels frisst der feste Abzug
##     fast alles; man muss den Kern treffen und dort bleiben.
##   * **Schwarmherz** - kein Panzer, dafuer schnell und weit schlaengelnd.
##     Draufhalten reicht nicht, man muss nachfuehren.
##
##   * **Ringmaul** - es kommt gar nicht erst heran, sondern haelt Abstand
##     und kreist. Wer draufhaelt, dreht sich mit; wer fahren will, verliert
##     es aus dem Kegel. Der erste Hoehepunkt, bei dem Fahren und Zielen
##     gegeneinander stehen.
##   * **Brutstock** - es setzt ab, solange es lebt. Wer es liegen laesst und
##     die Kleinen abraeumt, raeumt fuer immer; wer es zuerst nimmt, steht
##     dabei ungedeckt im Schwarm. Der einzige Hoehepunkt mit einer Uhr.
##
## Welches wo steht, sagt `leitwesen_fuer()` - und das ist keine Zufallswahl,
## sondern eine Zuordnung: der Kalkrochen darf nie in einem Abschnitt stehen,
## der den Kegel abdunkelt. Ein fester Abzug von einem Fuenftel Helligkeit
## frisst alles, und dann steht dort ein unbesiegbares Tier.

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
        &"kennung": &"ZAHNKIEFER",
        &"name": "Fangjaw",
        &"regel": "Sinks straight and dies fast. The yardstick for everything else.",
        &"leben": 22.0,
        &"tempo": 92.0,
        &"radius": 17.0,
        &"wucht": 1,
        &"schlaengel": 14.0,
        &"takt": 1.7,
        &"farbe": Color(0.62, 0.86, 0.95),
        &"ab_welle": 1,
    },
    {
        &"kennung": &"SCHLEIER",
        &"name": "Veilform",
        &"regel": "Comes in swarms and is very fast. Worth almost nothing alone.",
        &"leben": 8.0,
        &"tempo": 168.0,
        &"radius": 12.0,
        &"wucht": 1,
        &"schlaengel": 26.0,
        &"takt": 3.1,
        &"farbe": Color(0.72, 0.62, 0.98),
        &"ab_welle": 3,
        &"gruppe": [3, 5],
    },
    {
        &"kennung": &"PANZERKREBS",
        &"name": "Shellback",
        &"regel": "Slow and tough. Forces the cone to linger.",
        &"leben": 74.0,
        &"tempo": 54.0,
        &"radius": 25.0,
        &"wucht": 3,
        &"schlaengel": 6.0,
        &"takt": 0.9,
        &"farbe": Color(0.98, 0.68, 0.42),
        &"ab_welle": 6,
    },
    {
        &"kennung": &"GRABNATTER",
        &"name": "Trench Adder",
        &"regel": "Weaves wide. Chase it and you lose it; lead it and you hit.",
        &"leben": 34.0,
        &"tempo": 104.0,
        &"radius": 15.0,
        &"wucht": 2,
        &"schlaengel": 82.0,
        &"takt": 2.2,
        &"farbe": Color(0.55, 0.98, 0.72),
        &"ab_welle": 10,
    },
    {
        &"kennung": &"SCHILDKORALLE",
        &"name": "Shieldcoral",
        &"regel": "Armour: a flat amount is subtracted each second. Guard polyps barely scratch it.",
        &"leben": 58.0,
        &"tempo": 44.0,
        &"radius": 24.0,
        &"wucht": 3,
        &"schlaengel": 5.0,
        &"takt": 0.6,
        &"farbe": Color(0.46, 0.90, 0.86),
        &"ab_welle": 16,
        &"panzer": 7.0,
        &"aufwand": 1.60,
    },
    {
        &"kennung": &"GLUTQUALLE",
        &"name": "Emberjelly",
        &"regel": "Burns only in the core of the cone. Trailing it at the edge does nothing.",
        &"leben": 38.0,
        &"tempo": 60.0,
        &"radius": 21.0,
        &"wucht": 2,
        &"schlaengel": 20.0,
        &"takt": 1.0,
        &"farbe": Color(1.00, 0.56, 0.62),
        &"ab_welle": 24,
        &"mindest_licht": 0.52,
        &"aufwand": 1.45,
    },
    {
        &"kennung": &"TREIBANKER",
        &"name": "Driftanchor",
        &"regel": "Drifts sideways across the screen. Leaves the cone even if you hold still.",
        &"leben": 44.0,
        &"tempo": 56.0,
        &"radius": 19.0,
        &"wucht": 2,
        &"schlaengel": 9.0,
        &"takt": 1.3,
        &"farbe": Color(0.86, 0.82, 0.52),
        &"ab_welle": 32,
        &"drift": 27.0,
        &"aufwand": 1.30,
    },
    {
        &"kennung": &"SPRUNGAAL",
        &"name": "Lunge Eel",
        &"regel": "Sinks in bursts. Your usual tracking misses it.",
        &"leben": 28.0,
        &"tempo": 118.0,
        &"radius": 14.0,
        &"wucht": 2,
        &"schlaengel": 28.0,
        &"takt": 2.6,
        &"farbe": Color(0.60, 0.72, 1.00),
        &"ab_welle": 42,
        &"stoss": 0.85,
        &"aufwand": 1.22,
    },
    {
        &"kennung": &"SPIEGLER",
        &"name": "Mirrorshell",
        &"regel": "Its shell throws the core of the beam back. Only the fringe of the light burns it.",
        &"leben": 40.0,
        &"tempo": 58.0,
        &"radius": 23.0,
        &"wucht": 3,
        &"schlaengel": 11.0,
        &"takt": 0.8,
        &"farbe": Color(0.80, 0.84, 0.98),
        &"ab_welle": 54,
        &"hoechst_licht": 0.78,
        &"aufwand": 1.30,
    },
    {
        &"kennung": &"LAICHWOLKE",
        &"name": "Spawncloud",
        &"regel": "Comes six to nine at a time. Any one of them is nothing; all of them are a wall.",
        # **Der Gegenentwurf zur Zaehigkeit.** Ueber die Wellen hinweg
        # wachsen die Lebenspunkte je Tier, damit die Zahl lesbar bleibt -
        # das ist richtig, macht das Bild aber mit der Zeit leer. Diese Art
        # zieht in die andere Richtung: viel Koerper, fast kein Leben. Sie
        # kostet dasselbe Budget wie ein mittleres Tier und fuellt dafuer den
        # Schirm.
        &"leben": 5.0,
        # **Nicht kleiner.** `_test_takt_deckelt_den_sprung` haelt fest, dass
        # ein Tier in einem Bild nie weiter kommt als sein eigener
        # Durchmesser - sonst springt es durch den Rumpf, ohne ihn zu
        # beruehren. Bei Radius 9 trug ein Schritt 23.5 Einheiten gegen 18
        # Durchmesser.
        &"tempo": 132.0,
        &"radius": 12.0,
        &"wucht": 1,
        &"schlaengel": 32.0,
        &"takt": 3.6,
        &"farbe": Color(0.56, 0.98, 0.86),
        &"ab_welle": 20,
        # **Eins, nicht weniger.** Eine Art darf nie billiger sein als ihr
        # Leben, sonst kauft das Wellenbudget an ihr mehr Leben, als es
        # bezahlt. Der Schwarm wird trotzdem billig - nicht weil das Stueck
        # unter Wert geht, sondern weil das Stueck fast nichts ist.
        &"aufwand": 1.0,
        # Wieviele auf einen Schlag kommen. Steht hier und nicht in
        # `Wellen.auftritte()`, weil die Gruppengroesse eine Eigenschaft der
        # Art ist - vorher stand der Schleier dort als Sonderfall im Code.
        &"gruppe": [6, 9],
    },
    {
        &"kennung": &"KREISER",
        &"name": "Ringrunner",
        &"regel": "Never closes in. It circles you - hold the beam and you stop steering.",
        &"leben": 46.0,
        &"tempo": 104.0,
        &"radius": 16.0,
        &"wucht": 2,
        &"schlaengel": 8.0,
        &"takt": 1.1,
        &"farbe": Color(1.00, 0.74, 0.38),
        &"ab_welle": 66,
        &"aufwand": 1.24,
        # **Sein ganzer Entwurf.** Er haelt diesen Abstand und laeuft
        # seitlich weiter, statt geradeaus zu kommen. Im Schlund waere das
        # sinnlos gewesen - dort sank alles dieselbe Bahn nach unten. Hier
        # stellt er Fahren und Zielen gegeneinander: wer ihn im Kegel haelt,
        # dreht sich mit ihm und faehrt nicht mehr.
        &"umlauf": 260.0,
    },
    {
        &"kennung": &"LICHTSCHEU",
        &"name": "Shylight",
        &"regel": "Backs away while lit. Half a beam only pushes it out of reach.",
        &"leben": 34.0,
        &"tempo": 96.0,
        &"radius": 15.0,
        &"wucht": 2,
        &"schlaengel": 18.0,
        &"takt": 1.9,
        &"farbe": Color(0.72, 0.90, 0.66),
        &"ab_welle": 78,
        &"aufwand": 1.18,
        # **Wer es anleuchtet, schiebt es weg.** Das dreht die uebliche
        # Antwort um: draufhalten kostet hier Zeit, statt sie zu sparen. Man
        # nimmt es mit dem Stosslicht, oder man laesst es kommen und faengt
        # es kurz vor dem Rumpf.
        &"scheu": 0.85,
    },
    {
        &"kennung": &"SCHLUNDMUTTER",
        &"name": "Maw Mother",
        &"regel": "Warden at the end of every section. Slow, very tough - and one hit costs a third of the brood.",
        &"leben": 1.0,
        # So langsam, dass sie erst gegen Ende der Welle bei der Brut waere.
        # Das ist der Entwurf: sie ist das Finale, nicht die Ueberraschung.
        # Bei Tempo 30 lag der Spielraum der Wellen 36-40 wieder bei 1.00 -
        # kein Puffer mehr, und den hatte diese Strecke vorher.
        &"tempo": 23.0,
        # Gross genug, dass man sie nicht fuer eine Glutqualle haelt. Bei 42
        # sah sie im Bild aus wie ein weiteres mittleres Tier - ein
        # Hoehepunkt, den man erst am Lebensbalken erkennt, ist keiner.
        &"radius": 60.0,
        # Bei Wucht 6 kam der Wellenpruefer in Welle 40 mit 1 von 12 Brut
        # durch: dort dunkelt der Abschnitt den Kegel ab, die Schlundmutter
        # erreicht die Brut, und ein einziger Treffer nahm die Haelfte. Ein
        # Hoehepunkt darf teuer sein, aber nicht auf einen Schlag entscheiden.
        &"wucht": 4,
        &"schlaengel": 7.0,
        &"takt": 0.45,
        &"farbe": Color(0.98, 0.30, 0.52),
        &"ab_welle": Graben.WELLEN_JE_ABSCHNITT,
        # Nur wenig Panzer, obwohl sie danach aussieht. Bei acht meldete der
        # Wellenpruefer Welle 40 mit 1/12 Brut: dort dunkelt der Abschnitt den
        # Kegel auf ein Fuenftel ab, und ein fester Abzug frisst von einem
        # Fuenftel fast alles. Ihre Groesse liegt in den Lebenspunkten, nicht
        # in der Haut - dafuer gibt es die Schildkoralle.
        &"panzer": 3.0,
        &"aufwand": 1.0,
        &"leitwesen": true,
    },
    {
        &"kennung": &"KALKROCHEN",
        &"name": "Chalk Ray",
        &"regel": "Warden with a shell that shrugs off the fringe. Only the core of the beam bites.",
        &"leben": 1.0,
        # Etwas schneller als die Schlundmutter: sie ist der Brocken, er ist
        # der Druck. Zwei Leitwesen mit demselben Tempo waeren dasselbe Tier
        # in zwei Farben.
        &"tempo": 31.0,
        &"radius": 54.0,
        &"wucht": 4,
        &"schlaengel": 5.0,
        &"takt": 0.35,
        &"farbe": Color(0.94, 0.78, 0.42),
        &"ab_welle": Graben.WELLEN_JE_ABSCHNITT,
        # **Das ist sein ganzer Entwurf.** Der Panzer zieht einen festen
        # Betrag je Sekunde ab; am Rand des Kegels bleibt davon nichts uebrig.
        # Sein Leben wird - wie bei jedem Leitwesen - aus
        # `(Kegel - Panzer) * Sekunden` gerechnet, der Kampf dauert also
        # gleich lang. Was sich aendert, ist **wo** man stehen muss.
        #
        # Er darf deshalb nie in einem Abschnitt stehen, der den Kegel
        # abdunkelt: `leitwesen_fuer()` haelt das fest.
        &"panzer": 13.0,
        &"aufwand": 1.0,
        &"leitwesen": true,
    },
    {
        &"kennung": &"SCHWARMHERZ",
        &"name": "Swarm Heart",
        &"regel": "Warden that will not hold still. No shell - but it leaves the beam on its own.",
        &"leben": 1.0,
        &"tempo": 38.0,
        # Groesser als zuerst: bei 46 stand es im Bild neben einer
        # Grabnatter und sah aus wie eine. Ein Leitwesen muss man am Umriss
        # erkennen, nicht am Lebensbalken.
        &"radius": 54.0,
        &"wucht": 4,
        # Der Gegenentwurf zum Kalkrochen: keine Haut, dafuer eine Bahn, die
        # weit ausschlaegt und schnell schwingt. Draufhalten reicht nicht.
        &"schlaengel": 46.0,
        &"takt": 1.15,
        &"farbe": Color(0.58, 0.96, 0.78),
        &"ab_welle": Graben.WELLEN_JE_ABSCHNITT,
        &"panzer": 1.0,
        &"aufwand": 1.0,
        &"leitwesen": true,
    },
    {
        &"kennung": &"RINGMAUL",
        &"name": "Ring Maw",
        &"regel": "Warden that keeps its distance and circles. Hold the beam on it and you stop steering.",
        &"leben": 1.0,
        &"tempo": 58.0,
        &"radius": 50.0,
        &"wucht": 4,
        &"schlaengel": 12.0,
        &"takt": 0.7,
        &"farbe": Color(0.98, 0.62, 0.24),
        &"ab_welle": Graben.WELLEN_JE_ABSCHNITT,
        &"panzer": 2.0,
        &"aufwand": 1.0,
        &"leitwesen": true,
        # Weiter draussen als der Kreiser: ein Leitwesen soll man kommen
        # sehen, und auf 260 Einheiten stuende es bereits im Kegel, ohne dass
        # man gefahren waere.
        &"umlauf": 400.0,
    },
    {
        &"kennung": &"BRUTSTOCK",
        &"name": "Broodstalk",
        &"regel": "Warden that keeps spawning while it lives. Clear the young and you clear forever.",
        &"leben": 1.0,
        &"tempo": 26.0,
        &"radius": 56.0,
        &"wucht": 4,
        &"schlaengel": 6.0,
        &"takt": 0.4,
        &"farbe": Color(0.70, 0.42, 0.98),
        &"ab_welle": Graben.WELLEN_JE_ABSCHNITT,
        &"panzer": 3.0,
        &"aufwand": 1.0,
        &"leitwesen": true,
        # **Der einzige Hoehepunkt mit einer Uhr.** Alle `brut_takt` Sekunden
        # setzt er ein Junges ab. Wer die Kleinen abraeumt und ihn stehen
        # laesst, raeumt fuer immer; wer ihn zuerst nimmt, steht dabei
        # ungedeckt im Schwarm.
        #
        # Die Jungen zahlen **nichts** und stehen in keinem Budget - sonst
        # wuerde ein Leitwesen, das man lange stehen laesst, zur
        # Naehrstoffquelle, und die Wirtschaft haengt an der Wellenzahl
        # (Zusage 10). Dieselbe Begruendung wie bei der Funkenbluete
        # (Zusage 18): was nichts zahlt, verschiebt auch nichts.
        &"brut_takt": 2.4,
        &"brut_art": &"LAICHWOLKE",
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


## Ab welcher Helligkeit der Strahl abprallt. 0.0 heisst: keine Obergrenze.
static func hoechst_licht(index: int) -> float:
    return float(art(index).get(&"hoechst_licht", 0.0))


# --- Was die Arten des Rundumlaufs anders machen ---------------------------
#
# Drei Eigenschaften, die es im Schlund nicht geben konnte: dort sank alles
# dieselbe Bahn nach unten, also gab es kein Umkreisen, kein Zurueckweichen
# und keinen Ort, an dem etwas absetzen koennte.

## Auf welchem Abstand ein Tier um das Boot kreist, statt heranzukommen.
## 0.0 heisst: es kommt geradewegs.
static func umlauf(index: int) -> float:
    return float(art(index).get(&"umlauf", 0.0))


## Wie stark ein Tier zurueckweicht, solange es im Kegel steht. 0.0 heisst:
## es laesst sich anleuchten.
static func scheu(index: int) -> float:
    return float(art(index).get(&"scheu", 0.0))


## Alle wieviel Sekunden ein Tier ein Junges absetzt. 0.0 heisst: gar nicht.
static func brut_takt(index: int) -> float:
    return float(art(index).get(&"brut_takt", 0.0))


## Welche Art dabei herauskommt, oder -1.
static func brut_art(index: int) -> int:
    var k: StringName = art(index).get(&"brut_art", &"")
    if k == &"":
        return -1
    for i in TABELLE.size():
        if TABELLE[i][&"kennung"] == k:
            return i
    return -1


## Wieviele Tiere dieser Art auf einen Schlag kommen: [min, max].
##
## **Stand als Sonderfall in `Wellen.auftritte()`**, wo der Schleier
## namentlich abgefragt wurde. Die Gruppengroesse ist aber eine Eigenschaft
## der Art und keine des Wellenbaus - sonst muss man jede neue Schwarmart an
## zwei Stellen eintragen und vergisst die zweite.
static func gruppe(index: int) -> Vector2i:
    var g: Array = art(index).get(&"gruppe", [])
    if g.size() < 2:
        return Vector2i(1, 1)
    return Vector2i(int(g[0]), int(g[1]))


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


## Ob eine Art ein Leitwesen ist - eines der sechs Tiere, die nur am Ende
## eines Grabenabschnitts stehen.
##
## Sie werden **nicht** gewuerfelt wie die anderen: `Wellen.auftritte()` setzt
## genau eines auf die letzte Welle jedes Abschnitts und bezahlt es zuerst aus
## dem Budget. Waeren sie Teil der normalen Auswahl, kaeme irgendwann eine
## Welle aus lauter Leitwesen - und aus sechs Hoehepunkten wuerde Rauschen.
static func ist_leitwesen(index: int) -> bool:
    return bool(art(index).get(&"leitwesen", false))


## Welche Arten in Welle `nummer` ueberhaupt gewuerfelt werden duerfen.
static func verfuegbar(nummer: int) -> PackedInt32Array:
    var liste := PackedInt32Array()
    for i in TABELLE.size():
        if ist_leitwesen(i):
            continue
        if nummer >= int(TABELLE[i][&"ab_welle"]):
            liste.append(i)
    return liste


## Alle Leitwesen, in Tabellenreihenfolge.
static func leitwesen_liste() -> PackedInt32Array:
    var liste := PackedInt32Array()
    for i in TABELLE.size():
        if ist_leitwesen(i):
            liste.append(i)
    return liste


## Das erste Leitwesen, oder -1. Bleibt fuer den Fall, dass jemand nur wissen
## will, ob es ueberhaupt eines gibt.
static func leitwesen() -> int:
    for i in TABELLE.size():
        if ist_leitwesen(i):
            return i
    return -1


## **Welches Leitwesen am Ende dieses Abschnitts steht.**
##
## Eine feste Zuordnung, keine Wuerfelei: der Kalkrochen traegt einen Panzer,
## und ein fester Abzug frisst in einem abgedunkelten Abschnitt alles, was der
## Kegel noch hergibt. Er steht deshalb nur dort, wo `Regeln.DUNKEL` nicht
## gilt - in den Abschnitten 0, 1, 2 und 6. Die anderen beiden duerfen
## ueberall stehen.
##
## Der Index wiederholt sich mit den Abschnitten, nicht mit den Umdrehungen:
## wer den Graben zum zweiten Mal durchlaeuft, trifft dieselbe Folge unter
## haerteren Regeln. Das ist Absicht - eine Abfolge, die man kennt, ist der
## Unterschied zwischen einem Abstieg und einer Liste.
## **Fuenf Leitwesen auf acht Abschnitte, von Hand zugeordnet.**
##
## Die eine harte Regel steht in `_test_gepanzertes_leitwesen_nie_im_dunkeln`:
## der Kalkrochen (Platz 1) darf nie in einem Abschnitt stehen, der den Kegel
## abdunkelt - ein fester Abzug frisst von einem Fuenftel Helligkeit alles,
## und dann steht dort ein unbesiegbares Tier. Er liegt deshalb auf 1 und 6,
## den beiden Abschnitten ohne Dunkelphase.
##
## Der Rest ist Abwechslung: keine zwei gleichen nebeneinander, und jedes der
## fuenf kommt in einer Umdrehung mindestens einmal vor. Vorher waren es
## drei auf acht - man sah dasselbe Finale dreimal je Umdrehung.
const LEITFOLGE: PackedInt32Array = [0, 1, 3, 2, 4, 0, 1, 3]


static func leitwesen_fuer(abschnitt: int) -> int:
    var liste := leitwesen_liste()
    if liste.is_empty():
        return -1
    var wahl := LEITFOLGE[clampi(abschnitt, 0, LEITFOLGE.size() - 1)]
    return liste[clampi(wahl, 0, liste.size() - 1)]
