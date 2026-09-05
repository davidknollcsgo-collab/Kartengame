import { teile, type IsoDatum } from "./datum.ts";

export function euro(cent: number): string {
    return new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" }).format(cent / 100);
}

/** Für Kacheln: 1.234 € statt 1.234,00 € */
export function euroKurz(cent: number): string {
    return new Intl.NumberFormat("de-DE", {
        style: "currency",
        currency: "EUR",
        maximumFractionDigits: 0,
    }).format(cent / 100);
}

export function datumKurz(datum: IsoDatum | null | undefined): string {
    if (!datum) return "–";
    const { jahr, monat, tag } = teile(datum);
    const p = (n: number) => String(n).padStart(2, "0");
    return `${p(tag)}.${p(monat)}.${jahr}`;
}

export function tageInWorten(tage: number | null | undefined): string {
    if (tage === null || tage === undefined) return "–";
    if (tage === 0) return "heute";
    if (tage === 1) return "seit gestern";
    if (tage < 30) return `seit ${tage} Tagen`;
    if (tage < 365) return `seit ${Math.round(tage / 30)} Monaten`;
    const jahre = Math.floor(tage / 365);
    return jahre === 1 ? "seit über einem Jahr" : `seit über ${jahre} Jahren`;
}

export function anzahl(wert: number, einzahl: string, mehrzahl: string): string {
    return `${wert} ${wert === 1 ? einzahl : mehrzahl}`;
}
