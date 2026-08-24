## Entscheidet, welcher Einstiegshinweis gerade dran ist.
##
## Kein Lehrgang mit Fenstern und Weiter-Knöpfen: ein einzelner Hinweis, der
## auf das zeigt, was jetzt sinnvoll ist, und von selbst verschwindet, sobald
## der Spieler erkennbar verstanden hat. Lehrgänge, die man wegklicken muss,
## werden weggeklickt, ohne gelesen zu werden.
##
## Bewusst als reine Funktion über Zahlen: so lässt sich jeder Übergang im
## Testlauf prüfen, ohne die Station zu bauen.
class_name Einstieg
extends RefCounted

enum Schritt {
    ## Nichts anzeigen.
    KEIN,
    ## Auf den Stationskern zeigen - es gibt nichts zu kaufen.
    KERN,
    ## Auf die erste bezahlbare Baugruppe zeigen.
    KAUFEN,
}

## Ab so vielen Baugruppen gilt der Einstieg als verstanden.
const GENUG := 6


## Der nächste Hinweis.
##
## [param erstpreis] ist der Preis der günstigsten Baugruppe.
static func naechster(bestand_summe: int, plasma: float, erstpreis: float,
        prestige_anzahl: int) -> Schritt:
    # Wer schon einmal zurückgesetzt hat, braucht keine Anleitung mehr.
    if prestige_anzahl > 0 or bestand_summe >= GENUG:
        return Schritt.KEIN
    if plasma >= erstpreis:
        return Schritt.KAUFEN
    return Schritt.KERN


static func text(schritt: Schritt) -> String:
    match schritt:
        Schritt.KERN:
            return "Kern antippen"
        Schritt.KAUFEN:
            return "Baugruppe bauen"
    return ""
