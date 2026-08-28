# Vertragsfristen-Wächter

Überwacht Kündigungsfristen von Versicherungen, Software-Abos, Miet-, Leasing-
und Wartungsverträgen — und meldet sich, bevor ein Stichtag verstreicht.

Das Problem ist unspektakulär und teuer: Verträge verlängern sich still um ein
weiteres Jahr, weil niemand rechtzeitig gekündigt hat. Die Frist steht im
Vertrag, aber niemand rechnet sie aus, und wer sie ausrechnet, trägt sie
nirgends ein. Der Wächter macht beides.

## Was er kann

- **Stichtag statt Laufzeit.** Aus Beginn, Laufzeit, Verlängerung und
  Kündigungsfrist wird der Tag berechnet, an dem die Kündigung spätestens
  zugehen muss — auch bei Kündigung zum Monats-, Quartals- oder Jahresende und
  bei laufender Mindestlaufzeit.
- **Erinnerungen.** Ein täglicher Fristenlauf prüft alle aktiven Verträge und
  verschickt eine Sammelmail, sobald eine Frist in den eingestellten Vorlauf
  rutscht (voreingestellt 90, 30, 14 und 3 Tage vorher).
- **Kalender-Abo.** Alle Stichtage als `.ics`-Adresse für Outlook, Google
  Kalender oder Thunderbird, mit Erinnerung zwei Wochen vorher.
- **Kostenübersicht.** Jahreskosten je Kategorie und die Summe, die an den
  demnächst fälligen Verträgen hängt.
- **Ausgabe als CSV** für Excel, mit Semikolon und BOM.

## Loslegen

```bash
cd vertragsfristen-waechter
npm install
npm run dev            # Server auf :4000, Oberfläche auf :5173
```

Beim ersten Aufruf ein Konto anlegen; unter *Einstellungen → Beispieldaten*
lässt sich ein Bestand typischer Verträge einspielen.

Für den Dauerbetrieb:

```bash
npm run build
npm start              # ein Prozess, liefert auch die Oberfläche aus
```

### Einstellungen

Alles über Umgebungsvariablen, siehe `.env.beispiel`. Ohne Angaben läuft der
Wächter lokal mit einer SQLite-Datei unter `daten/`.

| Variable | Bedeutung |
|---|---|
| `PORT`, `HOST` | wo der Server lauscht (Vorgabe `127.0.0.1:4000`) |
| `DATENBANK` | Pfad der SQLite-Datei |
| `BASIS_ADRESSE` | Adresse der Oberfläche; steht in Mails und im Kalender-Abo |
| `SMTP_URL` | z. B. `smtps://nutzer:kennwort@mail.example:465` |
| `ABSENDER` | Absenderadresse der Erinnerungen |
| `PLANER_TAKT_MINUTEN` | Abstand zwischen zwei Fristenläufen (Vorgabe 60) |

**Ohne `SMTP_URL` wird nichts verschickt.** Die Erinnerungen entstehen
trotzdem und liegen im Postausgang, wo sich ihr Wortlaut ansehen lässt — so
lässt sich alles ausprobieren, bevor Zugangsdaten hinterlegt werden.

## Wie gerechnet wird

Die Regeln stecken in `src/fachlogik/fristen.ts`, ohne Datenbank- und
Netzbezug. Server und Oberfläche rufen dieselbe Funktion auf: was das Formular
beim Tippen anzeigt, steht nach dem Speichern auch in der Liste.

| Laufzeitmodell | Stichtag |
|---|---|
| feste Laufzeit mit Verlängerung | Laufzeitende der nächsten erreichbaren Periode minus Frist |
| feste Laufzeit ohne Verlängerung | kein Stichtag; überwacht wird der Auslauf |
| unbefristet | nächster Monats-, Quartals- oder Jahreswechsel, dessen Frist noch läuft |
| jederzeit kündbar | kein Termin; angezeigt wird, wann der Vertrag bei Kündigung heute endet |

Drei Feinheiten, die in der Praxis den Unterschied machen:

- **Rückwärts gerechnet mit Monatskappung.** Drei Monate vor dem 31.12. ist der
  30.09.; drei Monate vor dem 30.04. der 30.01.
- **Perioden hängen am Vertragsbeginn**, nicht aneinander. Kettenrechnung
  driftet über kurze Monate weg — ein am 31. beginnender Monatsvertrag wandert
  sonst nach jedem Februar einen Tag nach vorn.
- **Verstrichene Fristen führen weiter.** Ist der Stichtag der laufenden
  Periode vorbei, wird der nächste erreichbare genannt, zusammen mit dem
  Hinweis, bis wann sich der Vertrag nun verlängert.

Ob eine Kündigung fristgerecht war, entscheidet am Ende der Vertrag, nicht
dieses Programm. Für Verträge zwischen Unternehmen sind lange automatische
Verlängerungen zulässig; die seit 2022 für Verbraucher geltende Monatsfrist
(§ 309 Nr. 9 BGB) greift dort nicht.

## Aufbau

```
src/fachlogik/   Fristenrechnung, Formate, Beispieldaten, CSV — reine Funktionen
src/server/      Fastify, SQLite, Sitzungen, Fristenlauf, Mailversand, Kalender
src/web/         React-Oberfläche; nutzt dieselbe Fachlogik für die Vorschau
werkzeuge/       Hilfsskripte für den Bau
```

Getrennt bleibt: `src/fachlogik` kennt weder Datenbank noch Netz und lässt sich
deshalb vollständig testen; `src/server` ist der einzige Ort mit SQL.

## Tests

```bash
npm test          # Fachlogik und Schnittstelle
npm run pruefen   # zusätzlich Typprüfung
```

Abgedeckt sind die Datumsrandfälle (Schaltjahr, Monatsende, Sommerzeit), alle
Laufzeitmodelle, der Fristenlauf und die Schnittstelle samt Mandantentrennung —
eine Organisation sieht die Verträge einer anderen nicht.

## Demo ohne Server

```bash
npm run demo      # bau/demo/vertragsfristen-waechter.html
```

Baut die Oberfläche zu einer einzigen HTML-Datei, die alles im Browser ablegt:
kein Server, keine Anmeldung, kein Mailversand. Gedacht zum Vorführen; der
Fristenlauf läuft dort nur, während die Seite offen ist.

## Was noch fehlt

- Weitere Konten je Organisation einladen (das Datenmodell trägt es bereits,
  die Oberfläche noch nicht)
- Vertragsdokumente hochladen statt nur zu verlinken
- Import bestehender Bestände aus CSV

## Fremde Bestandteile

Schriften: IBM Plex Sans, Serif und Mono (SIL Open Font License 1.1), geladen
über Google Fonts. Pakete siehe `package.json`.
