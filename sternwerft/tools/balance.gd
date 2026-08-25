## Balancing-Bericht: godot --headless --path . --script tools/balance.gd
##
## Kein Test, sondern eine Messung. Spielt die Station mit einer vernuenftigen
## Strategie durch und meldet, wann welcher Abschnitt erreicht wird. Die
## entscheidende Zahl ist die Zeit bis zum ersten Prestige: dauert sie zu
## lange, sieht ein Spieler die Kernmechanik nie; geht sie zu schnell, verliert
## der Aufbau seinen Reiz.
extends SceneTree

## Simulationsschritt in Sekunden.
const DT := 1.0

## Laenge des Durchlaufs.
const DAUER := 48.0 * 3600.0


func _init() -> void:
    print("── Balancing-Bericht ──────────────────────────")
    _durchlauf()
    print("───────────────────────────────────────────────")
    quit(0)


func _durchlauf() -> void:
    var st: Node = load("res://scripts/autoload/spielstand.gd").new()
    st._ready()

    var erstkauf: Array[float] = []
    erstkauf.resize(Modul.ANZAHL)
    erstkauf.fill(-1.0)
    var erstes_prestige := -1.0
    var berichtet := {}

    var t := 0.0
    while t < DAUER:
        t += DT
        st.gutschrift(st.rate() * DT)

        # In den ersten Minuten tippt ein Spieler noch selbst - ohne das
        # kaeme die Station bei 0.1 Plasma pro Sekunde kaum in Gang.
        if t < 180.0 and fmod(t, 2.0) < DT:
            st.manuell_sammeln()

        _kaufe_bestes(st)

        for i in Modul.ANZAHL:
            if erstkauf[i] < 0.0 and st.bestand[i] > 0:
                erstkauf[i] = t
        if erstes_prestige < 0.0 and Oekonomie.prestige_moeglich(st.lebenszeit_plasma):
            erstes_prestige = t

        for marke in [600.0, 3600.0, 4.0 * 3600.0, 24.0 * 3600.0]:
            if not berichtet.has(marke) and t >= marke:
                berichtet[marke] = true
                print("   nach %-8s  %10s ◆/s   gesamt %10s ◆   %d Baugruppen"
                    % [Zahl.zeit(marke), Zahl.kurz(st.rate()),
                       Zahl.kurz(st.lebenszeit_plasma), _summe(st)])

    print("")
    print("   Erste Baugruppe je Stufe:")
    for i in Modul.ANZAHL:
        var wann := "nie erreicht" if erstkauf[i] < 0.0 else Zahl.zeit(erstkauf[i])
        print("     %-16s %s" % [Modul.name_von(i), wann])

    print("")
    var stufen := ""
    for i in Modul.ANZAHL:
        stufen += "%d " % int(st.modul_stufe[i])
    print("   Ausbaustufen nach 48 h: %s" % stufen)

    print("")
    if erstes_prestige < 0.0:
        print("   Erstes Prestige: in 48 h NICHT erreicht")
    else:
        print("   Erstes Prestige nach: %s" % Zahl.zeit(erstes_prestige))
    print("   Protokolle nach 48 h: %d" % Oekonomie.prestige_ertrag(st.lebenszeit_plasma))
    st.free()


## Kauft die Baugruppe mit dem besten Verhaeltnis aus Mehrertrag und Preis.
##
## Naeherung an vernuenftiges Spiel: nicht optimal, aber deutlich naeher dran
## als "immer die teuerste, die man sich leisten kann".
func _kaufe_bestes(st: Node) -> void:
    var bester := -1
    var beste_guete := 0.0
    var ist_ausbau := false

    for i in Modul.ANZAHL:
        var besessen: int = st.bestand[i]
        var stufe: int = st.modul_stufe[i]

        # Ein weiteres Stueck.
        var preis := Oekonomie.kosten(i, besessen)
        if preis <= st.plasma:
            var zuwachs := Oekonomie.modul_rate(i, besessen + 1, 1.0, stufe) \
                - Oekonomie.modul_rate(i, besessen, 1.0, stufe)
            var guete := zuwachs / preis
            if guete > beste_guete:
                beste_guete = guete
                bester = i
                ist_ausbau = false

        # Eine Ausbaustufe. Sie verdoppelt alle vorhandenen Stuecke auf einmal
        # und lohnt deshalb umso mehr, je mehr davon schon stehen.
        if besessen > 0 and not ModulAusbau.voll(stufe):
            var apreis := ModulAusbau.kosten(i, stufe)
            if apreis <= st.plasma:
                var azuwachs := Oekonomie.modul_rate(i, besessen, 1.0, stufe + 1) \
                    - Oekonomie.modul_rate(i, besessen, 1.0, stufe)
                var aguete := azuwachs / apreis
                if aguete > beste_guete:
                    beste_guete = aguete
                    bester = i
                    ist_ausbau = true

    if bester < 0:
        return
    if ist_ausbau:
        st.kaufe_modul_ausbau(bester)
    else:
        st.kaufe(bester, 1)


func _summe(st: Node) -> int:
    var n := 0
    for k in st.bestand:
        n += k
    return n
