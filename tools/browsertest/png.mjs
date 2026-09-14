// Ein PNG lesen, ohne eine Abhaengigkeit dafuer aufzunehmen.
//
// **Warum selbst und nicht `pngjs`.** Jede neue Abhaengigkeit ist ein
// Eintrag in `ASSETS.md` und eine Lizenz, die jemand pruefen muss - fuer
// vierzig Zeilen, die Node mit `zlib` ohnehin kann. Gelesen wird nur, was
// Playwright schreibt: acht Bit, RGBA, nicht verschraenkt.
import zlib from 'node:zlib';

export function lies_png(puffer) {
    let i = 8;                                   // Signatur ueberspringen
    let breite = 0, hoehe = 0, farbtyp = 6, tiefe = 8;
    const teile = [];
    while (i < puffer.length) {
        const laenge = puffer.readUInt32BE(i);
        const art = puffer.toString('ascii', i + 4, i + 8);
        const daten = puffer.subarray(i + 8, i + 8 + laenge);
        if (art === 'IHDR') {
            breite = daten.readUInt32BE(0);
            hoehe = daten.readUInt32BE(4);
            tiefe = daten[8];
            farbtyp = daten[9];
        } else if (art === 'IDAT') {
            teile.push(daten);
        } else if (art === 'IEND') {
            break;
        }
        i += 12 + laenge;                        // Laenge + Art + Daten + CRC
    }
    if (tiefe !== 8 || (farbtyp !== 6 && farbtyp !== 2)) {
        throw new Error(`PNG: Tiefe ${tiefe}, Farbtyp ${farbtyp} nicht unterstuetzt`);
    }
    const kanaele = farbtyp === 6 ? 4 : 3;
    const roh = zlib.inflateSync(Buffer.concat(teile));
    const zeile = breite * kanaele;
    const bild = Buffer.alloc(hoehe * zeile);
    // Die fuenf PNG-Filter. Jede Zeile beginnt mit ihrer Filternummer, und
    // jeder Filter rechnet gegen den linken und den oberen Nachbarn - wer
    // einen davon vergisst, bekommt kein Bild, sondern Schlieren.
    for (let y = 0; y < hoehe; y++) {
        const f = roh[y * (zeile + 1)];
        const ein = roh.subarray(y * (zeile + 1) + 1, (y + 1) * (zeile + 1));
        const aus = bild.subarray(y * zeile, (y + 1) * zeile);
        for (let x = 0; x < zeile; x++) {
            const a = x >= kanaele ? aus[x - kanaele] : 0;
            const b = y > 0 ? bild[(y - 1) * zeile + x] : 0;
            const c = (x >= kanaele && y > 0) ? bild[(y - 1) * zeile + x - kanaele] : 0;
            let wert = ein[x];
            if (f === 1) wert += a;
            else if (f === 2) wert += b;
            else if (f === 3) wert += (a + b) >> 1;
            else if (f === 4) {
                const p = a + b - c;
                const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
                wert += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
            }
            aus[x] = wert & 255;
        }
    }
    return { breite, hoehe, kanaele, bild };
}
