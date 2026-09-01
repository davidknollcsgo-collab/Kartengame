class_name KolonieStand
extends RefCounted

## Der Zustand der Kolonie: Kammerstufen, Vorrat, laufender Bau, Fortschritt.
##
## Reine Datenschicht - kein Szenen-, kein Autoload-Bezug. Deshalb kann der
## Balance-Durchlauf (`tools/kolonielauf.gd`) dreissig simulierte Tage
## durchrechnen, ohne das Spiel zu starten, und rechnet dabei mit genau
## denselben Regeln wie der Spieler.

## Startvorrat. Ohne ihn stuende der Spieler vor lauter gesperrten Knoepfen -
## derselbe Kaltstart, der bei STERNWERFT hundert simulierte Stunden lang
## nichts verdient hat.
const START_NAEHRSTOFF := 40

## Offline-Ertrag wird gedeckelt. Ein Filterbecken, das ueber Wochen sammelt,
## nimmt der Rueckkehr jeden Reiz - und macht Wartezeit zur besseren Strategie
## als Spielen.
const OFFLINE_DECKEL_STUNDEN := 8.0

var stufen := PackedInt32Array()

## Welche Brutlinien schon gezuechtet sind, und welche gerade traegt.
var linien := PackedInt32Array()
var linie := Brutlinien.Linie.KEINE
var naehrstoffe := START_NAEHRSTOFF
var hoechste_welle := 1

## Die beste Punktzahl einer Sitzung. Sie kostet nichts und schaltet nichts
## frei - sie ist der Grund, es noch einmal zu versuchen, wenn die Kolonie
## fuer heute fertig gebaut ist und der naechste Abschnitt noch zu ist.
var bestpunkte := 0

## Die laengste Kette, die je gehalten wurde. Zweite Bestmarke, weil sie etwas
## anderes misst als die Punktzahl: die sagt "eine gute Sitzung", diese sagt
## "ein guter Augenblick".
var beste_kette := 0

## Laufender Bau: -1 heisst keiner. `bau_fertig_um` ist Systemzeit in Sekunden.
var bau_kammer := -1
var bau_fertig_um := 0.0

## Wann der Spieler zuletzt da war - Grundlage des Offline-Ertrags.
var zuletzt_gesehen := 0.0

## --- Tagesziel ---
##
## `tag` ist der Tag, fuer den `fortschritt` und `geholt` gelten. Wechselt er,
## beginnen die Ziele von vorn; `strecke` zaehlt weiter.
var tag := 0
var ziel_fortschritt := PackedInt32Array()
var ziel_geholt := PackedInt32Array()
var strecke := 0

## Welche Raeuberarten schon einmal aufgetreten sind. Grundlage des
## Bestiariums - und der Ankuendigung, wenn eine zum ersten Mal kommt.
var gesehen := PackedInt32Array()

## Und welche Mutationen. Dieselbe Begruendung: eine gepanzerte Welle, die
## niemand erklaert hat, ist keine Abwechslung, sondern ein Fehler im Spiel.
var mutationen_gesehen := PackedInt32Array()

## Zuchtkalender: wie viele Tage schon abgeholt sind und an welchem Kalendertag
## zuletzt. Er laeuft genau einmal durch - siehe `Zuchtkalender`.
var kalender := 0
var kalender_tag := 0

## Wie viele Stroemungswellen heute noch offen sind. Wird am Tageswechsel
## wieder aufgefuellt - siehe `Tagesstroemung`.
var stroemung_offen := Tagesstroemung.JE_TAG

## Wie weit der Einstieg gediehen ist. Er laeuft genau einmal, und zwar
## waehrend gespielt wird - nicht als Textwand davor.
var einstieg := 0


func _init() -> void:
    stufen.resize(Kammern.zahl())
    stufen.fill(0)
    linien.append(Brutlinien.Linie.KEINE)
    ziel_fortschritt.resize(Tagesziel.zahl())
    ziel_geholt.resize(Tagesziel.zahl())


func stufe(kammer: int) -> int:
    if kammer < 0 or kammer >= stufen.size():
        return 0
    return stufen[kammer]


func schacht() -> int:
    return stufe(Kammern.Kammer.TIEFENSCHACHT)


# --- Grabentiefe -----------------------------------------------------------

## Die tiefste Welle, die der Graben derzeit hergibt.
func offene_welle() -> int:
    return Ausbau.offene_welle(schacht())


## Die Welle, die als naechstes gespielt wird. Der Fortschritt darf ueber den
## offenen Graben hinauszeigen - gespielt wird trotzdem nur, was offen ist.
func naechste_welle() -> int:
    return clampi(mini(hoechste_welle, offene_welle()), 1, Graben.TIEFSTE)


## Ob der Graben den Fortschritt gerade aufhaelt.
func graben_haelt() -> bool:
    return hoechste_welle > offene_welle()


## Welche Schachtstufe den naechsten Abschnitt oeffnet - 0, wenn keiner mehr
## aussteht.
func naechste_tiefe() -> int:
    # Es gibt immer einen naechsten Abschnitt - der Graben hat keinen Boden.
    return Ausbau.schacht_fuer_abschnitt(Graben.abschnitt_gesamt(offene_welle()) + 1)


# --- Bauen -----------------------------------------------------------------

func baut() -> bool:
    return bau_kammer >= 0


func preis(kammer: int) -> int:
    return Kammern.kosten(kammer, stufe(kammer))


func am_deckel(kammer: int) -> bool:
    return not Kammern.ausbaubar(kammer, stufe(kammer), schacht())


## Warum ein Ausbau gerade nicht geht - leerer String heisst: er geht.
##
## Ein Knopf, der nur grau ist, laesst den Spieler raten. Der Grund gehoert
## dorthin, wo er entsteht, nicht in die Anzeige.
func hindernis(kammer: int) -> String:
    if baut():
        return "Already digging"
    if am_deckel(kammer):
        if kammer == Kammern.Kammer.TIEFENSCHACHT:
            return "Deepest point reached"
        return "The deep shaft must go deeper"
    var fehlt := preis(kammer) - naehrstoffe
    if fehlt > 0:
        return "%d nutrients short" % fehlt
    return ""


func kann_bauen(kammer: int) -> bool:
    return hindernis(kammer).is_empty()


func starte_bau(kammer: int, jetzt: float) -> bool:
    if not kann_bauen(kammer):
        return false
    naehrstoffe -= preis(kammer)
    bau_kammer = kammer
    bau_fertig_um = jetzt + Kammern.bauzeit(kammer, stufe(kammer))
    return true


func restzeit(jetzt: float) -> float:
    if not baut():
        return 0.0
    return maxf(0.0, bau_fertig_um - jetzt)


## Holt einen fertigen Bau ab. Gibt die Kammer zurueck oder -1.
func hole_bau_ab(jetzt: float) -> int:
    if not baut() or restzeit(jetzt) > 0.0:
        return -1
    var kammer := bau_kammer
    stufen[kammer] += 1
    bau_kammer = -1
    bau_fertig_um = 0.0
    return kammer


# --- Tagesziel -------------------------------------------------------------

## Prueft den Tageswechsel. Gibt zurueck, ob ein neuer Tag begonnen hat.
func pruefe_tag() -> bool:
    var jetzt := Tagesziel.heute()
    if jetzt == tag:
        return false
    # Nur wer *gestern* da war, setzt die Strecke fort. Wer laenger weg war,
    # beginnt bei eins - aber verliert nichts anderes.
    strecke = strecke + 1 if tag > 0 and _ist_gestern(tag, jetzt) else 1
    tag = jetzt
    ziel_fortschritt.fill(0)
    ziel_geholt.fill(0)
    stroemung_offen = Tagesstroemung.JE_TAG
    return true


static func _ist_gestern(alt: int, neu: int) -> bool:
    var a := Time.get_unix_time_from_datetime_dict({
        "year": alt / 10000, "month": (alt / 100) % 100, "day": alt % 100,
        "hour": 12, "minute": 0, "second": 0})
    var n := Time.get_unix_time_from_datetime_dict({
        "year": neu / 10000, "month": (neu / 100) % 100, "day": neu % 100,
        "hour": 12, "minute": 0, "second": 0})
    return absf(n - a - 86400.0) < 43200.0


func melde_ziel(index: int, menge := 1) -> void:
    if index < 0 or index >= ziel_fortschritt.size():
        return
    ziel_fortschritt[index] = mini(ziel_fortschritt[index] + menge,
        Tagesziel.menge(index))


## Hebt den Fortschritt auf `wert`, wenn er hoeher ist.
##
## `melde_ziel()` zaehlt zusammen - richtig fuer "sechzig Raeuber", falsch
## fuer "eine Kette von zwoelf": dort ist nicht die Summe gefragt, sondern der
## hoechste erreichte Stand. Zwei Ziele, zwei Rechenarten.
func setze_ziel(index: int, wert: int) -> void:
    if index < 0 or index >= ziel_fortschritt.size():
        return
    ziel_fortschritt[index] = clampi(maxi(ziel_fortschritt[index], wert),
        0, Tagesziel.menge(index))


func ziel_erfuellt(index: int) -> bool:
    return ziel_fortschritt[index] >= Tagesziel.menge(index)


func ziel_offen(index: int) -> bool:
    return ziel_erfuellt(index) and ziel_geholt[index] == 0


## Holt den Lohn eines erfuellten Ziels ab. Gibt zurueck, was es einbrachte.
func hole_ziel(index: int) -> int:
    if not ziel_offen(index):
        return 0
    ziel_geholt[index] = 1
    var lohn := Tagesziel.lohn(index, hoechste_welle)
    naehrstoffe += lohn
    return lohn


func ziele_offen() -> int:
    var zahl := 0
    for i in ziel_fortschritt.size():
        if ziel_offen(i):
            zahl += 1
    return zahl


# --- Bestiarium ------------------------------------------------------------

func kennt(art: int) -> bool:
    return gesehen.has(art)


## Merkt sich eine Art. Gibt zurueck, ob sie neu war.
func merke_art(art: int) -> bool:
    if art < 0 or art >= Arten.zahl() or gesehen.has(art):
        return false
    gesehen.append(art)
    return true


func kennt_mutation(m: int) -> bool:
    return mutationen_gesehen.has(m)


## Merkt sich eine Mutation. Gibt zurueck, ob sie neu war.
func merke_mutation(m: int) -> bool:
    if m < 0 or m >= Mutationen.Mutation.size() or mutationen_gesehen.has(m):
        return false
    mutationen_gesehen.append(m)
    return true


# --- Zuchtkalender ---------------------------------------------------------

## Ob heute ein Kalendertag abzuholen ist.
func kalender_offen() -> bool:
    return kalender < Zuchtkalender.TAGE and kalender_tag != tag


## Welche Linie der Kalender schenkt: die naechste, die noch fehlt. Weil jede
## Linie die davor voraussetzt, ist die erste fehlende immer auch die
## zuechtbare - der Kalender kann also nichts verschenken, was ins Leere geht.
func kalender_linie() -> int:
    for i in range(1, Brutlinien.zahl()):
        if not hat_linie(i):
            return i
    return Brutlinien.Linie.KEINE


## Holt den heutigen Kalendertag ab. Gibt zurueck, was er einbrachte:
## `{&"linie": n}` oder `{&"naehrstoff": n}`, leer wenn nichts offen war.
func hole_kalender() -> Dictionary:
    if not kalender_offen():
        return {}
    var index := kalender
    kalender += 1
    kalender_tag = tag

    if Zuchtkalender.ist_linientag(index):
        var l := kalender_linie()
        if l != Brutlinien.Linie.KEINE:
            linien.append(l)
            linie = l
            return {&"linie": l}
        # Wer bis dahin alle Linien selbst gezuechtet hat, bekommt ihren Wert.
        # Ein leerer siebter Tag waere die schlechteste Belohnung von allen.
        var wert := Brutlinien.kosten(Brutlinien.zahl() - 1)
        naehrstoffe += wert
        return {&"naehrstoff": wert}

    var lohn := Zuchtkalender.naehrstoff(index, hoechste_welle)
    naehrstoffe += lohn
    return {&"naehrstoff": lohn}


# --- Tagesstroemung --------------------------------------------------------

func hat_stroemung() -> bool:
    return stroemung_offen > 0


## Verbraucht eine Stroemungswelle. Gibt zurueck, ob eine da war.
func nutze_stroemung() -> bool:
    if stroemung_offen <= 0:
        return false
    stroemung_offen -= 1
    return true


# --- Brutlinien ------------------------------------------------------------

func hat_linie(index: int) -> bool:
    return linien.has(index)


## Warum sich eine Linie gerade nicht zuechten laesst. Leer heisst: sie geht.
func linie_hindernis(index: int) -> String:
    if hat_linie(index):
        return "Already bred"
    var davor := Brutlinien.voraussetzung(index)
    if not hat_linie(davor):
        return "Breed %s first" % Brutlinien.name_von(davor)
    var fehlt := Brutlinien.kosten(index) - naehrstoffe
    if fehlt > 0:
        return "%d nutrients short" % fehlt
    return ""


func kann_zuechten(index: int) -> bool:
    return linie_hindernis(index).is_empty()


func zuechte(index: int) -> bool:
    if not kann_zuechten(index):
        return false
    naehrstoffe -= Brutlinien.kosten(index)
    linien.append(index)
    linie = index
    return true


## Waehlt eine bereits gezuechtete Linie aus.
func waehle_linie(index: int) -> bool:
    if not hat_linie(index):
        return false
    linie = index
    return true


# --- Ertrag ----------------------------------------------------------------

func je_stunde() -> float:
    return Kammern.filter_je_stunde(stufe(Kammern.Kammer.FILTERBECKEN))


## Rechnet den Ertrag der Abwesenheit gut und gibt ihn zurueck.
## Wie lange die Kolonie unbeaufsichtigt war, in Stunden und gedeckelt.
##
## Steht als eigene Funktion da, weil die Rueckkehrtafel sie braucht, bevor
## `ernte_offline()` den Zeitstempel weiterstellt - und eine zweite Rechnung
## fuer dieselbe Zeitspanne waere die naechste Stelle, an der zwei Zahlen
## auseinanderlaufen.
func abwesend(jetzt: float) -> float:
    if zuletzt_gesehen <= 0.0:
        return 0.0
    return clampf((jetzt - zuletzt_gesehen) / 3600.0, 0.0, OFFLINE_DECKEL_STUNDEN)


func ernte_offline(jetzt: float) -> int:
    if zuletzt_gesehen <= 0.0:
        zuletzt_gesehen = jetzt
        return 0
    var stunden := abwesend(jetzt)
    zuletzt_gesehen = jetzt
    var ertrag := int(floor(je_stunde() * stunden))
    naehrstoffe += ertrag
    return ertrag


# --- Wirkung auf die Schlundwache -----------------------------------------
#
# Einzige Quelle dieser Werte fuer das Spiel. `Ausbau` bleibt daneben die
# Sollkurve, an der sich die Kolonie messen lassen muss - nicht ihr Ersatz.

func leistung_faktor() -> float:
    return Kammern.leistung_faktor(stufe(Kammern.Kammer.LEUCHTORGAN)) \
        * Brutlinien.leistung_faktor(linie)


## Nie unter eins: eine Linie darf den Waechter umbauen, aber nicht lahmlegen.
func ziele() -> int:
    return maxi(1, Kammern.ziele(stufe(Kammern.Kammer.LEUCHTORGAN))
        + Brutlinien.ziele_zusatz(linie))


func drehtempo() -> float:
    return Graben.DREHTEMPO * Brutlinien.drehtempo_faktor(linie)


func stroemung_faktor() -> float:
    return Brutlinien.stroemung_faktor(linie)


func nachglut_dauer() -> float:
    return Brutlinien.nachglut_dauer(linie)


func nachglut_anteil() -> float:
    return Brutlinien.nachglut_anteil(linie)


func reichweite_faktor() -> float:
    return Kammern.reichweite_faktor(stufe(Kammern.Kammer.LEUCHTORGAN)) \
        * Brutlinien.reichweite_faktor(linie)


func winkel_faktor() -> float:
    return Kammern.winkel_faktor(stufe(Kammern.Kammer.LEUCHTORGAN)) \
        * Brutlinien.winkel_faktor(linie)


## Wieviel vom Panzer eines Raeubers wegfaellt - siehe Salzbrand.
func panzerbruch() -> float:
    return Brutlinien.panzerbruch(linie)


## Um wieviel jede Lichtschwelle nachlaesst - siehe Zwielicht.
func schwellen_nachlass() -> float:
    return Brutlinien.schwellen_nachlass(linie)


func polyp_leistung() -> float:
    return Kammern.polyp_leistung(stufe(Kammern.Kammer.ZUCHTKAMMER))


func polyp_kosten(gebaut: int) -> int:
    return Kammern.polyp_kosten(stufe(Kammern.Kammer.ZUCHTKAMMER), gebaut)


func brut_leben() -> int:
    return Kammern.brut_leben(stufe(Kammern.Kammer.BRUTKAMMER))


# --- Sichern ---------------------------------------------------------------

func zu_wort() -> Dictionary:
    return {
        &"fassung": 1,
        &"stufen": Array(stufen),
        &"naehrstoffe": naehrstoffe,
        &"hoechste_welle": hoechste_welle,
        &"bestpunkte": bestpunkte,
        &"beste_kette": beste_kette,
        &"linien": Array(linien),
        &"linie": linie,
        &"bau_kammer": bau_kammer,
        &"bau_fertig_um": bau_fertig_um,
        &"zuletzt_gesehen": zuletzt_gesehen,
        &"tag": tag,
        &"ziel_fortschritt": Array(ziel_fortschritt),
        &"ziel_geholt": Array(ziel_geholt),
        &"strecke": strecke,
        &"stroemung_offen": stroemung_offen,
        &"gesehen": Array(gesehen),
        &"mutationen_gesehen": Array(mutationen_gesehen),
        &"kalender": kalender,
        &"kalender_tag": kalender_tag,
        &"einstieg": einstieg,
    }


## Baut den Stand aus gespeicherten Daten. Alles wird geprueft und notfalls
## zurechtgebogen: eine beschaedigte Datei darf ein Spiel nicht unspielbar
## machen, und ein veraenderter Stand darf keine unmoeglichen Werte einspeisen.
static func aus_wort(wort: Dictionary) -> KolonieStand:
    var s := KolonieStand.new()
    var roh: Array = wort.get(&"stufen", [])
    for i in mini(roh.size(), s.stufen.size()):
        s.stufen[i] = clampi(int(roh[i]), 0, Kammern.HOECHSTSTUFE)

    var rohe_linien: Array = wort.get(&"linien", [])
    for wert in rohe_linien:
        var i := int(wert)
        if i >= 0 and i < Brutlinien.zahl() and not s.linien.has(i):
            s.linien.append(i)
    s.linie = int(wort.get(&"linie", Brutlinien.Linie.KEINE))
    if not s.linien.has(s.linie):
        s.linie = Brutlinien.Linie.KEINE

    s.naehrstoffe = maxi(0, int(wort.get(&"naehrstoffe", START_NAEHRSTOFF)))
    s.hoechste_welle = clampi(int(wort.get(&"hoechste_welle", 1)), 1, Graben.TIEFSTE)
    s.bestpunkte = maxi(0, int(wort.get(&"bestpunkte", 0)))
    s.beste_kette = maxi(0, int(wort.get(&"beste_kette", 0)))
    s.bau_kammer = int(wort.get(&"bau_kammer", -1))
    if s.bau_kammer < 0 or s.bau_kammer >= Kammern.zahl():
        s.bau_kammer = -1
    s.bau_fertig_um = float(wort.get(&"bau_fertig_um", 0.0))
    s.zuletzt_gesehen = float(wort.get(&"zuletzt_gesehen", 0.0))

    s.tag = int(wort.get(&"tag", 0))
    s.strecke = maxi(0, int(wort.get(&"strecke", 0)))
    s.stroemung_offen = clampi(int(wort.get(&"stroemung_offen", Tagesstroemung.JE_TAG)),
        0, Tagesstroemung.JE_TAG)
    var rohe_mut: Array = wort.get(&"mutationen_gesehen", [])
    for roh_m in rohe_mut:
        var m := int(roh_m)
        if m >= 0 and m < Mutationen.Mutation.size() \
                and not s.mutationen_gesehen.has(m):
            s.mutationen_gesehen.append(m)

    var rohe_arten: Array = wort.get(&"gesehen", [])
    for wert in rohe_arten:
        var a := int(wert)
        if a >= 0 and a < Arten.zahl() and not s.gesehen.has(a):
            s.gesehen.append(a)

    s.kalender = clampi(int(wort.get(&"kalender", 0)), 0, Zuchtkalender.TAGE)
    s.kalender_tag = maxi(0, int(wort.get(&"kalender_tag", 0)))
    s.einstieg = maxi(0, int(wort.get(&"einstieg", 0)))
    var roh_f: Array = wort.get(&"ziel_fortschritt", [])
    for i in mini(roh_f.size(), s.ziel_fortschritt.size()):
        s.ziel_fortschritt[i] = clampi(int(roh_f[i]), 0, Tagesziel.menge(i))
    var roh_g: Array = wort.get(&"ziel_geholt", [])
    for i in mini(roh_g.size(), s.ziel_geholt.size()):
        s.ziel_geholt[i] = clampi(int(roh_g[i]), 0, 1)
    return s
