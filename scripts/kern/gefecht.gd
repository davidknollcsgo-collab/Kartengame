class_name Gefecht
extends RefCounted

## **Das Gefecht, als reine Rechnung.**
##
## Hier steht alles, was über Leben und Tod entscheidet, und nichts, was mit
## Zeichnen zu tun hat. Der Grund ist derselbe wie überall in diesem Haus:
## ein Lauf muss sich **headless durchspielen** lassen. Nur so lässt sich die
## einzige Frage beantworten, die dieses Genre überhaupt hat - *hält ein
## Spieler, der sich vernünftig bewegt, die zehn Minuten durch?* - und zwar
## ohne dass jemand zehn Minuten lang selbst spielt.
##
## Kein Szenen-, kein Autoload-Bezug.

## **Wie oft der Streiter ueberhaupt verwundet werden kann** - gleichgueltig,
## wie viele anliegen.
##
## Das ist die Zahl, an der dieses Genre haengt, und der erste Entwurf hatte
## sie nicht. Dort schlug **jeder** anliegende Feind fuer sich zu: zehn
## Strolche machten siebzig Schaden je Sekunde gegen hundert Leben, und ein
## Gedraenge war kein schwerer Augenblick, sondern ein Sofort-Tod. Gemessen
## fiel der Schwertkaempfer nach hundertvierundfuenfzig Sekunden - mit
## dreihundertvierundachtzig Erschlagenen auf dem Konto.
##
## Ein Horden-Spiel muss aber wollen, dass man in die Horde geraet. Also
## zaehlt nicht, **wie viele** anliegen, sondern **wie lange** - und der
## haerteste von ihnen bestimmt, was es kostet. Damit bleibt ein Ritter
## gefaehrlicher als ein Strolch, und zwanzig Strolche sind nicht zwanzigmal
## ein Strolch.
const WUNDE_SPERRE := 0.55
## Wie groß der Streiter selbst ist - für Berührung und für das Bild.
const STREITER_RADIUS := 20.0

## Der Druckring. Wer darin steht, zählt für die Umzingelung - auch wenn er
## noch nicht anliegt. Der Ring sagt, **wie schlimm** es ist; die Berührung
## sagt, **dass** es passiert.
##
## Der Deckel oben behob den Sofort-Tod im Gedränge und nahm dabei jeden
## Grund, sich zu bewegen: gemessen hielt Stehenbleiben 465 Sekunden und
## Laufen 473 - die einzige Eingabe des Spiels bewirkte nichts. Bestraft
## wird darum nicht das Gedränge, sondern die **Umzingelung**: nicht wie
## viele anliegen, sondern aus wie vielen Richtungen. Zwanzig Strolche auf
## einer Seite sind so teuer wie einer; acht, die dich einschließen, sind
## das Dreifache. Das belohnt genau das, was das Spiel verspricht - sie vor
## dir halten, eine Flanke freilassen, durch eine Lücke gehen.
const DRUCK_RADIUS := 180.0
## In so viele Fächer fällt der Kreis. Gezählt wird, wie viele **besetzt**
## sind, nicht wie viele darin stehen.
const SEKTOREN := 8
## Der Aufschlag bei voller Umzingelung. Ein Fach mal eins, alle acht mal
## dreieinhalb.
const UMZINGELT_ZUSATZ := 2.5
## Wie schnell sich der Blick der Laufrichtung nachdreht. Sofort wäre ein
## Zeiger, gar nicht wäre ein Schild.
const BLICK_FOLGT := 9.0

## Wie weit der Sog den Sold heranzieht, wenn er einmal gefasst ist.
const SOLD_ZUG := 620.0
## Ein Geldstück liegt nicht ewig. Ohne das häufen sich in Minute neun
## dreitausend davon im Feld, und jeder kostet eine Abstandsrechnung.
const SOLD_DAUER := 22.0

## Wo Feinde eintreten: knapp außerhalb dessen, was man sieht. Näher wäre
## ein Erscheinen aus dem Nichts, weiter kostet nur Laufzeit.
const EINTRITT_RADIUS := 760.0
## Und wer zu weit zurückfällt, wird versetzt statt ewig hinterherzulaufen.
const HEIMHOL_RADIUS := 1500.0

## Wie lange ein Treffer einen Feind zurückwirft. Klein: Rückstoß, der die
## Horde aufhält, nimmt dem Gedränge seinen Sinn.
const STOSS_DAUER := 0.10
const STOSS_WEITE := 60.0


class Feind extends RefCounted:
    var art := 0
    var ort := Vector2.ZERO
    var leben := 1.0
    var leben_voll := 1.0
    var radius := 16.0
    var stoss := Vector2.ZERO
    var stoss_rest := 0.0
    ## Nur für den Stürmer: sammeln, preschen, ruhen.
    var uhr := 0.0
    var stuermt := false
    ## Nur für den Schützen.
    var schuss_frei := 0.0
    ## Vom Treiber angetrieben? Wird je Schritt neu gesetzt.
    var getrieben := false
    var lebt := true
    ## Rein für das Bild: Blickrichtung und ein Zucken nach einem Treffer.
    var blick := 1.0
    var zuckt := 0.0


class Geschoss extends RefCounted:
    var ort := Vector2.ZERO
    var richtung := Vector2.RIGHT
    var tempo := 300.0
    var schaden := 1.0
    var waffe := 0
    var feindlich := false
    var alter := 0.0
    var dauer := 3.0
    ## Wie viele es noch durchschlagen kann.
    var rest := 1
    ## Die Axt kehrt um.
    var kehrt := false
    var gekehrt := false
    var start := Vector2.ZERO
    var getroffen := {}
    var lebt := true


class Muenze extends RefCounted:
    var ort := Vector2.ZERO
    var wert := 1
    var alter := 0.0
    var gefasst := false
    var lebt := true


enum Vorfall { TREFFER, FEIND_FAELLT, STREITER_GETROFFEN, AUFSTIEG,
    SCHLAG, SCHUSS, MUENZE, WARLORD, ENDE }


class Stand extends RefCounted:
    var zeit := 0.0
    var ort := Vector2.ZERO
    var blick := Vector2.RIGHT
    var lauf := Vector2.ZERO
    var leben := 100.0
    var leben_voll := 100.0
    var wunde_frei := 0.0
    ## Wie eng der Ring steht, null bis eins. Das Bild nimmt dieselbe Zahl,
    ## aus der der Schaden fällt - zwei Rechnungen wären zwei Wahrheiten.
    var umzingelt := 0.0
    ## Welche Fächer besetzt sind, ein Bit je Fach. Nur fürs Zeichnen.
    var druck_faecher := 0
    var tempo := 200.0
    var schaden_faktor := 1.0
    var sold_faktor := 1.0
    var weite_faktor := 1.0
    var sog_zusatz := 0.0
    var panzer_zusatz := 0.0
    var held := 0

    var waffen := {}          ## Art -> Stufe
    var zuege := {}           ## Gunst.Zug -> Stufe
    var takte := {}           ## Art -> Sekunden bis zum nächsten Schlag
    var flegel_winkel := 0.0

    var feinde: Array[Feind] = []
    var geschosse: Array[Geschoss] = []
    var muenzen: Array[Muenze] = []

    var stufe := 1
    var erfahrung := 0
    var sold := 0
    var erschlagen := 0
    var warlord_da := false
    var warlord_gefallen := false

    ## Solange wahr, steht alles still: der Spieler wählt.
    var wartet_auf_wahl := false
    var angebote: Array = []

    var _eintritt_rest := 0.0
    var vorfaelle: Array = []

    func lebt() -> bool:
        return leben > 0.0

    func waffe_stufe(w: int) -> int:
        return int(waffen.get(w, 0))

    func zug_stufe(z: int) -> int:
        return int(zuege.get(z, 0))


## --- Aufbau ---

## `burg_stufen` ist die stetige Kurve, `held` die Abwechslung, `getragen`
## der Fund. Drei Quellen, drei verschiedene Fragen - und alle drei landen
## hier in denselben Zahlen, damit das Gefecht nur eine Wahrheit kennt.
static func baue(burg_stufen: Dictionary, held := Helden.Held.SCHWERT,
        getragen := {}) -> Stand:
    var s := Stand.new()
    s.held = held
    s.leben_voll = Halle.leben(int(burg_stufen.get(Halle.Bau.MAUER, 0))) \
        * Helden.leben_faktor(held) \
        * Ausruestung.summe(getragen, Ausruestung.Wirkt.LEBEN)
    s.leben = s.leben_voll
    s.tempo = Halle.tempo(int(burg_stufen.get(Halle.Bau.STALL, 0))) \
        * Helden.tempo_faktor(held) \
        * Ausruestung.summe(getragen, Ausruestung.Wirkt.TEMPO)
    s.schaden_faktor = Halle.schaden_faktor(
        int(burg_stufen.get(Halle.Bau.SCHMIEDE, 0))) \
        * Helden.schaden_faktor(held) \
        * Ausruestung.summe(getragen, Ausruestung.Wirkt.SCHADEN)
    s.sold_faktor = Halle.sold_faktor(int(burg_stufen.get(Halle.Bau.MUENZE, 0)))
    s.weite_faktor = Helden.weite_faktor(held)
    s.sog_zusatz = Ausruestung.summe(getragen, Ausruestung.Wirkt.SOG) - 1.0
    s.panzer_zusatz = Ausruestung.summe(getragen, Ausruestung.Wirkt.PANZER) - 1.0
    # **Man beginnt mit genau einer Waffe**, und zwar der seines Helden. Ohne
    # eine schlaegt man die erste halbe Minute gar nichts; mit zweien hat der
    # erste Aufstieg nichts mehr zu sagen.
    var erste := Helden.startwaffe(held)
    s.waffen[erste] = 1
    s.takte[erste] = 0.0
    return s


## Was der Spieler mit allen Faktoren wirklich austeilt.
static func schaden_von(s: Stand, w: int) -> float:
    return Waffen.schaden(w, s.waffe_stufe(w)) * s.schaden_faktor \
        * Gunst.schaden_faktor(s.zug_stufe(Gunst.Zug.WETZSTEIN))


static func tempo_von(s: Stand) -> float:
    return s.tempo * Gunst.tempo_faktor(s.zug_stufe(Gunst.Zug.STIEFEL))


static func sog_von(s: Stand) -> float:
    return Gunst.sog(s.zug_stufe(Gunst.Zug.LATERNE)) * (1.0 + s.sog_zusatz)


## Die Reichweite einer Waffe, mit dem Helden darin. Sie steht hier und nicht
## bei `Waffen`, weil erst hier bekannt ist, wer sie fuehrt - und ein
## Bogenschuetze, dessen Vorteil nur im Bild steht, hat keinen.
static func weite_von(s: Stand, w: int) -> float:
    return Waffen.weite(w, s.waffe_stufe(w)) * s.weite_faktor


## --- Der Schritt ---

static func schritt(s: Stand, dt: float, eingabe: Vector2,
        rng: RandomNumberGenerator) -> void:
    s.vorfaelle.clear()
    if s.wartet_auf_wahl or not s.lebt():
        return
    s.zeit += dt
    s.wunde_frei = maxf(0.0, s.wunde_frei - dt)

    _bewege_streiter(s, dt, eingabe)
    _speise_nach(s, dt, rng)
    _bewege_feinde(s, dt, rng)
    _fuehre_waffen(s, dt, rng)
    _bewege_geschosse(s, dt)
    _raeume_auf(s, dt)
    _sammle(s, dt)
    _zehre(s, dt)
    _pruefe_aufstieg(s, rng)


static func _bewege_streiter(s: Stand, dt: float, eingabe: Vector2) -> void:
    var e := eingabe
    if e.length() > 1.0:
        e = e.normalized()
    s.lauf = e
    s.ort += e * tempo_von(s) * dt
    # **Der Blick folgt dem Kampf, nicht dem Laufweg.** Wer flieht, laeuft
    # von der Horde weg; eine Figur, die dabei nach vorn sieht, kaempft mit
    # dem Ruecken zu allem, was sie bedroht - und das Bild widerspricht dann
    # dem, was die Waffen tun.
    var ziel := s.blick
    var nah := _naechste(s, 620.0, 1)
    if not nah.is_empty():
        ziel = (nah[0].ort - s.ort).normalized()
    elif e.length_squared() > 0.02:
        ziel = e.normalized()
    s.blick = s.blick.lerp(ziel, clampf(BLICK_FOLGT * dt, 0.0, 1.0))
    if s.blick.length_squared() > 0.0001:
        s.blick = s.blick.normalized()


static func _speise_nach(s: Stand, dt: float, rng: RandomNumberGenerator) -> void:
    if s.zeit >= Andrang.WARLORD_ZEIT and not s.warlord_da:
        s.warlord_da = true
        _setze_ein(s, Feinde.Art.WARLORD, rng)
        s.vorfaelle.append([Vorfall.WARLORD, null])
    if s.warlord_da:
        # **Nach dem Warlord kommt nichts mehr nach.** Ein Höhepunkt, den man
        # im Gedränge nicht sieht, ist keiner.
        return
    s._eintritt_rest -= dt * Andrang.rate(s.zeit)
    var sicherung := 0
    while s._eintritt_rest <= 0.0 and sicherung < 40:
        s._eintritt_rest += 1.0
        _setze_ein(s, Andrang.ziehe(s.zeit, rng), rng)
        sicherung += 1


static func _setze_ein(s: Stand, art: int, rng: RandomNumberGenerator) -> void:
    var f := Feind.new()
    f.art = art
    f.leben_voll = Feinde.leben(art) * Andrang.zaehigkeit(s.zeit)
    f.leben = f.leben_voll
    f.radius = Feinde.radius(art)
    var w := rng.randf() * TAU
    f.ort = s.ort + Vector2(cos(w), sin(w)) * EINTRITT_RADIUS
    f.uhr = rng.randf() * Feinde.STURM_SAMMELN
    f.schuss_frei = rng.randf() * Feinde.SCHUSS_TAKT
    s.feinde.append(f)


static func _bewege_feinde(s: Stand, dt: float, rng: RandomNumberGenerator) -> void:
    # **Der Treiber wirkt zuerst und für alle.** Wer ihn stehen lässt, kämpft
    # gegen eine schnellere Horde - das ist seine ganze Aussage, und sie muss
    # vor jeder Bewegung feststehen, sonst treibt er je nach Listenplatz.
    var treiber: Array[Feind] = []
    for f in s.feinde:
        f.getrieben = false
        if f.lebt and Feinde.sinn(f.art) == Feinde.Sinn.TREIBT:
            treiber.append(f)
    if not treiber.is_empty():
        var w2 := Feinde.TREIB_WEITE * Feinde.TREIB_WEITE
        for f in s.feinde:
            if not f.lebt:
                continue
            for t in treiber:
                if t != f and f.ort.distance_squared_to(t.ort) < w2:
                    f.getrieben = true
                    break

    # Wer anliegt, wie hart der haerteste davon zuschlaegt - und aus wie
    # vielen Richtungen ueberhaupt Druck kommt.
    var haerteste := 0.0
    var faecher := 0
    var druck_r2 := DRUCK_RADIUS * DRUCK_RADIUS
    for f in s.feinde:
        if not f.lebt:
            continue
        f.zuckt = maxf(0.0, f.zuckt - dt)
        var zu_spieler := s.ort - f.ort
        var abstand := zu_spieler.length()
        var richtung := zu_spieler / maxf(0.001, abstand)
        f.blick = 1.0 if richtung.x >= 0.0 else -1.0

        var tempo := Feinde.tempo(f.art)
        if f.getrieben:
            tempo *= Feinde.TREIB_SCHUB

        match Feinde.sinn(f.art):
            Feinde.Sinn.HAELT_ABSTAND:
                # Er hält seine Weite: zu nah geht er zurück, zu weit kommt
                # er heran. Genau dazwischen schießt er.
                f.schuss_frei -= dt
                if abstand > Feinde.SCHUSS_WEITE * 1.1:
                    f.ort += richtung * tempo * dt
                elif abstand < Feinde.SCHUSS_WEITE * 0.75:
                    f.ort -= richtung * tempo * dt
                elif f.schuss_frei <= 0.0:
                    f.schuss_frei = Feinde.SCHUSS_TAKT
                    var g := Geschoss.new()
                    g.ort = f.ort
                    g.richtung = richtung
                    g.tempo = Feinde.BOLZEN_TEMPO
                    g.schaden = Feinde.schaden(f.art)
                    g.feindlich = true
                    g.dauer = 4.0
                    s.geschosse.append(g)
                    s.vorfaelle.append([Vorfall.SCHUSS, f])
            Feinde.Sinn.STUERMT:
                f.uhr -= dt
                if f.stuermt:
                    f.ort += f.stoss.normalized() * tempo * Feinde.STURM_TEMPO * dt
                    if f.uhr <= 0.0:
                        f.stuermt = false
                        f.uhr = Feinde.STURM_SAMMELN
                else:
                    f.ort += richtung * tempo * 0.45 * dt
                    if f.uhr <= 0.0:
                        f.stuermt = true
                        f.uhr = Feinde.STURM_DAUER
                        # Er prescht dorthin, wo der Spieler **jetzt** steht.
                        # Vorhalten wäre unausweichlich, und was man nicht
                        # vermeiden kann, ist kein Angriff, sondern eine Steuer.
                        f.stoss = richtung
            _:
                f.ort += richtung * tempo * dt

        if f.stoss_rest > 0.0:
            f.stoss_rest -= dt
            f.ort += f.stoss * (STOSS_WEITE * dt / STOSS_DAUER)

        # Anliegen. Wer zuschlaegt, entscheidet sich weiter unten - hier
        # wird nur gesammelt, wer ueberhaupt dran ist.
        if abstand < f.radius + STREITER_RADIUS:
            haerteste = maxf(haerteste, Feinde.schaden(f.art))
        if abstand * abstand < druck_r2:
            var winkel := (-zu_spieler).angle() + PI
            var fach := int(winkel / TAU * float(SEKTOREN)) % SEKTOREN
            faecher |= 1 << fach

        # Wer weit zurückfällt, wird versetzt. Ein Feind, der zwei Minuten
        # hinterherläuft, ist kein Gegner, sondern ein Kostenpunkt.
        if abstand > HEIMHOL_RADIUS:
            var w := rng.randf() * TAU
            f.ort = s.ort + Vector2(cos(w), sin(w)) * EINTRITT_RADIUS

    var besetzt := 0
    for i in SEKTOREN:
        if (faecher & (1 << i)) != 0:
            besetzt += 1
    s.druck_faecher = faecher
    s.umzingelt = clampf(float(besetzt - 1) / float(SEKTOREN - 1), 0.0, 1.0)

    if haerteste > 0.0 and s.wunde_frei <= 0.0:
        s.wunde_frei = WUNDE_SPERRE
        _verwunde(s, haerteste * (1.0 + UMZINGELT_ZUSATZ * s.umzingelt))


static func _verwunde(s: Stand, roh: float) -> void:
    var panzer := Gunst.panzer(s.zug_stufe(Gunst.Zug.RUESTUNG)) + s.panzer_zusatz
    var wirklich := roh * (1.0 - clampf(panzer, 0.0, 0.85))
    s.leben -= wirklich
    s.vorfaelle.append([Vorfall.STREITER_GETROFFEN, null])
    if s.leben <= 0.0:
        s.leben = 0.0
        s.vorfaelle.append([Vorfall.ENDE, null])


## --- Die Waffen ---

static func _fuehre_waffen(s: Stand, dt: float, rng: RandomNumberGenerator) -> void:
    # Der Flegel schlägt nicht, er ist da. Seine Köpfe wandern.
    s.flegel_winkel += dt * 3.1

    for w in s.waffen.keys():
        var stufe := s.waffe_stufe(w)
        if stufe <= 0:
            continue
        if Waffen.kreist(w):
            _flegel(s, w, stufe, dt)
            continue
        var rest := float(s.takte.get(w, 0.0)) - dt
        if rest > 0.0:
            s.takte[w] = rest
            continue
        s.takte[w] = Waffen.takt(w, stufe)
        _schlage(s, w, stufe, rng)


static func _schlage(s: Stand, w: int, stufe: int, rng: RandomNumberGenerator) -> void:
    var schaden := schaden_von(s, w)
    var weite := weite_von(s, w)
    var zahl := Waffen.zahl(w, stufe)

    if Waffen.fliegt(w):
        # Die Armbrust braucht ein Ziel, die Axt nicht: ein Bolzen ins Leere
        # ist verschwendet, eine geworfene Axt kommt zurueck.
        var ziele := _naechste(s, weite, zahl)
        if ziele.is_empty() and w == Waffen.Art.ARMBRUST:
            return
        for i in zahl:
            var g := Geschoss.new()
            g.ort = s.ort
            g.start = s.ort
            g.waffe = w
            g.schaden = schaden
            g.tempo = 460.0 if w == Waffen.Art.ARMBRUST else 330.0
            g.dauer = 2.6
            # **Die Axt durchschlaegt nicht alles.** Mit unbegrenztem
            # Durchschlag maehte sie auf Hin- und Rueckweg eine ganze Gasse
            # und stand mit zweihundertachtundsechzig Erschlagenen einsam an
            # der Spitze. Fuenf ist viel und trotzdem eine Grenze.
            g.rest = 1 if w == Waffen.Art.ARMBRUST else 5
            g.kehrt = w == Waffen.Art.AXT
            if w == Waffen.Art.ARMBRUST:
                var z: Feind = ziele[i % ziele.size()]
                g.richtung = (z.ort - s.ort).normalized()
            else:
                # Äxte fächern auf, damit zwei nicht dieselbe Bahn nehmen -
                # um die Richtung zum Naechsten herum, aus demselben Grund
                # wie oben.
                var ziel_richtung := s.blick
                if not ziele.is_empty():
                    ziel_richtung = (ziele[0].ort - s.ort).normalized()
                var mitte := ziel_richtung.angle()
                var spanne := 0.5
                var teil := 0.0 if zahl <= 1 else (float(i) / float(zahl - 1) - 0.5)
                g.richtung = Vector2.RIGHT.rotated(mitte + teil * spanne)
            s.geschosse.append(g)
        s.vorfaelle.append([Vorfall.SCHLAG, w])
        return

    # **Sofortwaffen zielen auf den Naechsten, nicht in die Laufrichtung.**
    #
    # Der erste Anlauf liess das Schwert dorthin schlagen, wohin der Held
    # sieht, und der Blick folgte dem Laufweg. In einem Genre, dessen ganze
    # Bewegung Fliehen ist, zeigt der Laufweg aber **von der Horde weg** -
    # gemessen: hundertdreissig Sekunden, hundertachtzig Hiebe, **sieben**
    # Erschlagene. Eine Waffe, die nur trifft, wenn man auf die Feinde
    # zulaeuft, ist in diesem Spiel keine Waffe.
    #
    # Der Speer bleibt die Ausnahme, und zwar mit Absicht: er ist der eine
    # Zug, der nach dem Laufweg fragt, und daraus bezieht er seinen
    # Charakter. Alle anderen suchen sich ihr Ziel.
    var mitte := s.blick
    if w == Waffen.Art.SPEER:
        # **Der Speer stoesst nach hinten.**
        #
        # Entworfen war er als der eine Zug, der nach dem Laufweg fragt - und
        # er stiess nach vorn. Gemessen: zwei Erschlagene in zwei Minuten,
        # waehrend der Hammer zweihundertfuenfzehn schafft. Der Grund ist der
        # Kern dieses Genres und war im Entwurf uebersehen: **wer kitet,
        # laeuft von allen weg.** Nach vorn stoesst er ins Leere, immer.
        #
        # Die Frage bleibt dieselbe - *wohin laeufst du?* -, nur die Antwort
        # steht andersherum: er spiesst auf, was sich an die Fersen heftet.
        # Damit ist er die einzige Waffe, die belohnt, dass man gerade
        # flieht, und das ist ein Charakter, den keine andere hat.
        if s.lauf.length_squared() > 0.02:
            mitte = -s.lauf.normalized()
        else:
            # Steht man, gibt es keinen Laufweg - dann nimmt auch er den
            # Naechsten, statt in eine Himmelsrichtung zu stossen.
            var hinter := _naechste(s, weite * 1.6, 1)
            if not hinter.is_empty():
                mitte = (hinter[0].ort - s.ort).normalized()
    else:
        var nah := _naechste(s, weite * 1.6, 1)
        if not nah.is_empty():
            mitte = (nah[0].ort - s.ort).normalized()
    var halb := Waffen.breite(w, stufe) * 0.5
    var voll := halb >= PI
    var w2 := weite * weite
    var traf := false
    for f in s.feinde:
        if not f.lebt:
            continue
        var zu := f.ort - s.ort
        if zu.length_squared() > w2:
            continue
        if not voll and absf(zu.angle_to(mitte)) > halb:
            continue
        _treffe(s, f, schaden, zu.normalized())
        traf = true
    s.vorfaelle.append([Vorfall.SCHLAG, w])
    if traf:
        s.vorfaelle.append([Vorfall.TREFFER, w])


static func _flegel(s: Stand, w: int, stufe: int, dt: float) -> void:
    var zahl := Waffen.zahl(w, stufe)
    var weite := weite_von(s, w)
    var schaden := schaden_von(s, w) * dt / maxf(0.05, Waffen.takt(w, stufe))
    # Der Kopf ist so gross wie ein Feind breit ist: kleiner faehrt er
    # zwischen ihnen hindurch, ohne etwas zu beruehren.
    var kopf_r := 36.0
    for i in zahl:
        var winkel := s.flegel_winkel + TAU * float(i) / float(zahl)
        var ort := s.ort + Vector2(cos(winkel), sin(winkel)) * weite
        for f in s.feinde:
            if not f.lebt:
                continue
            if f.ort.distance_squared_to(ort) > (kopf_r + f.radius) * (kopf_r + f.radius):
                continue
            # **Der Flegel teilt seinen Schaden über die Zeit aus**, nicht je
            # Berührung. Je Berührung gerechnet hinge sein Schaden an der
            # Bildrate, und auf einem schnellen Telefon wäre er doppelt so
            # stark - genau der Fehler, den dieses Haus schon einmal bezahlt
            # hat.
            _treffe(s, f, schaden, (f.ort - ort).normalized(), false)


static func _treffe(s: Stand, f: Feind, schaden: float, richtung: Vector2,
        mit_stoss := true) -> void:
    f.leben -= schaden
    f.zuckt = 0.14
    if mit_stoss:
        f.stoss = richtung
        f.stoss_rest = STOSS_DAUER
    if f.leben > 0.0:
        return
    f.lebt = false
    s.erschlagen += 1
    if Feinde.ist_warlord(f.art):
        s.warlord_gefallen = true
    var m := Muenze.new()
    m.ort = f.ort
    m.wert = maxi(1, int(round(float(Feinde.sold(f.art)) * s.sold_faktor)))
    s.muenzen.append(m)
    s.vorfaelle.append([Vorfall.FEIND_FAELLT, f])


static func _naechste(s: Stand, weite: float, zahl: int) -> Array:
    var nah: Array = []
    var w2 := weite * weite
    for f in s.feinde:
        if f.lebt and f.ort.distance_squared_to(s.ort) <= w2:
            nah.append(f)
    nah.sort_custom(func(a, b):
        return a.ort.distance_squared_to(s.ort) < b.ort.distance_squared_to(s.ort))
    return nah.slice(0, maxi(1, zahl))


static func _bewege_geschosse(s: Stand, dt: float) -> void:
    for g in s.geschosse:
        if not g.lebt:
            continue
        g.alter += dt
        if g.kehrt and not g.gekehrt and g.alter > g.dauer * 0.42:
            g.gekehrt = true
        if g.gekehrt:
            # Sie fliegt zum Streiter zurück - und zwar dorthin, wo er
            # inzwischen steht. Eine Axt, die zum Wurfort zurückkehrt, fängt
            # niemand wieder.
            var zu := s.ort - g.ort
            if zu.length() < 30.0:
                g.lebt = false
                continue
            g.richtung = zu.normalized()
        g.ort += g.richtung * g.tempo * dt
        if g.alter > g.dauer:
            g.lebt = false
            continue

        if g.feindlich:
            if g.ort.distance_squared_to(s.ort) < STREITER_RADIUS * STREITER_RADIUS:
                g.lebt = false
                _verwunde(s, g.schaden)
            continue

        for f in s.feinde:
            if not f.lebt or g.getroffen.has(f):
                continue
            var r := f.radius + 12.0
            if g.ort.distance_squared_to(f.ort) > r * r:
                continue
            g.getroffen[f] = true
            _treffe(s, f, g.schaden, g.richtung)
            g.rest -= 1
            if g.rest <= 0:
                g.lebt = false
                break


static func _raeume_auf(s: Stand, dt: float) -> void:
    var lebende: Array[Feind] = []
    for f in s.feinde:
        if f.lebt:
            lebende.append(f)
    s.feinde = lebende
    var fliegende: Array[Geschoss] = []
    for g in s.geschosse:
        if g.lebt:
            fliegende.append(g)
    s.geschosse = fliegende


static func _sammle(s: Stand, dt: float) -> void:
    var sog := sog_von(s)
    var sog2 := sog * sog
    var liegend: Array[Muenze] = []
    for m in s.muenzen:
        m.alter += dt
        if m.alter > SOLD_DAUER:
            continue
        var zu := s.ort - m.ort
        if m.gefasst or zu.length_squared() < sog2:
            m.gefasst = true
            var d := zu.length()
            if d < STREITER_RADIUS:
                s.erfahrung += m.wert
                s.sold += m.wert
                s.vorfaelle.append([Vorfall.MUENZE, m])
                continue
            m.ort += zu / maxf(0.001, d) * SOLD_ZUG * dt
        liegend.append(m)
    s.muenzen = liegend


static func _zehre(s: Stand, dt: float) -> void:
    var z := Gunst.zehrung(s.zug_stufe(Gunst.Zug.ZEHRUNG))
    if z <= 0.0:
        return
    s.leben = minf(s.leben_voll, s.leben + z * dt)


static func _pruefe_aufstieg(s: Stand, rng: RandomNumberGenerator) -> void:
    var noetig := Gunst.stufenkosten(s.stufe)
    if s.erfahrung < noetig:
        return
    s.erfahrung -= noetig
    s.stufe += 1
    s.angebote = Gunst.angebote(s.waffen, s.zuege, rng)
    if s.angebote.is_empty():
        return
    s.wartet_auf_wahl = true
    s.vorfaelle.append([Vorfall.AUFSTIEG, null])


## Der Spieler hat gewählt.
static func nimm(s: Stand, welches: int) -> void:
    if not s.wartet_auf_wahl:
        return
    if welches < 0 or welches >= s.angebote.size():
        return
    var a = s.angebote[welches]
    if a.ist_waffe:
        s.waffen[a.was] = a.stufe
        if not s.takte.has(a.was):
            s.takte[a.was] = 0.0
    else:
        s.zuege[a.was] = a.stufe
    s.angebote = []
    s.wartet_auf_wahl = false


## Ist der Lauf vorbei - und wie?
static func vorbei(s: Stand) -> bool:
    return not s.lebt() or s.warlord_gefallen
