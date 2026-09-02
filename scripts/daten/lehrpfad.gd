class_name Lehrpfad
extends RefCounted

## Der gefuehrte Einstieg.
##
## **Vorher waren das fuenf graue Saetze.** Sie standen einer nach dem anderen
## in der Bildmitte, in derselben Schrift und derselben Farbe wie jede andere
## Meldung, ohne Titel und ohne einen Hinweis darauf, wovon sie reden. Wer
## zum ersten Mal hereinkommt, sieht dann einen dunklen Bildschirm, einen
## Lichtkegel und einen Satz, der irgendwo hingehoert - und muss selbst
## herausfinden, wohin.
##
## Ein Einstieg besteht aus drei Teilen, und der Satz ist nur einer davon:
##
##   1. **Was** zu tun ist - ein Titel in zwei bis vier Woertern. Er ist das,
##      was jemand liest, der nicht liest.
##   2. **Warum** - ein Satz. Er beantwortet die Frage, die sonst offen
##      bleibt, und er ist der Grund, warum man sich den Titel merkt.
##   3. **Wo** - ein Ring auf dem Ding, um das es geht. Ohne ihn ist jeder
##      Satz eine Suchaufgabe, und eine Suchaufgabe in den ersten dreissig
##      Sekunden ist der Punkt, an dem jemand die App wieder loescht.
##
## Der Pfad schreitet an **Ereignissen** fort, nicht an einer Uhr: wer
## langsamer ist, bekommt mehr Zeit; wer es sofort versteht, wird nicht
## aufgehalten. Er laeuft genau einmal, und `KolonieStand.einstieg` merkt
## sich, wie weit er gediehen ist.
##
## Reine Daten - keine Szenen- und keine Autoload-Bezuege, damit der Testlauf
## dieselbe Tafel sieht wie das Spiel.

## Worauf der Ring zeigt.
enum Ziel {
    KEINS,          ## Kein Ring - der Satz steht fuer sich.
    KEGEL,          ## Ein wandernder Ring im unteren Drittel: der Daumen.
    WELLENKNOPF,    ## Der Knopf, der die Welle losschickt.
    BRUT,           ## Das Gelege.
    NISCHE,         ## Die naechste freie Knospe an der Ranke.
    STOSSKNOPF,     ## Der Knopf unten rechts: das Stosslicht.
    KOLONIEKNOPF,   ## Der Weg in die Kolonie.
    KAMMERN,        ## Im Koloniebildschirm: die Kammerliste.
}

## Die Schritte in der Reihenfolge, in der sie fallen. Die Reihenfolge ist
## nicht frei gewaehlt, sondern die des Spiels selbst: rufen, ziehen, treffen,
## die Welle ueberstehen, bauen, ausbauen, wiederkommen.
##
## **Gerufen wird zuerst, nicht gezogen.** Hier stand "HOLD AND SWEEP" an
## erster Stelle - und der erste Bildschirm, den ein neuer Spieler sieht, ist
## die Bauphase. Dort gibt es keinen Kegel zu ziehen: Tippen setzt einen
## Polypen, und die Zeile darueber sagt genau das. Der allererste Satz des
## Spiels widersprach also der Zeile direkt ueber ihm und dem Bildschirm, auf
## dem er stand. Ein Einstieg, dessen erster Schritt auf dem ersten Bild
## nicht stimmt, kostet mehr Vertrauen als er aufbaut.
const TAFEL: Array[Dictionary] = [
    {
        &"kennung": &"STARTEN",
        &"titel": "SEND FOR THEM",
        &"satz": "Nothing comes out of the dark until you call it. Five waves make one session.",
        &"ziel": Ziel.WELLENKNOPF,
    },
    {
        &"kennung": &"ZIEHEN",
        &"titel": "HOLD AND SWEEP",
        &"satz": "Press anywhere and drag. The light cone follows your finger.",
        &"ziel": Ziel.KEGEL,
    },
    {
        &"kennung": &"BRENNEN",
        &"titel": "LIGHT BURNS",
        &"satz": "Whatever stands in the cone takes damage. The bright core burns fastest, and the cone holds only a few at once.",
        &"ziel": Ziel.KEINS,
    },
    {
        &"kennung": &"STOSS",
        &"titel": "THE BURST",
        &"satz": "Tap the ring, bottom right. The guardian throws a shockwave that hits everything it crosses - even outside the cone. It recharges on its own.",
        &"ziel": Ziel.STOSSKNOPF,
    },
    {
        &"kennung": &"BRUT",
        &"titel": "GUARD THE BROOD",
        &"satz": "A raider that slips past takes an egg. Lose every egg and the session ends - the colony keeps what it earned.",
        &"ziel": Ziel.BRUT,
    },
    {
        &"kennung": &"POLYP",
        &"titel": "GROW A POLYP",
        &"satz": "Between waves, tap a bud on the vine. The guard polyp that grows there fires on its own while you sweep.",
        &"ziel": Ziel.NISCHE,
    },
    {
        &"kennung": &"KOLONIE",
        &"titel": "OPEN THE COLONY",
        &"satz": "Nutrients from the maw are spent down in the trench. That is where the cone gets stronger.",
        &"ziel": Ziel.KOLONIEKNOPF,
    },
    {
        &"kennung": &"KAMMER",
        &"titel": "RAISE A CHAMBER",
        &"satz": "Tap a chamber to raise it. It takes time to dig, and it keeps digging while you are away.",
        &"ziel": Ziel.KAMMERN,
    },
    {
        &"kennung": &"SITZUNG",
        &"titel": "FIVE WAVES A SESSION",
        &"satz": "After five waves the brood is whole again and the polyps are gone. Come back, go deeper, and take the trench a section at a time.",
        &"ziel": Ziel.KEINS,
    },
]


static func anzahl() -> int:
    return TAFEL.size()


## Ob dieser Schritt ueberhaupt einer ist. Alles andere heisst: fertig.
static func gilt(schritt: int) -> bool:
    return schritt >= 0 and schritt < TAFEL.size()


static func titel(schritt: int) -> String:
    return String(TAFEL[clampi(schritt, 0, TAFEL.size() - 1)][&"titel"])


static func satz(schritt: int) -> String:
    return String(TAFEL[clampi(schritt, 0, TAFEL.size() - 1)][&"satz"])


static func ziel(schritt: int) -> int:
    return int(TAFEL[clampi(schritt, 0, TAFEL.size() - 1)][&"ziel"])


## Ob dieser Schritt im Koloniebildschirm steht statt im Schlund. Der
## Bildschirm deckt das HUD ab; ein Satz, der dort faellig ist, muss dort
## gezeichnet werden, sonst zeigt er auf etwas, das gerade nicht zu sehen ist.
static func in_der_kolonie(schritt: int) -> bool:
    return gilt(schritt) and ziel(schritt) == Ziel.KAMMERN
