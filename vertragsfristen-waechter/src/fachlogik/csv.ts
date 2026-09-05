// CSV-Ausgabe für Excel: Semikolon als Trennzeichen und ein BOM, sonst
// verstümmelt Excel die Umlaute.

import { AMPEL_TEXT, bewerteVertrag } from "./fristen.ts";
import { datumKurz, jahreskostenCent, kuendigungsregel } from "./formate.ts";
import {
    KATEGORIE_TEXT,
    LAUFZEITMODELL_TEXT,
    VERTRAGSSTATUS_TEXT,
    ZAHLUNGSINTERVALL_TEXT,
    type Vertrag,
} from "./typen.ts";

const SPALTEN = [
    "Bezeichnung",
    "Anbieter",
    "Kategorie",
    "Vertragsnummer",
    "Abteilung",
    "Ansprechpartner",
    "Status",
    "Beginn",
    "Laufzeitmodell",
    "Erstlaufzeit (Monate)",
    "Verlängerung (Monate)",
    "Kündigungsfrist",
    "Nächster Stichtag",
    "Tage bis Stichtag",
    "Vertragsende bei Kündigung",
    "Bewertung",
    "Betrag",
    "Zahlungsintervall",
    "Kosten pro Jahr",
    "Notizen",
];

// Ein führendes =, +, - oder @ macht aus dem Feld in Excel eine Formel. Die
// Werte stammen aus Vertragsdaten, die jemand eingetippt hat — also von außen.
const FORMELZEICHEN = /^[=+\-@\t\r]/;

function feld(wert: string | number | null | undefined): string {
    let text = wert === null || wert === undefined ? "" : String(wert);
    if (FORMELZEICHEN.test(text)) text = `'${text}`;
    return /[";\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function betrag(cent: number): string {
    return (cent / 100).toFixed(2).replace(".", ",");
}

export function baueCsv(vertraege: Vertrag[], basis: string): string {
    const zeilen = [SPALTEN.join(";")];
    for (const vertrag of vertraege) {
        const { fristen, ampel } = bewerteVertrag(vertrag, basis);
        zeilen.push(
            [
                vertrag.bezeichnung,
                vertrag.anbieter,
                KATEGORIE_TEXT[vertrag.kategorie],
                vertrag.vertragsnummer,
                vertrag.abteilung,
                vertrag.ansprechpartner,
                VERTRAGSSTATUS_TEXT[vertrag.status],
                datumKurz(vertrag.beginn),
                LAUFZEITMODELL_TEXT[vertrag.laufzeitmodell],
                vertrag.erstlaufzeitMonate,
                vertrag.verlaengerungMonate,
                kuendigungsregel(vertrag),
                fristen.stichtag ? datumKurz(fristen.stichtag) : "",
                fristen.tageBisStichtag ?? "",
                fristen.wirksamesVertragsende ? datumKurz(fristen.wirksamesVertragsende) : "",
                AMPEL_TEXT[ampel],
                betrag(vertrag.betragCent),
                ZAHLUNGSINTERVALL_TEXT[vertrag.zahlungsintervall],
                betrag(jahreskostenCent(vertrag.betragCent, vertrag.zahlungsintervall)),
                vertrag.notizen.replace(/\r?\n/g, " "),
            ]
                .map(feld)
                .join(";"),
        );
    }
    return "﻿" + zeilen.join("\r\n") + "\r\n";
}
