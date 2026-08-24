## Formatiert grosse Zahlen und Zeitspannen fuer die Anzeige.
##
## Idle-Spiele erreichen schnell Werte, die als Ziffernkette unlesbar sind.
## [method kurz] bricht sie auf drei signifikante Stellen mit Suffix herunter
## (15.4 K, 2.31 M, 8.70 aa). Ab Billiarden wird die uebliche Buchstaben-
## notation verwendet: aa, ab, ac ... az, ba, bb ...
class_name Zahl
extends RefCounted

## Suffixe fuer die ersten fuenf Dreierbloecke. Danach uebernimmt [method _buchstaben].
const KURZ_SUFFIX: PackedStringArray = ["", "K", "M", "B", "T"]

## Ab diesem Dreierblock wird auf Buchstabenpaare umgestellt.
const BUCHSTABEN_AB := 5

## Jenseits davon (~1e2611) faellt die Anzeige auf Exponentialschreibweise
## zurueck. Praktisch unerreichbar, aber besser als eine falsche Ausgabe.
const MAX_BLOCK := 5 + 26 * 26


## Kuerzt [param wert] auf drei signifikante Stellen mit Groessensuffix.
static func kurz(wert: float) -> String:
    if is_nan(wert):
        return "?"
    if is_inf(wert):
        return "-∞" if wert < 0.0 else "∞"
    if wert < 0.0:
        return "-" + kurz(-wert)
    if wert < 1000.0:
        # Unterhalb der ersten Schwelle ist die volle Zahl noch lesbar.
        return str(int(wert)) if is_equal_approx(wert, floor(wert)) else "%.1f" % wert

    var block := int(floor(log(wert) / log(1000.0)))
    if block >= MAX_BLOCK:
        return "%.2e" % wert

    var mantisse := wert / pow(1000.0, block)
    # Rundung kann 999.95 auf 1000.00 heben - dann eine Stufe weiterruecken.
    if mantisse >= 999.995:
        block += 1
        mantisse /= 1000.0
        if block >= MAX_BLOCK:
            return "%.2e" % wert

    var stellen := 2 if mantisse < 10.0 else (1 if mantisse < 100.0 else 0)
    return ("%." + str(stellen) + "f") % mantisse + " " + _suffix(block)


## Liefert das Suffix fuer einen Dreierblock.
static func _suffix(block: int) -> String:
    if block < BUCHSTABEN_AB:
        return KURZ_SUFFIX[block]
    return _buchstaben(block - BUCHSTABEN_AB)


## Wandelt einen Index in ein Buchstabenpaar: 0 -> aa, 1 -> ab, 26 -> ba.
static func _buchstaben(index: int) -> String:
    var erster := index / 26
    var zweiter := index % 26
    return char(97 + erster) + char(97 + zweiter)


## Formatiert eine Dauer als "3h 12m" / "12m 05s" / "45s".
static func zeit(sekunden: float) -> String:
    if sekunden < 0.0 or is_nan(sekunden):
        return "0s"
    var gesamt := int(sekunden)
    var s := gesamt % 60
    var m := (gesamt / 60) % 60
    var h := gesamt / 3600
    if h > 0:
        return "%dh %02dm" % [h, m]
    if m > 0:
        return "%dm %02ds" % [m, s]
    return "%ds" % s
