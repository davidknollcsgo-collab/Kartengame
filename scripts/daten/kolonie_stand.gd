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
        return "Es wird schon gegraben"
    if am_deckel(kammer):
        if kammer == Kammern.Kammer.TIEFENSCHACHT:
            return "Tiefster Punkt erreicht"
        return "Der Tiefenschacht muss tiefer"
    var fehlt := preis(kammer) - naehrstoffe
    if fehlt > 0:
        return "Es fehlen %d Naehrstoff" % fehlt
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


# --- Brutlinien ------------------------------------------------------------

func hat_linie(index: int) -> bool:
    return linien.has(index)


## Warum sich eine Linie gerade nicht zuechten laesst. Leer heisst: sie geht.
func linie_hindernis(index: int) -> String:
    if hat_linie(index):
        return "Bereits gezuechtet"
    var davor := Brutlinien.voraussetzung(index)
    if not hat_linie(davor):
        return "Erst %s zuechten" % Brutlinien.name_von(davor)
    var fehlt := Brutlinien.kosten(index) - naehrstoffe
    if fehlt > 0:
        return "Es fehlen %d Naehrstoff" % fehlt
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
func ernte_offline(jetzt: float) -> int:
    if zuletzt_gesehen <= 0.0:
        zuletzt_gesehen = jetzt
        return 0
    var stunden := clampf((jetzt - zuletzt_gesehen) / 3600.0, 0.0, OFFLINE_DECKEL_STUNDEN)
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
    return Kammern.reichweite_faktor(stufe(Kammern.Kammer.LEUCHTORGAN))


func winkel_faktor() -> float:
    return Kammern.winkel_faktor(stufe(Kammern.Kammer.LEUCHTORGAN))


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
        &"linien": Array(linien),
        &"linie": linie,
        &"bau_kammer": bau_kammer,
        &"bau_fertig_um": bau_fertig_um,
        &"zuletzt_gesehen": zuletzt_gesehen,
        &"tag": tag,
        &"ziel_fortschritt": Array(ziel_fortschritt),
        &"ziel_geholt": Array(ziel_geholt),
        &"strecke": strecke,
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
    s.hoechste_welle = clampi(int(wort.get(&"hoechste_welle", 1)), 1, Graben.WELLEN_GESAMT)
    s.bau_kammer = int(wort.get(&"bau_kammer", -1))
    if s.bau_kammer < 0 or s.bau_kammer >= Kammern.zahl():
        s.bau_kammer = -1
    s.bau_fertig_um = float(wort.get(&"bau_fertig_um", 0.0))
    s.zuletzt_gesehen = float(wort.get(&"zuletzt_gesehen", 0.0))

    s.tag = int(wort.get(&"tag", 0))
    s.strecke = maxi(0, int(wort.get(&"strecke", 0)))
    var roh_f: Array = wort.get(&"ziel_fortschritt", [])
    for i in mini(roh_f.size(), s.ziel_fortschritt.size()):
        s.ziel_fortschritt[i] = clampi(int(roh_f[i]), 0, Tagesziel.menge(i))
    var roh_g: Array = wort.get(&"ziel_geholt", [])
    for i in mini(roh_g.size(), s.ziel_geholt.size()):
        s.ziel_geholt[i] = clampi(int(roh_g[i]), 0, 1)
    return s
