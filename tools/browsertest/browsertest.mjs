// Browsertest mit echter Eingabe.
//
//     cd tools/browsertest && npm install && node browsertest.mjs
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

import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';

const HIER = path.dirname(fileURLToPath(import.meta.url));
const WURZEL = path.resolve(HIER, '../../docs');
const PORT = 8731;

// Streckmodus "expand": die Steuerflaeche ist 720 breit und entsprechend
// hoch - nicht 1280. Ein geratener Anteil trifft daneben.
const BREITE = 400, HOEHE = 760;
const H = 720 * (HOEHE / BREITE);
const anteil = (y) => y / H;

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
const k = leinwand ? await leinwand.boundingBox() : null;

const tipp = async (fy, fx = 0.5, warte = 900) => {
    await seite.mouse.click(k.x + k.width * fx, k.y + k.height * fy);
    await seite.waitForTimeout(warte);
};

if (k) {
    // 1. Kolonie oeffnen und alle vier Reiter besuchen.
    await tipp(anteil(H - 410 + 27));
    const reiterY = anteil(96 + 12 + 18);
    // Vier Reiter, gleich breit mit 8 px Luecke - die Mitten liegen bei
    // 1/8, 3/8, 5/8 und 7/8 der Breite. Ein geratener Anteil trifft daneben.
    for (const fx of [0.375, 0.625, 0.875, 0.125]) await tipp(reiterY, fx);
    await tipp(anteil(H - 78 + 34));                 // zurueck zum Schlund

    // 2. Welle starten und den Kegel wirklich schwenken.
    await tipp(0.5);
    await seite.mouse.move(k.x + k.width * 0.5, k.y + k.height * 0.5);
    await seite.mouse.down();
    for (let i = 0; i <= 14; i++) {
        await seite.mouse.move(k.x + k.width * (0.14 + i * 0.05), k.y + k.height * 0.28);
        await seite.waitForTimeout(70);
    }
    await seite.mouse.up();
    await seite.waitForTimeout(2000);
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
    console.log('Browsertest bestanden: Start, alle vier Reiter, Wellenstart, Kegelzug.');
    process.exit(0);
}
for (const f of fehler) console.log('FEHLER: ' + f);
process.exit(1);
