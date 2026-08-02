# 🎴 ARKANWETT
### *Wo Strategie auf Bluff trifft*

Ein strategisches 1-gegen-1-Kartenspiel, das die taktische Tiefe von Kreaturenduellen mit dem psychologischen Nervenkitzel von Poker-Einsätzen verbindet. Spieler beschwören Wesen, wirken Zauber und setzen gleichzeitig Energie-Chips ein, um Runden für sich zu entscheiden — wer bluffen kann und die richtigen Wesen zur richtigen Zeit einsetzt, gewinnt.

**Das Spiel ist gebaut und spielbar** — als Android-App gegen den „Arkanmeister“, eine KI mit eigenem Einsatzverhalten inklusive Bluff. → [Loslegen](#loslegen)

---

## Warum ARKANWETT kein Klon ist

| Element | Inspiration | Was ARKANWETT anders macht |
|---|---|---|
| Chips/Einsätze | Poker | Chips sind keine reine Wettwährung, sondern auch die Ressource, mit der Wesen beschworen und Zauber aktiviert werden — Bluffen kostet also echte Spielstärke, nicht nur Geld. |
| Kreaturen & Kampf | Sammelkartenspiele | Kämpfe werden nicht nur durch ANG/VER-Werte entschieden, sondern durch einen **Einsatz-Multiplikator**, den beide Spieler zuvor per Bietrunde festgelegt haben. |
| Kartenkombinationen | Poker-Blätter | Am Rundenende bilden gespielte Karten **Schicksalshände** (Elementar-Paar, Stufen-Straße, Element-Flush …), die einzigartige, spielspezifische Boni statt Geldgewinne auslösen. |
| Gewinnbedingung | Beide Genres | Man gewinnt entweder, indem man die Lebenspunkte des Gegners auf 0 bringt **oder** ihn komplett aus Chips herausdrängt — zwei parallele Wege, die sich gegenseitig taktisch beeinflussen. |

---

## Loslegen

Ziel dieser Ausbaustufe ist **Android**. Zwei Wege:

**App bauen** — `android/` in Android Studio öffnen und starten, oder:

```bash
cd android && ./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

**Ohne Build ausprobieren** — das Spiel ist eine PWA:

```bash
npm start          # bedient web/ auf Port 8000
```

Am Telefon `http://<IP-des-Rechners>:8000` in Chrome öffnen → *Zum Startbildschirm
hinzufügen*. Läuft danach im Vollbild und offline.

Alle Details, Grenzen und der Build-Status: **[docs/ANDROID.md](docs/ANDROID.md)**.

---

## Spielmaterial

- 2 Spieler (Grundversion, erweiterbar auf 4 im "Arena-Modus")
- 1 Deck pro Spieler (40 Karten)
- 20 Energie-Chips pro Spieler zu Rundenbeginn
- Lebenspunkte-Zähler (Start: 20)
- Optional: Spielmatte mit markierten Zonen (Wesen-Zone, Aktionszone, Chip-Pool)

---

## Die Karten

### Wesen-Karten
Haben eine **Stufe** (1–10), ein **Element**, Angriffs- (ANG) und Verteidigungswert (VER) sowie oft eine Sonderfähigkeit.

### Aktionskarten
- **Zauber** – sofortige Effekte, offen gespielt
- **Fallen** – verdeckt gelegt, lösen bei einer Bedingung aus

### Schicksalskarten
Seltene Karten mit starken, aber riskanten Effekten — sie kosten zusätzlich Chips aus dem eigenen Pool und können so einen Bluff teuer machen.

---

## Elementsystem

Fünf Elemente in einem Kreislauf, plus ein Gegenpaar:

```
Feuer → Erde → Luft → Wasser → Feuer   (jedes ist stark gegen das nächste)
Licht ⇄ Schatten                        (neutralisieren sich, dominieren sonst alle anderen)
```

---

## Spielablauf

1. **Vorbereitung** – Deck mischen, Starthand (5 Karten) ziehen, Chips verteilen
2. **Einsatzphase** – wie bei Poker: Setzen, Erhöhen, Mitgehen oder Aussteigen. Der finale Einsatz bestimmt den Kampf-Multiplikator der Runde
3. **Beschwörungsphase** – Wesen und Aktionskarten ausspielen (bezahlt mit Chips)
4. **Kampfphase** – Wesen treten an; Schaden = (ANG − VER) × Einsatz-Multiplikator
5. **Schicksalsphase** – offene Karten werden auf Schicksalshände geprüft, Boni werden ausgelöst
6. **Auswertung** – Lebenspunkte-Abzug, nicht genutzte Chips wandern in den nächsten Zug

> Die App rechnet nach genau diesen Regeln, mit einigen für eine spielbare
> Umsetzung nötigen Präzisierungen — jede davon ist in
> [docs/REGELN.md](docs/REGELN.md#abweichungen-vom-design-dokument) begründet.
> Die wichtigste: Schicksalshände werden **vor** dem Kampf ermittelt, weil ihre
> Boni sonst ins Leere liefen.

---

## Schicksalshände (Bonus-Kombinationen)

| Hand | Bedingung | Effekt |
|---|---|---|
| Elementar-Paar | 2 Wesen gleichen Elements im Feld | +2 ANG auf beide |
| Stufen-Straße | 3 Wesen mit aufsteigender Stufe | Nächste Wesen-Beschwörung kostenlos |
| Element-Flush | Alle Feldwesen teilen ein Element | Gegnerische Fallen werden für die Runde deaktiviert |
| Vollbund | Paar + Drilling gleichzeitig | 5 Chips vom Gegner-Pool abziehen |
| Schattenlicht | Licht- und Schattenwesen gleichzeitig im Feld | Doppelter Schaden in der Kampfphase |

---

## Gewinnbedingungen

Ein Spieler gewinnt, sobald **eine** dieser Bedingungen eintritt:
- Die Lebenspunkte des Gegners erreichen 0
- Der Gegner hat keine Chips mehr und kann in der Einsatzphase nicht mehr mitgehen

---

## Beispielrunde

Spieler A setzt 3 Chips, Spieler B erhöht auf 5 — A geht mit, der Kampf-Multiplikator liegt bei ×2. A beschwört ein Feuer-Wesen (Stufe 4, ANG 1600), B kontert mit einem Wasser-Wesen (Stufe 5, ANG 1800). Da Wasser gegen Feuer im Vorteil ist, erhält B's Wesen +400 ANG. A spielt eine verdeckte Falle, die den Elementvorteil aufhebt — der Bluff aus der Einsatzphase zahlt sich aus, A gewinnt den Schlagabtausch.

*Elementvorteil und Fallenwirkung dieser Runde sind als Testfälle hinterlegt
(`tests/engine.test.js`). Ein Detail entscheidet die App strenger als das
Beispiel: Zerstört wird jedes Wesen, dessen VER überschritten wird — hier fallen
also beide. Lebenspunkte kostet nur der Überschuss.*

---

## Projektstruktur

```
web/                Das Spiel – reines HTML/CSS/JS, kein Build-Schritt
  index.html        Brett im Hochformat
  styles.css        Oberfläche für Telefone
  js/elements.js    Elementkreislauf
  js/cards.js       Kartenpool und Deckbau
  js/hands.js       Schicksalshände
  js/game.js        Regel-Engine (Phasen, Kampf, Auswertung) – ohne DOM
  js/ai.js          Der „Arkanmeister“
  js/ui.js          Rendern und Eingaben
  js/main.js        Steuerung, lässt die KI sichtbar ziehen

android/            Native Hülle (Kotlin + WebView), bindet web/ als Assets ein
tests/              36 Tests der Engine (node --test)
docs/REGELN.md      Regeln, wie die App sie rechnet
docs/ANDROID.md     Bauen, installieren, bekannte Grenzen
```

Die Engine kennt keine Oberfläche und die Oberfläche keine Regeln — dieselben
Dateien laufen im Browser, in der App und unter Node in den Tests.

## Entwicklung

```bash
npm test           # Regel-Engine prüfen
npm start          # web/ lokal ausliefern
```

## Projektstatus & Roadmap

- [x] Vollständige Kartenliste (Wesen, Zauber, Fallen, Schicksalskarten) ausarbeiten — 26 Wesen und 17 Aktionskarten, siehe `web/js/cards.js`
- [x] Digitale Umsetzung als Android-App (KI-Gegner, vollständiger Rundenablauf)
- [x] Testrunden mit angepassten Chip-/Lebenspunkte-Werten — Balance über 400 simulierte KI-Duelle geprüft (Median 7 Runden)
- [ ] Erste Installation auf einem echten Gerät (Build in der Entwicklungsumgebung gesperrt, siehe [docs/ANDROID.md](docs/ANDROID.md))
- [ ] Spielstand über App-Neustarts sichern
- [ ] Physischer Prototyp zum Testen der Balance am Tisch
- [ ] Ton, Vibration und Kampfanimationen
- [ ] Arena-Modus für 4 Spieler

## Mitwirken

Ideen, Balancing-Vorschläge und neue Kartenkonzepte sind willkommen — einfach ein Issue oder einen Pull Request eröffnen.

## Lizenz

Noch offen (TBD).
