// Ein Feld für eine CSV-Ausgabe absichern.
//
// Zwei getrennte Gefahren: Trennzeichen im Text zerlegen die Zeile, und ein
// führendes =, +, - oder @ macht aus dem Feld in Excel und LibreOffice eine
// Formel. Der zweite Fall ist der gefährlichere — Anzeigenamen kommen aus dem
// Mandanten des Kunden und damit von außen (CWE-1236).

const FORMELZEICHEN = /^[=+\-@\t\r]/;

export function csvFeld(wert: unknown): string {
    let text = wert === null || wert === undefined ? "" : String(wert);
    if (FORMELZEICHEN.test(text)) text = `'${text}`;
    return /[";\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}
