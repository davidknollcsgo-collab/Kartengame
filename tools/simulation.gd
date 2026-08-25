class_name Simulation
extends RefCounted

## Ein Spieler, der die Schlundwache vernuenftig spielt - als Rechnung.
##
## **Zusicherung, die nicht aufgeweicht werden darf:** Wellenpruefer und
## Balance-Durchlauf benutzen diesen einen Simulator. Bei HYPHA hatten Sucher
## und Loesbarkeitspruefer getrennte Rechnungen, verschiedene Aufloesungen und
## kamen zu verschiedenen Ergebnissen. Genau das darf hier nicht wieder
## passieren.
##
## Der simulierte Spieler ist **absichtlich schlechter als ein guter Mensch**:
## er zielt immer nur auf den vordersten Raeuber, fasst nie zwei zugleich und
## fuehrt den Kegel nicht vor. Was er schafft, schafft ein Mensch auch.

const TAKT := 1.0 / 30.0
const HOECHSTDAUER := 200.0


class Ergebnis extends RefCounted:
    var welle: int = 0
    var ueberstanden: bool = false
    var brut_vorher: int = 0
    var brut_nachher: int = 0
    var durchgelassen: int = 0
    var dauer: float = 0.0
    var naehrstoffe: int = 0
    var polypen: int = 0

    func verlust() -> int:
        return brut_vorher - brut_nachher


class Zustand extends RefCounted:
    ## Ausbaustand des Waechters. 1.0 heisst Grundwerte.
    var leistung_faktor: float = 1.0
    var reichweite_faktor: float = 1.0
    var winkel_faktor: float = 1.0
    var ziele_zusatz: int = 0

    var brut: int = Graben.BRUT_LEBEN
    var naehrstoffe: int = 0
    var polypen: Array[Vector2] = []

    func leistung() -> float:
        return Graben.LEISTUNG * leistung_faktor

    func reichweite() -> float:
        return Graben.REICHWEITE * reichweite_faktor

    func halbwinkel() -> float:
        return Graben.HALBWINKEL * winkel_faktor

    func ziele() -> int:
        return Graben.ZIELE + ziele_zusatz


class Tier extends RefCounted:
    var art: int = 0
    var eintritt: float = 0.0
    var x: float = 0.0
    var phase: float = 0.0
    var leben: float = 0.0
    var lebendig: bool = true
    var angekommen: bool = false

    func ort(zeit: float) -> Vector2:
        var seit := zeit - eintritt
        if seit < 0.0:
            return Vector2(x, Graben.EINTRITT_Y)
        var a := Arten.art(art)
        return Schlund.bahn(Vector2(x, Graben.EINTRITT_Y), Graben.BRUT_Y,
            a[&"tempo"], a[&"schlaengel"], a[&"takt"], phase, seit)


## Baut Wehrpolypen, solange Naehrstoffe reichen. Genau das tut ein Spieler
## zwischen zwei Wellen, und der Simulator muss es tun, sonst misst er ein
## anderes Spiel.
static func baue_polypen(z: Zustand) -> void:
    while z.polypen.size() < Graben.NISCHEN.size():
        var preis := Graben.polyp_kosten(z.polypen.size())
        if z.naehrstoffe < preis:
            return
        z.naehrstoffe -= preis
        z.polypen.append(Graben.NISCHEN[z.polypen.size()])


## Eine Welle durchrechnen. `z` wird dabei fortgeschrieben.
static func welle(nummer: int, z: Zustand) -> Ergebnis:
    var e := Ergebnis.new()
    e.welle = nummer
    e.brut_vorher = z.brut

    var tiere: Array[Tier] = []
    for a in Wellen.auftritte(nummer):
        var t := Tier.new()
        t.art = a[&"art"]
        t.eintritt = a[&"zeit"]
        t.x = a[&"x"]
        t.phase = a[&"phase"]
        t.leben = Wellen.leben_in(t.art, nummer)
        tiere.append(t)

    var richtung := Vector2.UP
    var zeit := 0.0
    var offen := tiere.size()

    while offen > 0 and z.brut > 0 and zeit < HOECHSTDAUER:
        zeit += TAKT

        # 1. Zielwahl: der vorderste erreichbare Raeuber.
        var ziel: Tier = null
        var beste := -INF
        for t in tiere:
            if not t.lebendig or zeit < t.eintritt:
                continue
            var p := t.ort(zeit)
            if p.distance_to(Graben.WAECHTER) > z.reichweite():
                continue
            if p.y > beste:
                beste = p.y
                ziel = t
        if ziel == null:
            for t in tiere:
                if not t.lebendig or zeit < t.eintritt:
                    continue
                var p := t.ort(zeit)
                if p.y > beste:
                    beste = p.y
                    ziel = t

        # 2. Kegel nachfuehren - mit derselben Drehgrenze wie im Spiel.
        if ziel != null:
            var soll := Schlund.zielrichtung(Graben.WAECHTER, ziel.ort(zeit), richtung)
            richtung = Schlund.gedreht(richtung, soll, Graben.DREHTEMPO, TAKT)

        # 3. Wer steht wie hell im Licht? Erst danach entscheidet
        #    `Schlund.brennende()`, wen der Kegel tatsaechlich fasst - genau so
        #    macht es auch das Spiel.
        var lebende: Array[Tier] = []
        var orte: Array[Vector2] = []
        var hell := PackedFloat32Array()
        for t in tiere:
            if not t.lebendig or zeit < t.eintritt:
                continue
            var p := t.ort(zeit)
            lebende.append(t)
            orte.append(p)
            hell.append(Schlund.beleuchtung(Graben.WAECHTER, richtung,
                z.halbwinkel(), z.reichweite(), p))

        for i in Schlund.brennende(hell, z.ziele()):
            lebende[i].leben -= Schlund.schaden_je_sekunde(z.leistung(), hell[i]) * TAKT

        # 4. Polypen. Jeder greift ein Ziel in seiner Reichweite an.
        for n in z.polypen:
            for i in lebende.size():
                if lebende[i].leben > 0.0 and orte[i].distance_to(n) <= Graben.POLYP_REICHWEITE:
                    lebende[i].leben -= Graben.POLYP_LEISTUNG * TAKT
                    break

        # 5. Tote zaehlen, Ankunft an der Brut abrechnen.
        for i in lebende.size():
            var t := lebende[i]
            if t.leben <= 0.0:
                t.lebendig = false
                offen -= 1
                z.naehrstoffe += Arten.wert(t.art)
            elif orte[i].y >= Graben.BRUT_Y - 0.5:
                t.lebendig = false
                t.angekommen = true
                offen -= 1
                e.durchgelassen += 1
                z.brut = maxi(0, z.brut - Arten.wucht(t.art))

    e.dauer = zeit
    e.brut_nachher = z.brut
    e.ueberstanden = z.brut > 0
    e.naehrstoffe = z.naehrstoffe
    e.polypen = z.polypen.size()
    return e


## Setzt den Waechter auf den Koloniestand, den `Ausbau` fuer Welle `nummer`
## vorsieht. `verstaerkung` weicht davon absichtlich ab - damit laesst sich
## pruefen, wieviel Spielraum ueber oder unter der Vorgabe noch traegt.
static func stelle_ein(z: Zustand, nummer: int, verstaerkung := 1.0) -> void:
    z.leistung_faktor = Ausbau.leistung_faktor(nummer) * verstaerkung
    z.reichweite_faktor = Ausbau.reichweite_faktor(nummer)
    z.winkel_faktor = Ausbau.winkel_faktor(nummer)
    z.ziele_zusatz = Ausbau.ziele(nummer) - Graben.ZIELE


## Eine ganze Sitzung: `Graben.WELLEN_JE_SITZUNG` Wellen ab `erste`.
##
## Die Brut startet voll, Polypen werden waehrend der Sitzung aus dem verdient
## Naehrstoff gebaut. Beides entspricht dem Spiel: der Koloniestand bleibt,
## die Polypen einer Sitzung nicht.
static func sitzung(erste: int, verstaerkung := 1.0) -> Array[Ergebnis]:
    var z := Zustand.new()
    var liste: Array[Ergebnis] = []
    for i in Graben.WELLEN_JE_SITZUNG:
        var nummer := erste + i
        stelle_ein(z, nummer, verstaerkung)
        baue_polypen(z)
        var e := welle(nummer, z)
        liste.append(e)
        if not e.ueberstanden:
            break
    return liste
