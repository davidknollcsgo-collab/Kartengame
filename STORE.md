# Play Store — was fertig ist und was nur du selbst machen kannst

Diese Datei ist die Abgabemappe. Alles, was hier in Kästen steht, lässt sich
so übernehmen; alles unter **Deine Schritte** kann kein Bauauftrag erledigen,
weil dafür ein Konto, eine Zahlung oder ein Schlüssel nötig ist.

---

## 1. Was der Bauauftrag liefert

| Datei | Wo | Wofür |
|---|---|---|
| `nekton.aab` | Artefakt `nekton-play` des CI-Laufs | Der Upload für die Play Console |
| `nekton.apk` | Anhang der Vorabveröffentlichung | Zum Ausprobieren auf dem eigenen Telefon |
| `nekton.html` | Anhang der Vorabveröffentlichung | Dasselbe Spiel in einer Datei, im Browser |
| `privacy.html` | GitHub Pages, `…/privacy.html` | Die Pflichtadresse für die Datenschutzerklärung |

Das App Bundle entsteht nur, wenn die vier Geheimnisse hinterlegt sind
(siehe unten). Ohne sie überspringt der Auftrag den Schritt und meldet das,
statt den ganzen Bau zu fällen.

---

## 2. Deine Schritte

### a) Signierschlüssel erzeugen — einmalig, und gut aufbewahren

```bash
keytool -genkeypair -v -keystore nekton.keystore -alias nekton \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 nekton.keystore > nekton.keystore.b64
```

**Geht dieser Schlüssel verloren, lässt sich die App nie wieder
aktualisieren.** Nimm in der Play Console die *Play App Signing* an — dann
hält Google den Verteilschlüssel, und dieser hier ist nur noch der
Upload-Schlüssel, den man notfalls austauschen kann.

### b) Vier Geheimnisse im Repository hinterlegen

Settings → Secrets and variables → Actions → *New repository secret*:

| Name | Inhalt |
|---|---|
| `PLAY_KEYSTORE_BASE64` | der Inhalt von `nekton.keystore.b64` |
| `PLAY_KEYSTORE_PASSWORD` | das Store-Passwort aus a) |
| `PLAY_KEY_ALIAS` | `nekton` |
| `PLAY_KEY_PASSWORD` | das Key-Passwort aus a) |

### c) GitHub Pages einschalten

Settings → Pages → Build and deployment → Source: **GitHub Actions**.
Ohne das gibt es keine öffentliche Adresse für die Datenschutzerklärung, und
die verlangt Google.

### d) Play Console

* Entwicklerkonto anlegen (einmalig 25 USD).
* Neue App: Name **Nekton**, Sprache Englisch, Typ *Spiel*, kostenpflichtig.
* Preis setzen. Für ein Spiel dieses Umfangs sind 2,99 bis 3,99 € der
  übliche Rahmen.
* Bundle aus dem Artefakt `nekton-play` hochladen.
* Die Formulare unter Punkt 4 ausfüllen.
* Vor der ersten Veröffentlichung verlangt Google einen geschlossenen Test
  mit echten Testern über mehrere Tage. Das ist kein Formfehler, den man
  umgeht — es ist eine Wartezeit, die eingeplant gehört.

---

## 3. Store-Eintrag

**Titel** (max. 30 Zeichen)

```
Nekton: Deep Guard
```

**Kurzbeschreibung** (max. 80 Zeichen)

```
One finger, one cone of light, and a trench that comes at you from all sides.
```

**Vollständige Beschreibung** (max. 4000 Zeichen)

```
Deep in a lightless trench, a colony survives on one thing: light. You take a
boat out into the dark water above the trench floor and bring back what the
colony needs to grow.

Hold your finger anywhere on the screen. The light turns to face it, and the
boat drives toward it. What stands in the light burns. What reaches you takes
a piece of the hull. That is the whole control scheme — no buttons to learn,
no aiming reticle, no timing windows. Where the light should be is a harder
question than it sounds once a dozen species are closing from every direction
at once, each of them wrong to treat the same way.

THE DIVE
Five waves to a dive, three or four minutes, and then the report: what you
brought back stays with the colony even when the hull does not.

The trench is unlit until you drive through it. What you have seen stays on
your map; what you have not could be anything. Sites lie buried out there
that only show themselves once you have been close — and so do ambushers. A
quarter of every wave is already lying in the dark when you arrive, waiting
for you to come near.

Guard polyps ride behind you and burn what they can reach. How many is up to
your colony: one at the start, up to eight once the polyp chamber is deep.

SEVENTEEN WAYS TO BE WRONG
Fangjaw comes straight at you and dies fast — the yardstick for everything
else. Shellback is slow enough to ignore and tough enough that ignoring it
costs you. Emberjelly burns only in the core of the beam, never at the edge.
Mirrorshell is the exact opposite: its shell throws the core back, so only
the fringe of the light bites. Driftanchor slides sideways and leaves the
cone even if you hold perfectly still. Shylight backs away while it is lit,
so half a beam only pushes it out of reach. Ringrunner never closes at all —
it circles, and holding the beam on it means you stop steering.

Five wardens close the sections, and none of them is just a bigger animal.
One keeps spawning young while it lives. One will not hold still. One circles
and makes you choose between shooting and driving.

THE COLONY
Between dives the game turns into something slower. Five chambers, dug down a
shaft into the rock: a brighter light organ, more and stronger guard polyps,
a thicker hull, nutrients that accrue while you are away, and a shaft that
opens the trench deeper. Build times run from minutes to hours — enough to
give the day a rhythm, never enough to make you wait for permission to play.

THE TRENCH HAS NO FLOOR
Every ten waves the trench changes its rules: a current that bends your aim,
raiders that avoid light, stretches of darkness. Past the sixth section the
raiders begin to mutate — plated, lightshy, erratic, bloated — in
combinations that keep arriving as long as you keep descending. There is no
last wave.

NO STRINGS
One price, once. No ads. No loot boxes. No energy meter. No second currency
you can buy. No account, no sign-in, no internet connection — the game does
not collect a single thing about you, because there is no code in it that
could.

Everything you see and hear was made for this game and generated by it: the
graphics are drawn in code, every sound is synthesised as it plays. There is
not one image file and not one audio file in the whole app.
```


**Kategorie**: Spiele → Strategie
**Tags**: Strategy, Casual, Single player, Offline
**Kontakt**: david.knoll.csgo@gmail.com
**Datenschutzerklärung**: `https://<benutzer>.github.io/<repo>/privacy.html`

---

### Grafiken

Beides entsteht aus dem laufenden Spiel, nicht in einem Grafikprogramm — aus
demselben Grund wie alles andere hier: `ASSETS.md` führt keine Bilddatei
außer dem App-Symbol, und ein zugekauftes Ladenbild wäre der erste Eintrag.

```bash
tools/ladenbilder.sh build/laden    # acht Screenshots, 1080x1920
tools/ladengrafik.sh build/laden    # das Feature-Bild, 1024x500
```

Jeder Lauf legt sich einen eigenen, leeren Spielstand an. Ohne das lief die
Aufnahme auf dem Stand, der zufällig im Behälter lag — und statt des Spiels
stand dann eine Rückkehrtafel im Bild. **Eine Aufnahme, die den Spielstand
der Maschine zeigt, zeigt nicht das Spiel**, und das fällt erst auf, wenn der
Eintrag schon steht.

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
das Spiel bebt bei einem Treffer an der Brut, einem gefallenen Leitwesen, dem
Stoßlicht und dem Ende einer Sitzung. VIBRATE ist eine normale Berechtigung —
sie fragt beim Benutzer nichts ab, liest nichts und erhebt nichts; sie darf nur
den Vibrationsmotor anstoßen. An den Antworten oben ändert sie deshalb nichts.
Abschaltbar ist sie im Spiel unter **Colony → Day → Settings → Rumble**.

Nachprüfbar mit `aapt dump badging nekton.apk`: in der Berechtigungsliste steht
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
| Gewalt | Keine gegen Menschen oder menschenähnliche Figuren. Erfundene Tiefseetiere werden von Licht verbrannt; kein Blut, keine Verletzungsdarstellung |
| Sexuelle Inhalte, Drogen, Glücksspiel, Schimpfwörter | Keine |
| Nutzerinteraktion, geteilter Standort, Käufe in der App | Keine |

Erwartete Einstufung: **PEGI 3 / ESRB Everyone**.

### Werbung

Enthält keine Werbung.

---

## 5. Was noch fehlt, ehrlich benannt

* **Der geschlossene Test.** Google verlangt ihn vor der ersten
  Veröffentlichung. Dafür braucht es echte Testgeräte und echte Tester —
  und genau dort zeigen sich die Fehler, die kein Simulator findet.
* **Ein zweites Gerät.** Alle Messungen hier laufen in Software-Rasterung
  ohne Grafikkarte. Was das über ein echtes Telefon sagt, ist wenig.
