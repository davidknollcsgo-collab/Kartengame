class_name Simulation
extends RefCounted

## Ein Spieler, der den Rundumlauf vernuenftig faehrt - als Rechnung.
##
## **Zusicherung, die nicht aufgeweicht werden darf:** Wellenpruefer und
## Kolonielauf benutzen diesen einen Simulator. Bei HYPHA hatten Sucher und
## Loesbarkeitspruefer getrennte Rechnungen, verschiedene Aufloesungen und
## kamen zu verschiedenen Ergebnissen. Genau das darf hier nicht wieder
## passieren.
##
## **Er hat die Schleife gewechselt.** Bis September 2026 rechnete er die
## Schlundwache nach: ein fester Waechter, Raeuber, die von oben sinken,
## Wehrpolypen in Nischen. Die Schleife ist geloescht; ein Pruefer, der ein
## Spiel misst, das es nicht gibt, ist schlimmer als keiner - er meldet
## gruen und sagt nichts ueber das, was gespielt wird.
##
## Gerechnet wird deshalb jetzt eine Fahrt, und zwar mit **denselben
## Funktionen wie die Szene**: `Rundum.schritt()` bewegt die Tiere,
## `Rundum.begleiter_ziel()` und `Rundum.naechstes_ziel()` fuehren die
## Begleiter, `Schlund.beleuchtung()`/`schaden_an()`/`brennende()` machen den
## Schaden. Der einzige erlaubte Unterschied ist, wer zielt: dort ein Finger,
## hier eine Rechnung.
##
## Der simulierte Fahrer ist **absichtlich schlechter als ein guter Mensch**:
##
##   * Er **faehrt nicht**. Das Boot steht, und die Raeuber kommen zu ihm.
##     Ein Mensch weicht aus, zieht einen Pulk auseinander und holt sich
##     Nachzuegler; all das geht als Reserve in das Ergebnis ein.
##   * Er zielt immer nur auf das naechste Tier und fuehrt den Kegel nicht
##     vor.
##   * Er loest das Stosslicht aus, sobald es geladen ist, statt es fuer den
##     Pulk aufzuheben.
##
## Was er schafft, schafft ein Mensch auch. Gemessen wird eine **untere
## Schranke**, und sie wird auch so gemeldet.
##
## Reine Rechnung: keine Szene, kein Autoload. Deshalb stehen die Zahlen, die
## beide Seiten brauchen, in `Rundum` und nicht in `rundlauf.gd`.

const TAKT := 1.0 / 30.0

## **Laenger als im Schlund.** Dort lief eine Welle allein; hier laufen
## `Rundum.DICHTE` ineinander, also dauert eine Runde ein Mehrfaches.
const HOECHSTDAUER := 300.0


class Ergebnis extends RefCounted:
    var welle: int = 0
    var ueberstanden: bool = false
    var huelle_vorher: int = 0
    var huelle_nachher: int = 0

    ## Wie oft ein Raeuber das Boot erreicht hat. Nicht dasselbe wie der
    ## Huellenverlust: ein Leitwesen kostet mehr als ein Schleier.
    var treffer: int = 0
    var dauer: float = 0.0
    var naehrstoffe: int = 0

    func verlust() -> int:
        return huelle_vorher - huelle_nachher


class Zustand extends RefCounted:
    ## Ausbaustand des Bootes. 1.0 heisst Grundwerte.
    var leistung_faktor: float = 1.0
    var reichweite_faktor: float = 1.0
    var winkel_faktor: float = 1.0
    var ziele_zusatz: int = 0

    ## Wieviele Begleiter mitfahren. Aus derselben Kammerkurve wie im Spiel.
    var begleiter_zahl: int = 1

    ## **Die Huelle ist die Brut.** Wer faehrt, hat kein Gelege mehr zu
    ## verteidigen; `Arten.wucht()` sagt weiter, was ein Durchkommen kostet,
    ## und die Brutkammer hebt weiter die Zahl der Fehler, die man uebersteht.
    var huelle: int = Graben.BRUT_LEBEN
    var huelle_voll: int = Graben.BRUT_LEBEN
    var naehrstoffe: int = 0

    ## **Der Bruchteil wird mitgenommen, nicht weggerundet.**
    ##
    ## `Wellen.wert_in()` hat eine Untergrenze von eins; geteilt durch
    ## `Rundum.DICHTE` sind das 0.33 je Tier. Wer je Tier rundet, bekommt in
    ## den ersten zwanzig Wellen **null** Naehrstoff - und der Kolonielauf
    ## meldet dann eine Wand, die es nicht gibt. Das Spiel fuehrt denselben
    ## Rest in `rundlauf.gd::_lohne()`.
    var lohn_rest: float = 0.0

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

    ## Aus welcher Welle - dieselbe Begruendung wie bei `Raeuber.welle`:
    ## Mutationen gehoeren dem Paar aus Art und Welle, nicht der Art allein.
    var welle: int = 1
    var eintritt: float = 0.0
    var phase: float = 0.0
    var leben: float = 0.0
    var lebendig: bool = true
    var lauert: bool = false
    var ort := Vector2.ZERO

    ## Wie lange dieses Tier schon unterwegs ist. Der Weg wird Schritt fuer
    ## Schritt gerechnet, weil das Ziel sich bewegen kann - also braucht das
    ## Pendeln eine eigene Uhr.
    var alter: float = 0.0

    ## Von welchem Stosslicht es schon getroffen wurde - dieselbe Marke wie
    ## `Raeuber.stoss_nr` im Spiel, aus demselben Grund.
    var stoss_nr: int = -1


## Die Tiere einer Fahrtrunde aufstellen.
##
## **Wort fuer Wort wie `rundlauf.gd::_bereite_welle_vor()`**, samt Saat.
## Eine andere Reihenfolge oder ein anderer Wurf hiesse: der Pruefer sieht
## eine andere Welle als der Spieler. Der einzige Unterschied ist, dass das
## Boot hier im Ursprung steht.
static func stelle_auf(nummer: int) -> Array[Tier]:
    var tiere: Array[Tier] = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x52554e44 + nummer
    var eintraege: Array[Dictionary] = []
    for versatz in Rundum.DICHTE:
        for e in Wellen.auftritte(nummer + versatz):
            var kopie := e.duplicate()
            kopie[&"zeit"] = float(e[&"zeit"]) \
                + float(versatz) * rng.randf_range(0.4, 1.6)
            eintraege.append(kopie)
    for eintrag in eintraege:
        var t := Tier.new()
        t.art = int(eintrag[&"art"])
        t.welle = nummer
        t.eintritt = float(eintrag[&"zeit"])
        t.phase = float(eintrag[&"phase"])
        t.leben = Wellen.leben_in(t.art, nummer)
        var anteil := (float(eintrag[&"x"]) / Graben.EINTRITT_SEITE) * 0.5 + 0.5
        var winkel := anteil * TAU + rng.randf_range(-0.12, 0.12)
        t.ort = Rundum.eintritt(winkel)
        if not Arten.ist_leitwesen(t.art) \
                and rng.randf() < Rundum.LAUER_ANTEIL:
            t.lauert = true
            t.eintritt = 0.0
            t.ort = Rundum.gehalten(Vector2.RIGHT.rotated(
                rng.randf_range(0.0, TAU))
                * rng.randf_range(Rundum.LAUER_NAH, Rundum.LAUER_WEIT), 60.0)
        tiere.append(t)
    return tiere


## Eine Fahrtrunde durchrechnen: `Rundum.DICHTE` Wellen ab `nummer`,
## ineinander. `z` wird dabei fortgeschrieben.
static func welle(nummer: int, z: Zustand) -> Ergebnis:
    var e := Ergebnis.new()
    e.welle = nummer
    e.huelle_vorher = z.huelle

    var tiere := stelle_auf(nummer)
    var boot := Vector2.ZERO
    var blick := Vector2.UP
    var zahl := maxi(1, z.begleiter_zahl)
    var begleiter: Array[Vector2] = []
    for i in zahl:
        begleiter.append(Rundum.begleiter_ziel(i, zahl,
            boot, blick, Rundum.BEGLEITER_ABSTAND))

    var zeit := 0.0
    var offen := tiere.size()

    # **Der simulierte Fahrer benutzt das Stosslicht, sobald es geladen ist.**
    #
    # Das muss er, denn `Ausbau.durchsatz()` rechnet es ein und
    # `Wellen.staerke()` faellt daraus. Ein Pruefer, der eine Leistung nicht
    # abruft, die die Kurve voraussetzt, misst ein Spiel, das schwerer ist als
    # das gespielte - und meldet Waende, die es nicht gibt.
    var stoss_kuehl := 0.0
    var stoss_weit := -1.0
    var stoss_nr := 0

    while offen > 0 and z.huelle > 0 and zeit < HOECHSTDAUER:
        zeit += TAKT

        # 1. Bewegen. Wer noch nicht eingetreten ist, wartet; wer lauert,
        #    liegt still, bis das Boot nah genug kommt.
        var wach := 0
        for t in tiere:
            if not t.lebendig:
                continue
            if zeit < t.eintritt:
                continue
            if t.lauert:
                if t.ort.distance_to(boot) <= Rundum.WECK_RADIUS:
                    t.lauert = false
                else:
                    continue
            wach += 1
            t.alter += TAKT
            var a := Arten.art(t.art)
            t.ort = Rundum.schritt(t.ort, boot,
                Wellen.tempo_in(t.art, t.welle), a[&"schlaengel"],
                a[&"takt"], t.phase, t.alter, TAKT,
                Wellen.drift_in(t.art, t.welle))

        # **Wenn sonst nichts mehr steht, erwachen die Uebrigen.** Sonst
        # haengt die Runde an einem Lauerer, der vierzehnhundert Einheiten
        # entfernt im Dunkeln liegt - im Spiel faehrt der Spieler die Karte
        # ab, hier liefe die Uhr bis zum Deckel.
        if wach == 0:
            for t in tiere:
                if t.lebendig and t.lauert and zeit >= t.eintritt:
                    t.lauert = false

        # 2. Zielwahl und Kegel. Der Fahrer nimmt das naechste wache Tier.
        #
        #    Die Stroemung des Abschnitts treibt den Kegel ab. Er haelt
        #    dagegen, indem er die Ablenkung von seinem Zielwinkel abzieht -
        #    aber die Drehgrenze bleibt, also kostet ihn eine schnell
        #    wechselnde Stroemung Zeit. Genau das soll sie.
        var lebende: Array[Tier] = []
        var orte: Array[Vector2] = []
        for t in tiere:
            if t.lebendig and not t.lauert and zeit >= t.eintritt:
                lebende.append(t)
                orte.append(t.ort)

        var abtrieb := Regeln.stroemung(nummer, zeit)
        var n := Rundum.naechstes_ziel(boot, orte, INF)
        if n >= 0:
            var soll := Schlund.zielrichtung(boot, orte[n], blick)
            blick = Schlund.gedreht(blick, soll.rotated(-abtrieb),
                Graben.DREHTEMPO, TAKT)
        var wirksam := blick.rotated(abtrieb)
        var schein := Regeln.helligkeit(nummer, zeit)
        var rand_kern := Regeln.rand_kern(nummer)
        var tiefe_kern := Regeln.tiefe_kern(nummer)

        # 3. Wer steht wie hell im Licht? Erst danach entscheidet
        #    `Schlund.brennende()`, wen der Kegel tatsaechlich fasst - genau
        #    so macht es auch das Spiel.
        var hell := PackedFloat32Array()
        for i in lebende.size():
            hell.append(Schlund.beleuchtung(boot, wirksam, z.halbwinkel(),
                z.reichweite(), orte[i], rand_kern, tiefe_kern) * schein)

        # Dieselbe Reihenfolge wie im Spiel: erst ausrechnen, was jedes Tier
        # abbekaeme, dann danach auswaehlen. Wer hier nach Helligkeit
        # auswaehlt und dort nach Wirkung, prueft ein anderes Spiel.
        var wirkung := PackedFloat32Array()
        wirkung.resize(lebende.size())
        for i in lebende.size():
            wirkung[i] = Schlund.schaden_an(z.leistung(), hell[i],
                Wellen.panzer_in(lebende[i].art, nummer),
                Wellen.mindest_licht_in(lebende[i].art, nummer),
                Wellen.hoechst_licht_in(lebende[i].art, nummer))

        for i in Schlund.brennende(wirkung, z.ziele()):
            lebende[i].leben -= wirkung[i] * TAKT

        # 3b. Das Stosslicht. Derselbe Ring wie im Spiel: er laeuft nach
        #     aussen und trifft jedes Tier genau einmal, mit derselben
        #     `Schlund.schaden_an()` bei voller Helligkeit.
        stoss_kuehl = maxf(0.0, stoss_kuehl - TAKT)
        if stoss_weit < 0.0 and stoss_kuehl <= 0.0:
            stoss_kuehl = Graben.STOSS_ABKUEHLUNG
            stoss_weit = 0.0
            stoss_nr += 1
        if stoss_weit >= 0.0:
            var vorher := stoss_weit
            stoss_weit += Graben.STOSS_TEMPO * TAKT
            for i in lebende.size():
                var tt := lebende[i]
                if tt.stoss_nr == stoss_nr or tt.leben <= 0.0:
                    continue
                var weg := orte[i].distance_to(boot)
                if weg > stoss_weit or weg <= vorher:
                    continue
                tt.stoss_nr = stoss_nr
                tt.leben -= Schlund.schaden_an(z.leistung(), 1.0,
                    Wellen.panzer_in(tt.art, nummer),
                    Wellen.mindest_licht_in(tt.art, nummer),
                    Wellen.hoechst_licht_in(tt.art, nummer)) * Graben.STOSS_WERT
            if stoss_weit > z.reichweite():
                stoss_weit = -1.0

        # 4. Die Begleiter. Jeder nimmt das naechste Tier in seiner
        #    Reichweite - dieselbe Wahl wie im Spiel, aus derselben Funktion.
        for i in begleiter.size():
            # Ohne Traegheit: das Boot steht, also stehen sie auf ihrem Platz.
            begleiter[i] = Rundum.begleiter_ziel(i, begleiter.size(), boot,
                blick, Rundum.BEGLEITER_ABSTAND)
            var b := Rundum.naechstes_ziel(begleiter[i], orte,
                Rundum.BEGLEITER_REICHWEITE)
            if b < 0:
                continue
            # **Der Panzer gilt auch hier** - genau das macht ihn aus: ein
            # Begleiter kratzt an einer Schildkoralle kaum noch.
            lebende[b].leben -= maxf(0.0, Graben.POLYP_LEISTUNG
                - Wellen.panzer_in(lebende[b].art, nummer)) * TAKT

        # 5. Tote zaehlen, Bisse abrechnen.
        #
        #    **Der Naehrstoff wird durch `DICHTE` geteilt**, genau wie im
        #    Spiel: hier laufen drei Wellen ineinander, also liegen dreimal
        #    so viele Koerper im Feld. Wer jeden voll bezahlte, zahlte fuer
        #    eine Welle den dreifachen Ertrag - und Einkommen und Kosten sind
        #    aneinander gekoppelt.
        for i in lebende.size():
            var t := lebende[i]
            if t.leben <= 0.0:
                t.lebendig = false
                offen -= 1
                z.lohn_rest += float(Wellen.wert_in(t.art, nummer)) \
                    / float(Rundum.DICHTE)
                var lohn := int(floor(z.lohn_rest))
                if lohn > 0:
                    z.lohn_rest -= float(lohn)
                    z.naehrstoffe += lohn
            elif t.ort.distance_to(boot) < Rundum.BOOT_RADIUS \
                    + Wellen.radius_in(t.art, nummer) * 0.5:
                # Zurueckwerfen statt entfernen: ein Raeuber, der beim
                # Treffer verschwindet, macht aus dem Boot eine Wand.
                e.treffer += 1
                z.huelle = maxi(0, z.huelle - Arten.wucht(t.art))
                t.ort = boot + (t.ort - boot).normalized() \
                    * (Rundum.BOOT_RADIUS + 190.0)
                t.eintritt = zeit + Rundum.BISS_SPERRE
                t.alter = 0.0

    e.dauer = zeit
    e.huelle_nachher = z.huelle
    e.ueberstanden = z.huelle > 0
    e.naehrstoffe = z.naehrstoffe
    return e


## Setzt das Boot auf den Koloniestand, den `Ausbau` fuer Welle `nummer`
## vorsieht. `verstaerkung` weicht davon absichtlich ab - damit laesst sich
## pruefen, wieviel Spielraum ueber oder unter der Vorgabe noch traegt.
static func stelle_ein(z: Zustand, nummer: int, verstaerkung := 1.0) -> void:
    z.leistung_faktor = Ausbau.leistung_faktor(nummer) * verstaerkung
    z.reichweite_faktor = Ausbau.reichweite_faktor(nummer)
    z.winkel_faktor = Ausbau.winkel_faktor(nummer)
    z.ziele_zusatz = Ausbau.ziele(nummer) - Graben.ZIELE
    z.begleiter_zahl = Ausbau.begleiter(nummer)


## Eine ganze Fahrt: `Graben.WELLEN_JE_SITZUNG` Runden ab `erste`.
##
## Die Huelle startet voll und haelt ueber die ganze Fahrt - das entspricht
## dem Spiel: der Koloniestand bleibt, die Huelle einer Fahrt nicht.
static func sitzung(erste: int, verstaerkung := 1.0) -> Array[Ergebnis]:
    var z := Zustand.new()
    var liste: Array[Ergebnis] = []
    for i in Graben.WELLEN_JE_SITZUNG:
        var nummer := erste + i
        stelle_ein(z, nummer, verstaerkung)
        var e := welle(nummer, z)
        liste.append(e)
        if not e.ueberstanden:
            break
    return liste
