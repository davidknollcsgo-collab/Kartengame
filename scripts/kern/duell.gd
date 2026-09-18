class_name Duell
extends RefCounted

## **Das Duell, als reine Rechnung.**
##
## Hier steht alles, was ueber Sieg und Niederlage entscheidet - und nichts,
## was mit Zeichnen zu tun hat. Der Grund ist derselbe wie ueberall in diesem
## Haus: was das Bild zeigt und was wirklich zaehlt, muss **dieselbe Zahl**
## sein. Die Buehne fragt `fuehrungsanteil()`, um die Zinnoberlinie zu
## zeichnen, und die Pruefung fragt dieselbe Funktion - eine Fuehrungslinie,
## die anders steht als das Fenster, ist unlernbar.
##
## Kein Szenen-, kein Autoload-Bezug: der Kern laeuft headless durch.

enum Lage {
    RUHE,       ## atmet, wartet auf seinen Einsatz
    ANSATZ,     ## holt aus - die Linie steht im Bild
    OFFEN,      ## pariert und aus der Deckung
    GEFALLEN,
}

## **Was ein Fehlgriff kostet.** Ohne diese Sperre waere die beste Strategie,
## alle vier Achsen dauernd durchzuwischen, bis eine passt - und dann waere
## das Spiel kein Lesen mehr, sondern Ruehren. Lang genug, dass Ruehren
## verliert; kurz genug, dass ein einzelner Fehler nicht die Ronde kostet.
const SPERRE := 0.34

## Wie lange ein Gegner zwischen zwei Ansaetzen durchatmet. Ohne Pause steht
## eine Fuehrungslinie ununterbrochen im Bild, und der Ansatz verliert
## genau das, was ihn lesbar macht: seinen Anfang.
const PAUSE_KURZ := 0.45
const PAUSE_LANG := 1.05

## Wie lang ein Wisch mindestens sein muss, in Bildpunkten. Darunter ist es
## ein Tippen - und ein Tippen ist die Antwort auf den Stoss.
const WISCH_MINDEST := 46.0


## Ein Gegner im Duell.
class Klinge extends RefCounted:
    var art := 0
    var lage := Lage.RUHE
    var uhr := 0.0            ## Sekunden in dieser Lage
    var dauer := 0.0          ## wie lange die Lage dauert
    var linie := 0            ## was gerade im Bild steht
    var wahre_linie := 0      ## was wirklich faellt (Taeuschung!)
    var offene_paraden := 1
    var platz := 0            ## Standort auf der Buehne, von links
    var seite := 1.0          ## -1 links vom Spieler, +1 rechts
    var in_mensur := false    ## steht er ueberhaupt schon im Duell?
    ## **Sein Platz in der Mensur**, nicht auf dem Schirm - null bis
    ## `gleichzeitig - 1`. Der Kern weiss nicht, wo das im Bild liegt; er
    ## weiss nur, dass zwei Gegner nicht auf demselben Platz stehen.
    var stelle := 0
    var zuckt := 0.0          ## rein fuer das Bild: Nachschwingen eines Schlags

    func lebt() -> bool:
        return lage != Lage.GEFALLEN


## Was bei einem Schritt geschehen ist. Die Buehne liest das und macht
## daraus Klang, Beben und Tusche - sie rechnet nichts davon selbst nach.
enum Vorfall { PARIERT, GEFAELLT, GETROFFEN, FEHLGRIFF, TAEUSCHUNG, SCHLAG_LOS }


## Der Zustand eines ganzen Duells.
class Stand extends RefCounted:
    var nummer := 1
    var klingen: Array[Klinge] = []
    var atem := 3
    var atem_voll := 3
    var sperre := 0.0
    var kette := 0
    var beste_kette := 0
    var ehre := 0
    var gefaellt := 0
    var zeit := 0.0
    var gleichzeitig := 1
    ## Aus der Schule, einmal beim Aufbruch gesetzt - im Duell aendert sich
    ## der Stand nicht, und ein Wert, der sich mitten im Kampf verschiebt,
    ## waere nicht mehr zu lernen.
    var lesezeit := 0.0
    var fensterzusatz := 0.0
    var oeffnungsfaktor := 1.0
    var vorfaelle: Array = []

    func lebt() -> bool:
        return atem > 0

    func offen() -> int:
        var n := 0
        for k in klingen:
            if k.lebt():
                n += 1
        return n


## --- Die vier Zahlen, die Bild und Pruefung teilen ---

static func ansatzdauer(art: int, lesezeit: float) -> float:
    return Gegner.ansatz(art) + lesezeit


static func fensterbreite(art: int, zusatz: float) -> float:
    return Gegner.fenster(art) + zusatz


static func oeffnungsdauer(art: int, faktor: float) -> float:
    return Gegner.oeffnung(art) * faktor


## Wie weit der Ansatz fortgeschritten ist, von 0 bis 1. **Das ist die Zahl,
## aus der die Zinnoberlinie ihre Laenge nimmt** - und dieselbe, an der das
## Fenster haengt. Bei 1 faellt der Hieb.
static func fuehrungsanteil(k: Klinge) -> float:
    if k.lage != Lage.ANSATZ or k.dauer <= 0.0:
        return 0.0
    return clampf(k.uhr / k.dauer, 0.0, 1.0)


## Steht dieser Gegner gerade im Fenster? Zweiseitig um den Schlag herum.
static func im_fenster(k: Klinge, stand: Stand) -> bool:
    if k.lage != Lage.ANSATZ:
        return false
    var f := fensterbreite(k.art, stand.fensterzusatz)
    return absf(k.uhr - k.dauer) <= f


## --- Aufbau ---

static func baue(nummer: int, stufen: Dictionary) -> Stand:
    var s := Stand.new()
    s.nummer = nummer
    s.lesezeit = Schule.lesezeit(int(stufen.get(Schule.Halle.AUGE, 0)))
    s.fensterzusatz = Schule.fensterzusatz(
        int(stufen.get(Schule.Halle.HANDGELENK, 0)))
    s.oeffnungsfaktor = Schule.oeffnungsfaktor(
        int(stufen.get(Schule.Halle.SCHNEIDE, 0)))
    s.atem_voll = Schule.atem(int(stufen.get(Schule.Halle.ATEM, 0)))
    s.atem = s.atem_voll
    s.gleichzeitig = Ronde.gleichzeitig(nummer)

    var i := 0
    for art in Ronde.gegner(nummer):
        var k := Klinge.new()
        k.art = art
        k.platz = i
        k.seite = -1.0 if i % 2 == 0 else 1.0
        k.lage = Lage.RUHE
        k.offene_paraden = Gegner.paraden(art)
        # Der erste Ansatz kommt gestaffelt, sonst stehen zwei
        # Fuehrungslinien im selben Augenblick da und niemand hat je
        # gesehen, wie eine anfaengt.
        k.dauer = PAUSE_KURZ + float(i) * 0.38
        s.klingen.append(k)
        i += 1
    _stelle_mensur(s)
    return s


## Wer steht im Duell? Die vordersten `gleichzeitig` Lebenden. Wer faellt,
## macht Platz - und der Naechste tritt vor, statt dass alle von Anfang an
## dastehen.
static func _stelle_mensur(s: Stand) -> void:
    var drin := 0
    for k in s.klingen:
        if not k.lebt():
            continue
        if drin < s.gleichzeitig:
            if not k.in_mensur:
                k.in_mensur = true
                k.lage = Lage.RUHE
                k.uhr = 0.0
                k.dauer = PAUSE_KURZ
            k.stelle = drin
            drin += 1
        else:
            k.in_mensur = false


static func _neue_linie(art: int, ausser: int, rng: RandomNumberGenerator) -> int:
    var moeglich := Gegner.linien_von(art)
    if moeglich.size() <= 1:
        return moeglich[0]
    for _i in 8:
        var l: int = moeglich[rng.randi_range(0, moeglich.size() - 1)]
        if l != ausser:
            return l
    return moeglich[0]


## --- Der Schritt ---

static func schritt(s: Stand, dt: float, rng: RandomNumberGenerator) -> void:
    s.vorfaelle.clear()
    if not s.lebt():
        return
    s.zeit += dt
    s.sperre = maxf(0.0, s.sperre - dt)

    for k in s.klingen:
        if not k.lebt() or not k.in_mensur:
            continue
        k.zuckt = maxf(0.0, k.zuckt - dt)
        k.uhr += dt

        match k.lage:
            Lage.RUHE:
                if k.uhr >= k.dauer:
                    k.lage = Lage.ANSATZ
                    k.uhr = 0.0
                    k.dauer = ansatzdauer(k.art, s.lesezeit)
                    k.wahre_linie = _neue_linie(k.art, -1, rng)
                    # Der Taeuscher zeigt zuerst eine andere.
                    if Gegner.taeuscht(k.art):
                        k.linie = _neue_linie(k.art, k.wahre_linie, rng)
                    else:
                        k.linie = k.wahre_linie

            Lage.ANSATZ:
                # Die Taeuschung faellt mitten im Ansatz - spaet genug, dass
                # die erste Lesung nicht mehr traegt, frueh genug, dass die
                # zweite noch moeglich ist.
                if Gegner.taeuscht(k.art) and k.linie != k.wahre_linie \
                        and k.uhr >= k.dauer * Gegner.TAEUSCH_LAGE:
                    k.linie = k.wahre_linie
                    s.vorfaelle.append([Vorfall.TAEUSCHUNG, k])

                var f := fensterbreite(k.art, s.fensterzusatz)
                if k.uhr > k.dauer + f:
                    # Durchgekommen. Der Hieb sitzt.
                    s.atem -= 1
                    s.kette = 0
                    k.lage = Lage.RUHE
                    k.uhr = 0.0
                    k.dauer = PAUSE_LANG
                    k.zuckt = 0.22
                    s.vorfaelle.append([Vorfall.GETROFFEN, k])

            Lage.OFFEN:
                if k.uhr >= k.dauer:
                    k.lage = Lage.RUHE
                    k.uhr = 0.0
                    k.dauer = PAUSE_KURZ
                    # **Seine Deckung schliesst sich wieder ganz.** Ohne
                    # diese Zeile braucht der Eisenarm seine zwei Paraden
                    # genau einmal und danach nie wieder - seine ganze
                    # Eigenart waere eine Eigenart der ersten Begegnung.
                    k.offene_paraden = Gegner.paraden(k.art)
                    # Wer eine Oeffnung verstreichen laesst, verliert die
                    # Kette. Sonst kostet Zoegern nichts, und ein Spiel, in
                    # dem Zoegern nichts kostet, hat keine Uhr.
                    s.kette = 0

    _stelle_mensur(s)


## --- Die Antwort des Spielers ---
##
## `wisch` ist der Vektor vom Anfang zum Ende der Fingerbewegung. Ist er
## kuerzer als `WISCH_MINDEST`, gilt es als Tippen - und Tippen ist die
## Antwort auf den Stoss, nichts sonst.

static func antworte(s: Stand, wisch: Vector2) -> void:
    if not s.lebt():
        return
    if s.sperre > 0.0:
        return

    var getippt := wisch.length() < WISCH_MINDEST

    # **Der Daumen zielt nach Gefahr.** Was zuerst faellt, wird zuerst
    # beantwortet - erst wenn nichts draengt, wird ein Offener genommen.
    var ziel: Klinge = null
    var naechster := 9999.0
    for k in s.klingen:
        if not k.lebt() or not k.in_mensur:
            continue
        if im_fenster(k, s):
            var rest := absf(k.uhr - k.dauer)
            if rest < naechster:
                naechster = rest
                ziel = k

    if ziel != null:
        var passt := false
        if Schnitte.ist_stoss(ziel.wahre_linie):
            passt = getippt
        elif not getippt:
            # **Die naechste Achse, keine Schwelle.** Die Begruendung steht
            # bei `Schnitte.naechste_achse()`: eine Schwelle hat einen Rand,
            # und ein Rand ist entweder doppeldeutig oder tot.
            passt = Schnitte.naechste_achse(wisch) == ziel.wahre_linie
        if passt:
            _pariere(s, ziel)
        else:
            _fehlgriff(s)
        return

    # Nichts draengt: ein Offener wird gefaellt. Ein Tippen toetet nicht -
    # es ist ein Schlag auf die Klinge, kein Schnitt.
    var beute: Klinge = null
    var knappste := 9999.0
    for k in s.klingen:
        if not k.lebt() or not k.in_mensur or k.lage != Lage.OFFEN:
            continue
        var rest := k.dauer - k.uhr
        if rest < knappste:
            knappste = rest
            beute = k
    if beute != null and not getippt:
        _faelle(s, beute)
        return

    _fehlgriff(s)


static func _pariere(s: Stand, k: Klinge) -> void:
    k.offene_paraden -= 1
    k.zuckt = 0.26
    s.kette += 1
    s.beste_kette = maxi(s.beste_kette, s.kette)
    s.vorfaelle.append([Vorfall.PARIERT, k])
    if k.offene_paraden > 0:
        # Noch nicht durch: er faengt sofort neu an, mit frischer Linie.
        k.lage = Lage.RUHE
        k.uhr = 0.0
        k.dauer = PAUSE_KURZ * 0.6
        return
    k.lage = Lage.OFFEN
    k.uhr = 0.0
    k.dauer = oeffnungsdauer(k.art, s.oeffnungsfaktor)


static func _faelle(s: Stand, k: Klinge) -> void:
    k.lage = Lage.GEFALLEN
    # **Er raeumt seinen Platz sofort.** Sonst steht der Nachruecker in
    # derselben Stelle wie der Sterbende, und im Bild faellt einer durch
    # den anderen hindurch.
    k.in_mensur = false
    k.zuckt = 0.4
    s.gefaellt += 1
    s.kette += 1
    s.beste_kette = maxi(s.beste_kette, s.kette)
    s.ehre += Ronde.wert_von(k.art, s.nummer)
    s.vorfaelle.append([Vorfall.GEFAELLT, k])
    _stelle_mensur(s)


static func _fehlgriff(s: Stand) -> void:
    s.sperre = SPERRE
    s.kette = 0
    s.vorfaelle.append([Vorfall.FEHLGRIFF, null])


## Ist die Ronde geraeumt?
static func geraeumt(s: Stand) -> bool:
    for k in s.klingen:
        if k.lebt():
            return false
    return true
