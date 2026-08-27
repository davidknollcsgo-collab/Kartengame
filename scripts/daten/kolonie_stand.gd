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
var naehrstoffe := START_NAEHRSTOFF
var hoechste_welle := 1

## Laufender Bau: -1 heisst keiner. `bau_fertig_um` ist Systemzeit in Sekunden.
var bau_kammer := -1
var bau_fertig_um := 0.0

## Wann der Spieler zuletzt da war - Grundlage des Offline-Ertrags.
var zuletzt_gesehen := 0.0


func _init() -> void:
    stufen.resize(Kammern.zahl())
    stufen.fill(0)


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
    return Kammern.leistung_faktor(stufe(Kammern.Kammer.LEUCHTORGAN))


func ziele() -> int:
    return Kammern.ziele(stufe(Kammern.Kammer.LEUCHTORGAN))


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
        &"bau_kammer": bau_kammer,
        &"bau_fertig_um": bau_fertig_um,
        &"zuletzt_gesehen": zuletzt_gesehen,
    }


## Baut den Stand aus gespeicherten Daten. Alles wird geprueft und notfalls
## zurechtgebogen: eine beschaedigte Datei darf ein Spiel nicht unspielbar
## machen, und ein veraenderter Stand darf keine unmoeglichen Werte einspeisen.
static func aus_wort(wort: Dictionary) -> KolonieStand:
    var s := KolonieStand.new()
    var roh: Array = wort.get(&"stufen", [])
    for i in mini(roh.size(), s.stufen.size()):
        s.stufen[i] = clampi(int(roh[i]), 0, Kammern.HOECHSTSTUFE)

    s.naehrstoffe = maxi(0, int(wort.get(&"naehrstoffe", START_NAEHRSTOFF)))
    s.hoechste_welle = clampi(int(wort.get(&"hoechste_welle", 1)), 1, Graben.WELLEN_GESAMT)
    s.bau_kammer = int(wort.get(&"bau_kammer", -1))
    if s.bau_kammer < 0 or s.bau_kammer >= Kammern.zahl():
        s.bau_kammer = -1
    s.bau_fertig_um = float(wort.get(&"bau_fertig_um", 0.0))
    s.zuletzt_gesehen = float(wort.get(&"zuletzt_gesehen", 0.0))
    return s
