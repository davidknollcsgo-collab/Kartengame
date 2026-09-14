// Browsertest mit echter Eingabe.
//
//     cd tools/browsertest && npm install && node browsertest.mjs
//
// Braucht `docs/` - also vorher:
//     godot --headless --path . --export-release "Web" docs/index.html
//
// **Warum das kein Luxus ist.** Bei HYPHA schluckte das HUD saemtliche
// Beruehrungen, weil ein Control von Haus aus MOUSE_FILTER_STOP hat. Kein
// Screenshot und kein Testschuss aus dem Code hat das gezeigt - jeder
// Entwicklertest rief die Funktionen direkt auf und ging damit an der
// kaputten Stelle vorbei. Erst ein echter Klick im Browser hat es gefunden.
//
// Der Server hier setzt dieselbe strenge Inhaltsrichtlinie wie die
// Artifact-Seite. Ohne sie faellt nicht auf, wenn der Start `data:` oder
// `blob:` braucht - beim Benutzer dann schon.
//
// **Und er hat jahrelang das falsche Spiel geklickt.** Sein erster Schritt
// war "vom Titelbildschirm in die Schlundwache" - eine Schleife, die es seit
// September nicht mehr gibt. Er hat trotzdem bestanden und "Start, alle
// Reiter, Wellenstart, Kegelzug" gemeldet, denn gepruesft wurden genau zwei
// Dinge: dass eine Leinwand da ist und dass die Konsole schweigt. Alles
// andere waren Klicks ins Leere, und ein Klick ins Leere sieht aus wie ein
// Klick, der sitzt.
//
// Deshalb prueft jeder Schritt jetzt sein **Ergebnis**, und zwar am Bild:
// ein Spiel auf einer Leinwand hat kein DOM, an dem man fragen koennte.

import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { lies_png } from './png.mjs';

const HIER = path.dirname(fileURLToPath(import.meta.url));
const WURZEL = path.resolve(HIER, '../../docs');
const PORT = 8731;
const BREITE = 400, HOEHE = 760;

const TYPEN = {
    '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream', '.png': 'image/png',
    '.json': 'application/json',
};

function starte_server() {
    return new Promise((fertig) => {
        const s = http.createServer((anfrage, antwort) => {
            const datei = path.join(WURZEL, anfrage.url === '/' ? '/index.html' : anfrage.url);
            if (!datei.startsWith(WURZEL) || !fs.existsSync(datei)) {
                antwort.writeHead(404); antwort.end(); return;
            }
            antwort.writeHead(200, {
                'Content-Type': TYPEN[path.extname(datei)] ?? 'application/octet-stream',
                'Cross-Origin-Opener-Policy': 'same-origin',
                'Cross-Origin-Embedder-Policy': 'require-corp',
                'Content-Security-Policy':
                    "default-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
                    "connect-src 'self'; worker-src 'self'",
            });
            fs.createReadStream(datei).pipe(antwort);
        });
        s.listen(PORT, '127.0.0.1', () => fertig(s));
    });
}

const fehler = [];
function pruefe(bedingung, was) {
    if (!bedingung) fehler.push(was);
    return bedingung;
}

if (!fs.existsSync(path.join(WURZEL, 'index.pck'))) {
    console.log('FEHLER: docs/index.pck fehlt - erst den Web-Export bauen:');
    console.log('  godot --headless --path . --export-release "Web" docs/index.html');
    process.exit(1);
}

const server = await starte_server();
const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM ?? '/opt/pw-browsers/chromium',
});
const seite = await browser.newPage({ viewport: { width: BREITE, height: HOEHE } });

const konsole = [];
seite.on('pageerror', (e) => konsole.push('pageerror: ' + e.message));
seite.on('console', (m) => { if (m.type() === 'error') konsole.push(m.text()); });

await seite.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: 'load' });
await seite.waitForTimeout(16000);

const leinwand = await seite.$('canvas');
pruefe(leinwand !== null, 'Keine Leinwand - das Spiel ist nicht gestartet');

// --- Was man auf einer Leinwand messen kann -------------------------------

async function bild() {
    return lies_png(await seite.screenshot());
}

// Mittlere Helligkeit. Trennt die Bedienschirme (Tafeln, Text) von der
// Fahrt (schwarzes Wasser) - gemessen: Kolonie 35, Titel und Fahrt 20.
function helligkeit(p, y0 = 0.0, y1 = 1.0) {
    let s = 0, n = 0;
    for (let y = Math.floor(p.hoehe * y0); y < p.hoehe * y1; y += 3) {
        for (let x = 0; x < p.breite; x += 3) {
            const i = (y * p.breite + x) * p.kanaele;
            s += p.bild[i] + p.bild[i + 1] + p.bild[i + 2];
            n += 3;
        }
    }
    return s / n;
}

// Wieviel sich zwei Bilder unterscheiden. Der Hintergrund lebt - Schwaerme
// ziehen, der Kegel wandert -, also ist "irgendetwas hat sich geaendert"
// **immer** wahr. Gemessen wird deshalb gegen das Rauschen desselben
// Schirms, nicht gegen null.
function unterschied(a, b) {
    let s = 0, n = 0;
    for (let y = 0; y < a.hoehe; y += 3) {
        for (let x = 0; x < a.breite; x += 3) {
            const i = (y * a.breite + x) * a.kanaele;
            s += Math.abs(a.bild[i] - b.bild[i])
                + Math.abs(a.bild[i + 1] - b.bild[i + 1])
                + Math.abs(a.bild[i + 2] - b.bild[i + 2]);
            n += 3;
        }
    }
    return s / n;
}

// Wohin faellt das Licht? Der Kegel ist das Hellste im Bild, also sagt der
// helligkeitsgewichtete Schwerpunkt, wohin er zeigt - und damit, ob ein Zug
// am Finger etwas bewegt hat. Robuster als ein Bildvergleich: das Wasser
// lebt ohnehin, der Schwerpunkt nicht.
function schwerpunkt(p) {
    let sx = 0, sw = 0;
    for (let y = 0; y < p.hoehe; y += 3) {
        for (let x = 0; x < p.breite; x += 3) {
            const i = (y * p.breite + x) * p.kanaele;
            const w = p.bild[i] + p.bild[i + 1] + p.bild[i + 2];
            sx += x * w;
            sw += w;
        }
    }
    return sx / Math.max(1, sw);
}


const tipp = async (fx, fy, warte = 1100) => {
    await seite.mouse.click(BREITE * fx, HOEHE * fy);
    await seite.waitForTimeout(warte);
};

if (leinwand) {
    // **Jede Schwelle hier ist gemessen, keine geraten.** Die Zahlen daneben
    // stammen aus einem Lauf, der nichts geprueft und alles gedruckt hat -
    // eine Schranke, die man sich ausdenkt, faellt entweder immer oder nie.
    const titel = await bild();
    pruefe(helligkeit(titel) > 4.0,
        'Das Titelbild ist schwarz - die Szene zeichnet nicht');

    // 1. COLONY. Ein Bedienschirm ist voller Tafeln und Text, offenes Wasser
    //    ist es nicht: gemessen 34,2 gegen 17 bis 20.
    await tipp(0.18, 0.909, 1600);
    const k0 = await bild();
    const im_ausbau = pruefe(helligkeit(k0) > 28.0,
        `COLONY hat nicht geoeffnet (Helligkeit ${helligkeit(k0).toFixed(1)}, erwartet > 28)`);

    // 2. Alle sechs Reiter.
    //
    //    **Das Rauschen wird auf dem Schirm gemessen, auf dem verglichen
    //    wird.** Der erste Anlauf nahm es vom Titelbild - dort ziehen
    //    Schwaerme und der Kegel wandert, also 10,5 -, und verlangte davon
    //    das Dreifache. Ein Reiterwechsel aendert 8 bis 19. Der Test meldete
    //    daraufhin sechs Fehler, die keine waren. Der Ausbauschirm steht
    //    still: sein Rauschen ist 0,35.
    if (im_ausbau) {
        await seite.waitForTimeout(1100);
        const k1 = await bild();
        const ruhe = unterschied(k0, k1);
        const schwelle = Math.max(8 * ruhe, 3.0);
        console.log(`Ruhe des Ausbauschirms: ${ruhe.toFixed(2)} - `
            + `Schwelle je Reiter: ${schwelle.toFixed(2)}`);

        const namen = ['BUILD', 'LINES', 'BEASTS', 'TRAITS', 'DAY', 'BOAT'];
        const REITER = namen.length;
        // Die Mitten aus der Zahl gerechnet und nicht getippt - beim
        // sechsten (BOAT) waeren sonst alle Anteile daneben gegangen, und
        // der Test haette weiter gruen gemeldet, dass er "alle" besucht hat.
        const mitten = [...Array(REITER).keys()].map((i) => (2 * i + 1) / (2 * REITER));
        let vorher = k1;
        // Der aktive zuletzt, damit am Ende ein anderer als der erste steht.
        for (const i of [1, 2, 3, 4, 5, 0]) {
            await tipp(mitten[i], 0.092);
            const jetzt = await bild();
            const d = unterschied(vorher, jetzt);
            pruefe(d > schwelle,
                `Reiter ${namen[i]} hat nichts geaendert `
                + `(${d.toFixed(2)} <= ${schwelle.toFixed(2)})`);
            vorher = jetzt;
        }
    }

    // 3. Zurueck in den Graben.
    await tipp(0.5, 0.967, 1600);
    const zurueck = await bild();
    pruefe(helligkeit(zurueck) < 26.0,
        `BACK TO THE TRENCH hat nicht geschlossen `
        + `(Helligkeit ${helligkeit(zurueck).toFixed(1)}, erwartet < 26)`);

    // 4. In die Fahrt - und zwar auf den Knopf: bis der Wellenstart ein
    //    Knopf wurde, startete jeder Tipp die Welle, auch dieser hier aus
    //    Versehen richtig. Jetzt ist die Stelle die Aussage des Tests.
    //
    //    Geprueft wird das **untere Band**: im Menue stehen dort drei
    //    Knoepfe (19,4), in der Fahrt die Uebersichtskarte und der
    //    Stosslichtring (46,9). Ein ganzflaechiger Vergleich taugt dafuer
    //    nicht - Titelbild und Fahrt sind beide dunkles Wasser.
    await tipp(0.5, 0.861, 2600);
    const fahrt = await bild();
    const unten = helligkeit(fahrt, 0.83, 0.99);
    pruefe(unten > 35.0,
        `PLAY hat die Fahrt nicht gestartet `
        + `(unteres Band ${unten.toFixed(1)}, erwartet > 35)`);

    // 5. Den Kegel wirklich schwenken. Gemessen wird, wohin das Licht
    //    wandert: der Kegel ist das Hellste im Bild, also verschiebt ein Zug
    //    den Helligkeitsschwerpunkt. Gemessen 195 -> 231 bei 400 Pixeln
    //    Breite.
    const vor_zug = schwerpunkt(fahrt);
    await seite.mouse.move(BREITE * 0.5, HOEHE * 0.5);
    await seite.mouse.down();
    for (let i = 0; i <= 14; i++) {
        await seite.mouse.move(BREITE * (0.14 + i * 0.05), HOEHE * 0.28);
        await seite.waitForTimeout(70);
    }
    await seite.mouse.up();
    await seite.waitForTimeout(1200);
    const gezogen = await bild();
    const nach_zug = schwerpunkt(gezogen);
    pruefe(Math.abs(nach_zug - vor_zug) > 10.0,
        `Der Zug am Finger hat das Licht nicht bewegt `
        + `(Schwerpunkt ${vor_zug.toFixed(0)} -> ${nach_zug.toFixed(0)})`);

    // Ausserhalb des Projekts ablegen: im Projekt waere es eine Bilddatei
    // ohne Eintrag in ASSETS.md, und der Lizenzcheck meldet das zu Recht.
    await seite.screenshot({ path: path.join(os.tmpdir(), 'nekton-browsertest.png') });
}

// Godots Startbild kommt als blob: und wird von der Richtlinie abgewiesen.
// Das ist bekannt und harmlos - alles andere nicht.
const echte = konsole.filter((z) => !z.includes('blob:') && !z.includes('404'));
pruefe(echte.length === 0, 'Konsolenfehler:\n  ' + echte.join('\n  '));

await browser.close();
server.close();

if (fehler.length === 0) {
    console.log('Browsertest bestanden: Start, COLONY, sechs Reiter, zurueck, '
        + 'PLAY, Fingerzug - jeder Schritt am Bild geprueft.');
    process.exit(0);
}
for (const f of fehler) console.log('FEHLER: ' + f);
process.exit(1);
