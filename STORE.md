# Play Store — was fertig ist und was nur du selbst machen kannst

Diese Datei ist die Abgabemappe. Alles, was hier in Kästen steht, lässt sich
so übernehmen; alles unter **Deine Schritte** kann kein Bauauftrag erledigen,
weil dafür ein Konto, eine Zahlung oder ein Schlüssel nötig ist.

---

## 1. Was der Bauauftrag liefert

| Datei | Wo | Wofür |
|---|---|---|
| `tenthousand.aab` | Artefakt `tenthousand-play` des CI-Laufs | Der Upload für die Play Console |
| `tenthousand.apk` | Anhang der Vorabveröffentlichung | Zum Ausprobieren auf dem eigenen Telefon |
| `tenthousand.html` | Anhang der Vorabveröffentlichung | Dasselbe Spiel in einer Datei, im Browser |
| `privacy.html` | GitHub Pages, `…/privacy.html` | Die Pflichtadresse für die Datenschutzerklärung |

Das App Bundle entsteht nur, wenn die vier Geheimnisse hinterlegt sind
(siehe unten). Ohne sie überspringt der Auftrag den Schritt und meldet das,
statt den ganzen Bau zu fällen.

---

## 2. Deine Schritte

### a) Signierschlüssel erzeugen — einmalig, und gut aufbewahren

```bash
keytool -genkeypair -v -keystore tenthousand.keystore -alias tenthousand \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 tenthousand.keystore > tenthousand.keystore.b64
```

**Geht dieser Schlüssel verloren, lässt sich die App nie wieder
aktualisieren.** Nimm in der Play Console die *Play App Signing* an — dann
hält Google den Verteilschlüssel, und dieser hier ist nur noch der
Upload-Schlüssel, den man notfalls austauschen kann.

### b) Vier Geheimnisse im Repository hinterlegen

Settings → Secrets and variables → Actions → *New repository secret*:

| Name | Inhalt |
|---|---|
| `PLAY_KEYSTORE_BASE64` | der Inhalt von `tenthousand.keystore.b64` |
| `PLAY_KEYSTORE_PASSWORD` | das Store-Passwort aus a) |
| `PLAY_KEY_ALIAS` | `tenthousand` |
| `PLAY_KEY_PASSWORD` | das Key-Passwort aus a) |

### c) GitHub Pages einschalten

Settings → Pages → Build and deployment → Source: **GitHub Actions**.
Ohne das gibt es keine öffentliche Adresse für die Datenschutzerklärung, und
die verlangt Google.

### d) Play Console

* Entwicklerkonto anlegen (einmalig 25 USD).
* Neue App: Name **Ten Thousand**, Sprache Englisch, Typ *Spiel*, kostenpflichtig.
  Die Paketkennung ist `de.tenthousand.horde` (`export_presets.cfg`). **Sie
  ist ab dem ersten Hochladen endgültig** — bis dahin lässt sie sich frei
  ändern, danach nie mehr.
* Preis setzen. Für ein Spiel dieses Umfangs sind 2,99 bis 3,99 € der
  übliche Rahmen.
* Bundle aus dem Artefakt `tenthousand-play` hochladen.
* Die Formulare unter Punkt 4 ausfüllen.
* Vor der ersten Veröffentlichung verlangt Google einen geschlossenen Test
  mit echten Testern über mehrere Tage. Das ist kein Formfehler, den man
  umgeht — es ist eine Wartezeit, die eingeplant gehört.

---

## 3. Store-Eintrag

**Titel** (max. 30 Zeichen)

```
Ten Thousand: One vs the Horde
```

**Kurzbeschreibung** (max. 80 Zeichen)

```
One finger steers the man. The weapons swing themselves. Last ten minutes.
```

**Vollständige Beschreibung** (max. 4000 Zeichen)

```
One man, seen from above, and a horde that does not stop coming. Hold out for
ten minutes and the Warlord takes the field.

Your finger steers the man — nothing else. Put your thumb down anywhere and
drag; that is the whole control scheme. The weapons strike on their own, at
whoever is nearest. What you decide is where to stand: which way to run, whom
to let in front of you, when to slip through a gap before it closes.

SURROUNDED IS WORSE THAN OUTNUMBERED
Twenty brigands on one side cost you what one does. Eight all around cost four
times as much. A red ring at your feet shows how closed in you are, so you
see it coming before you feel it. Keep a flank open and you are rewarded, not
merely spared.

CHOOSE WHAT YOU BECOME
Every level brings three offers, never three of the same. Six weapons, each
asking something different of you: the arming sword cuts an arc before you,
the boar spear thrusts at whatever is on your heels, the flail swings close
about you, the crossbow looses at the nearest, the war hammer pays when they
crowd you, the throwing axe flies out and comes back. And six ways to grow
between them — mail, boots, a whetstone, a lantern that draws in coin, rations
that close your wounds, and sworn men who fight at your back while you give
ground.

SEVEN FOES, EACH ITS OWN QUESTION
Brigands, wolves and pikemen simply come. Crossbowmen keep their distance and
shoot, so you must go to them. Knights gather and charge. The standard bearer
drives the men around him faster — take him first. Each arrives in its own
time, so you learn one before the next.

BETWEEN RUNS
The keep is the steady climb: a wall for more life, a forge for harder blows,
a stable for speed, a mint for more coin — twenty-five levels each. Every run
ends with a find, even a short one: helms, hauberks, rings and cloaks, one
piece for each of four places, each doing exactly one thing.

Four heroes — the Swordsman, the Archer, the Spearman and the Hammerman — each
with exactly one trait, unlocked by deeds rather than bought. Twelve garments
to wear, also earned by deeds, and they change nothing but your colours.

NO STRINGS
One price, once. No ads. No loot boxes. No energy meter. No second currency.
No account, no sign-in, no internet connection — the game does not collect a
single thing about you, because there is no code in it that could.

Everything you see and hear was made for this game and generated by it: the
figures are drawn in code, every sound is synthesised as it plays. There is
not one image file and not one audio file in the whole app.
```


**Kategorie**: Spiele → Action
**Tags**: Action, Casual, Single player, Offline
**Kontakt**: david.knoll.csgo@gmail.com
**Datenschutzerklärung**: `https://<benutzer>.github.io/<repo>/privacy.html`

---

### Grafiken

Beides entsteht aus dem laufenden Spiel, nicht in einem Grafikprogramm — aus
demselben Grund wie alles andere hier: `ASSETS.md` führt keine Bilddatei
außer dem App-Symbol, und ein zugekauftes Ladenbild wäre der erste Eintrag.

```bash
tools/ladenbilder.sh build/laden    # fünf Screenshots, 1080x1920
tools/ladengrafik.sh build/laden    # das Feature-Bild, 1024x500
```

Jeder Lauf legt sich einen eigenen, leeren Spielstand an. **Eine Aufnahme,
die den Spielstand der Maschine zeigt, zeigt nicht das Spiel**, und das fällt
erst auf, wenn der Eintrag schon steht.

Die Gefechtsbilder rechnet `--zeit` mit `Daumen` vor — demselben simulierten
Daumen, den `tools/probe.gd` misst, bis hin zur Wahl beim Aufstieg. Ein
Ladenbild aus einem Lauf, den es nicht gibt, wäre Werbung für ein anderes
Spiel.

## 4. Formulare — die Antworten

### Datensicherheit (Data safety)

| Frage | Antwort |
|---|---|
| Erhebt oder teilt deine App Nutzerdaten? | **Nein** |
| Werden Daten verschlüsselt übertragen? | entfällt — es wird nichts übertragen |
| Können Nutzer die Löschung beantragen? | entfällt — es liegt nichts vor |

Das ist keine geschönte Antwort, sondern der Zustand des Programms: kein
HTTP-Client, kein Web-Socket, keine Werbe- oder Auswertungsbibliothek, keine
Geräte-Kennung.

**Genau eine Android-Berechtigung**, und die ist `android.permission.VIBRATE`:
das Spiel bebt, wenn der Held getroffen wird, beim Aufstieg, wenn der Warlord
das Feld betritt, und am Ende eines Laufs. VIBRATE ist eine normale
Berechtigung — sie fragt beim Benutzer nichts ab, liest nichts und erhebt
nichts; sie darf nur den Vibrationsmotor anstoßen. An den Antworten oben
ändert sie deshalb nichts. Abschaltbar ist sie im Spiel unter **Keep →
Rumble**, der Ton daneben unter **Keep → Sound**.

Nachprüfbar mit `aapt dump badging tenthousand.apk`: in der Berechtigungsliste steht
diese eine Zeile und sonst nichts. Kommt je eine zweite hinzu, gehört sie in
demselben Commit hierher — eine Abgabemappe, die eine Berechtigung verschweigt,
ist schlimmer als gar keine.

**Nicht erschrecken, wenn `strings` mehr findet.** Ein `strings` über das
`AndroidManifest.xml` der APK zeigt zusätzlich `android.permission.DUMP`.
Godots Exporter legt Berechtigungsnamen im Zeichenvorrat des Manifests an,
ohne sie zu deklarieren; ein Zeichenvorrat wird nicht aufgeräumt. Gezählt
werden `<uses-permission>`-**Tags**, und davon gibt es genau einen — im Manifest
der gebauten APK nachgeparst, nicht angenommen. Genau das listet `aapt` auch.

### Inhaltseinstufung (Content rating)

| Frage | Antwort |
|---|---|
| Gewalt | **Ja, gegen menschenähnliche Figuren**, in einem erfundenen Mittelalter: Räuber, Pikeniere, Armbruster, Ritter, dazu Wölfe. Von oben gesehen, die Figuren wenige Millimeter groß und gezeichnet, nicht realistisch. Waffen schlagen selbsttätig; ein Erschlagener verschwindet in einem Funkenstoß in seiner eigenen Farbe. Wird der Held getroffen, stieben zinnoberrote Funken — gezeichnet als Signal, im selben Stil, nicht als Blut. Keine Verletzungsdarstellung, keine Leichen, die liegen bleiben |
| Sexuelle Inhalte, Drogen, Glücksspiel, Schimpfwörter | Keine. Der Fund nach einem Lauf ist zufällig, aber weder kaufbar noch gegen Geld tauschbar — kein Glücksspiel im Sinne des Fragebogens |
| Nutzerinteraktion, geteilter Standort, Käufe in der App | Keine |

Erwartete Einstufung: **PEGI 7 / ESRB Everyone 10+** (Fantasy-Gewalt). Die
Einstufung vergibt der IARC-Fragebogen, nicht diese Mappe — die Antworten
oben sind die, die der Stand des Spiels hergibt.

**Hier stand bis September 2026 „keine Gewalt gegen menschenähnliche
Figuren“ und PEGI 3** — die Antwort für NEKTON, zwei Spiele zuvor. Eine
falsche Antwort im Einstufungsfragebogen ist kein Formfehler: Google kann die
App dafür entfernen.

### Werbung

Enthält keine Werbung.

---

## 5. Was noch fehlt, ehrlich benannt

* **Der geschlossene Test.** Google verlangt ihn vor der ersten
  Veröffentlichung. Dafür braucht es echte Testgeräte und echte Tester —
  und genau dort zeigen sich die Fehler, die kein Simulator findet.
* **Ein zweites Gerät.** Alle Messungen hier laufen in Software-Rasterung
  ohne Grafikkarte. Was das über ein echtes Telefon sagt, ist wenig.
