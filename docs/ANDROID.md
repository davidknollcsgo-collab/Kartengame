# ARKANWETT auf Android

Zwei Wege auf ein Telefon — der erste braucht keinerlei Werkzeug, der zweite
liefert eine echte App mit Icon im Launcher.

---

## Weg 1: APK bauen (die eigentliche App)

Das Projekt unter `android/` ist eine schlanke native Hülle: eine Activity mit
einer WebView, die das Spiel aus `web/` als lokale Assets lädt. Kein Netzwerk,
kein Tracking, keine Berechtigungen — die App fordert bewusst **nicht einmal
`INTERNET`** an.

### Mit Android Studio

1. Android Studio öffnen → *Open* → Ordner `android/` wählen
2. Gradle-Sync abwarten (lädt Android Gradle Plugin 8.7.2 und Kotlin 2.0.21)
3. Telefon per USB anschließen (USB-Debugging aktiv) → *Run*

### Auf der Kommandozeile

Voraussetzung: JDK 17+ und Android SDK, `ANDROID_HOME` gesetzt.

```bash
cd android
./gradlew assembleDebug
# Ergebnis: app/build/outputs/apk/debug/app-debug.apk

adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Für eine signierte Release-APK zusätzlich einen Keystore anlegen und in
`app/build.gradle.kts` eine `signingConfig` ergänzen.

### Technische Eckdaten

| Punkt | Wert |
|---|---|
| Package | `de.arkanwett` |
| minSdk / targetSdk | 24 (Android 7.0) / 35 |
| Ausrichtung | fest Hochformat |
| Berechtigungen | keine |
| Größe | wenige hundert KB — das Spiel sind reine Textdateien |

Besonderheiten der Hülle (`android/app/src/main/java/de/arkanwett/MainActivity.kt`):

- `web/` wird über `sourceSets["main"].assets.srcDir(...)` **direkt** eingebunden.
  Es gibt keine Kopie im Android-Verzeichnis, die veralten könnte.
- Fenster-Insets (Statusleiste, Navigationsleiste, Display-Aussparung) werden als
  Padding auf die WebView gelegt — nichts wird überlagert.
- Die Zurück-Taste schließt erst Kartendetail bzw. Zielauswahl (`window.ARKANWETT_ZURUECK`),
  danach erst die App.
- Der Bildschirm bleibt während des Duells an.
- Die Schriftvergrößerung des Systems wirkt, ist aber auf 115 % gedeckelt —
  darüber passt das Brett nicht mehr auf ein Telefon.

---

## Weg 2: Ohne Build — als PWA installieren

`web/` ist eine vollwertige Progressive Web App mit Manifest und Service Worker.

```bash
# auf dem Rechner, im Projektordner:
python3 -m http.server 8000 --directory web
```

Am Telefon im selben WLAN `http://<IP-des-Rechners>:8000` in Chrome öffnen →
Menü → *Zum Startbildschirm hinzufügen*. Danach startet das Spiel im Vollbild
ohne Browserleiste und läuft dank Service Worker auch offline.

Dasselbe funktioniert mit jedem Static-Hosting (GitHub Pages, Netlify …):
einfach den Inhalt von `web/` ausliefern.

---

## Bekannte Grenzen

- Der Spielstand überlebt keinen App-Neustart. Innerhalb der Sitzung bleibt er
  über `WebView.saveState` erhalten, ein Kaltstart beginnt ein neues Duell.
- Es gibt keinen Ton und keine Vibration.
- Getestet wurde das Layout in Chromium bei Telefongrößen (Pixel-7-Viewport,
  412 × 915 dp) sowie mit der Regel für niedrige Bauhöhen ab 680 px. Auf einem
  echten Gerät wurde die App bislang **nicht** ausgeführt — siehe Hinweis unten.

> **Hinweis zum Build-Status:** Die APK konnte in der Entwicklungsumgebung nicht
> kompiliert werden, weil dort `dl.google.com` (Android SDK und Android Gradle
> Plugin) durch die Netzwerkrichtlinie gesperrt ist. Geprüft sind Spiel-Engine
> (36 Tests), das Layout im mobilen Browser und die Wohlgeformtheit aller
> Android-Ressourcen. Der erste `./gradlew assembleDebug`-Lauf auf einem Rechner
> mit Netzzugang ist noch offen.
