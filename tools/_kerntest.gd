extends SceneTree
func _init() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for nummer in [1, 2, 5, 8, 11, 17, 20, 23, 30]:
        var stufen := {}
        for h in 4:
            stufen[h] = Schule.stufe_soll(nummer)
        var s := Duell.baue(nummer, stufen)
        var namen := ""
        for k in s.klingen:
            namen += Gegner.name_von(k.art) + " "
        print("Ronde %2d | Gegner %2d | zugleich %d | Atem %d | Ehre %4d | %s"
            % [nummer, s.klingen.size(), s.gleichzeitig, s.atem_voll,
                Ronde.ehre(nummer), namen])
    # Ein vollstaendiger Durchlauf mit einem perfekten Spieler.
    var stufen2 := {}
    for h in 4:
        stufen2[h] = 0
    var s2 := Duell.baue(20, stufen2)
    var t := 0.0
    while not Duell.geraeumt(s2) and s2.lebt() and t < 200.0:
        Duell.schritt(s2, 1.0 / 60.0, rng)
        t += 1.0 / 60.0
        for k in s2.klingen:
            if not k.lebt() or not k.in_mensur:
                continue
            if Duell.im_fenster(k, s2):
                if Schnitte.ist_stoss(k.wahre_linie):
                    Duell.antworte(s2, Vector2(1, 0))
                else:
                    Duell.antworte(s2, Schnitte.richtung(k.wahre_linie) * 120.0)
                break
            if k.lage == Duell.Lage.OFFEN:
                Duell.antworte(s2, Vector2(120, 0))
                break
    print("perfekter Spieler, Ronde 20: geraeumt=%s nach %.1f s, Atem %d/%d, Kette %d, Ehre %d"
        % [str(Duell.geraeumt(s2)), t, s2.atem, s2.atem_voll, s2.beste_kette, s2.ehre])
    quit()
