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
    KAMMERN,        ## Die Kammerliste.
    LINIEN,         ## Der Reiter mit den Brutlinien.
    TAG,            ## Der Tagesreiter.
}

## Der Einstieg **in die Kolonie**, und nur dorthin.
##
## **Er zeigte lange gar nichts.** Vorher standen hier neun Schritte, die
## den Spieler durch die Schlundwache fuehrten - rufen, ziehen, treffen, die
## Brut halten, einen Polypen setzen. Die Schleife ist geloescht, und der
## einzige Aufrufer war `wache.gd`: seit deren Loeschung setzte niemand mehr
## den Schritt, `_lehre` blieb auf -1, und ein neuer Spieler bekam die Fahrt
## erklaert und den Ausbau **gar nicht**. Toter Code, der aussieht wie ein
## Einstieg.
##
## Die Fahrt erklaert sich seither selbst (`rundlauf.gd::LEHRE`, drei Saetze
## waehrend gespielt wird). Was dort nicht hingehoert, ist die Kolonie: sie
## ist ein eigener Bildschirm, man kommt freiwillig hin, und dort hat ein
## Satz Platz. Also erklaert dieser Pfad genau das - und hoert auf, wo der
## Bildschirm aufhoert.
const TAFEL: Array[Dictionary] = [
    {
        &"kennung": &"KAMMER",
        &"titel": "RAISE A CHAMBER",
        &"satz": "Tap a chamber to raise it. It takes time to dig, and it keeps digging while you are away - even with the app closed.",
        &"ziel": Ziel.KAMMERN,
    },
    {
        &"kennung": &"WOFUER",
        &"titel": "WHAT THE CHAMBERS DO",
        &"satz": "The light organ makes the beam burn hotter and hold more at once. The brood chamber is your hull. The polyp chamber sends more escorts down with you.",
        &"ziel": Ziel.KAMMERN,
    },
    {
        &"kennung": &"SCHACHT",
        &"titel": "THE SHAFT OPENS THE TRENCH",
        &"satz": "The deep shaft is what lets you dive further. Raise it and the next section of the trench opens.",
        &"ziel": Ziel.KAMMERN,
    },
    {
        &"kennung": &"LINIEN",
        &"titel": "BREED A LINE",
        &"satz": "Lines are bred, never drawn - you pick one, nutrients are the price, the result is fixed. Several can carry at once; the brood chamber opens the slots.",
        &"ziel": Ziel.LINIEN,
    },
    {
        &"kennung": &"TAG",
        &"titel": "COME BACK TOMORROW",
        &"satz": "Three waves a day pay double, and the calendar hands you something for showing up. The trench keeps what you earned either way.",
        &"ziel": Ziel.TAG,
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


## Die feste Kennung eines Schritts. Deutsch und unveraenderlich - der
## Bildschirm fragt danach, ob der Spieler getan hat, wovon der Satz redet,
## und ein angezeigter Titel darf sich aendern, ohne dass das bricht.
static func kennung(schritt: int) -> StringName:
    return TAFEL[clampi(schritt, 0, TAFEL.size() - 1)][&"kennung"]


static func ziel(schritt: int) -> int:
    return int(TAFEL[clampi(schritt, 0, TAFEL.size() - 1)][&"ziel"])


## Wieviele Reiter der Koloniebildschirm hat.
##
## **Steht hier, obwohl der Bildschirm sie zeichnet.** `Lehrpfad.reiter()`
## gibt einen Reiterindex zurueck, also muss die Datenschicht wissen, wieviele
## es gibt - sonst zeigt ein Schritt auf einen Reiter, den es nicht gibt, und
## das faellt erst auf, wenn ihn jemand erreicht. Der Testlauf haelt die Zahl
## gegen das `enum Sicht` in `kolonie_schirm.gd`.
const REITER_ANZAHL := 6


## Auf welchem Reiter dieser Schritt faellig ist. Ein Satz ueber die
## Brutlinien, der auf dem Kammerreiter steht, zeigt auf etwas, das gerade
## nicht zu sehen ist.
static func reiter(schritt: int) -> int:
    match ziel(schritt):
        Ziel.LINIEN:
            return 1
        Ziel.TAG:
            return 4
        _:
            return 0
