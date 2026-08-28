import { tageBis, teile, type IsoDatum } from "./datum.ts";
import {
    ZAHLUNGEN_PRO_JAHR,
    type Fristbezug,
    type Fristeinheit,
    type Laufzeitmodell,
    type Zahlungsintervall,
} from "./typen.ts";

const MONATSNAMEN = [
    "Januar", "Februar", "März", "April", "Mai", "Juni",
    "Juli", "August", "September", "Oktober", "November", "Dezember",
];

/** "2026-03-31" → "31.03.2026" */
export function datumKurz(datum: IsoDatum | null | undefined): string {
    if (!datum) return "–";
    const { jahr, monat, tag } = teile(datum);
    const p = (n: number) => String(n).padStart(2, "0");
    return `${p(tag)}.${p(monat)}.${jahr}`;
}

/** "2026-03-31" → "31. März 2026" */
export function datumLang(datum: IsoDatum | null | undefined): string {
    if (!datum) return "–";
    const { jahr, monat, tag } = teile(datum);
    return `${tag}. ${MONATSNAMEN[monat - 1]} ${jahr}`;
}

/** Abstand in Worten: "in 12 Tagen", "heute", "vor 3 Tagen". */
export function tageInWorten(tage: number | null | undefined): string {
    if (tage === null || tage === undefined) return "–";
    if (tage === 0) return "heute";
    if (tage === 1) return "morgen";
    if (tage === -1) return "gestern";
    if (tage < 0) return `vor ${Math.abs(tage)} Tagen`;
    return `in ${tage} Tagen`;
}

export function abstandInWorten(von: IsoDatum, bis: IsoDatum): string {
    return tageInWorten(tageBis(von, bis));
}

export function fristInWorten(wert: number, einheit: Fristeinheit, bezug: Fristbezug): string {
    if (bezug === "jederzeit") {
        return `jederzeit mit ${einheitInWorten(wert, einheit)} Frist`;
    }
    const bezugstext: Record<Exclude<Fristbezug, "jederzeit">, string> = {
        zum_laufzeitende: "zum Laufzeitende",
        zum_monatsende: "zum Monatsende",
        zum_quartalsende: "zum Quartalsende",
        zum_jahresende: "zum Jahresende",
    };
    return `${einheitInWorten(wert, einheit)} ${bezugstext[bezug]}`;
}

/**
 * Die Kündigungsregel eines Vertrags in Worten. Ein Vertrag, der von selbst
 * ausläuft, hat keine Frist — "0 Monate zum Laufzeitende" wäre irreführend.
 */
export function kuendigungsregel(vertrag: {
    laufzeitmodell: Laufzeitmodell;
    kuendigungsfristWert: number;
    kuendigungsfristEinheit: Fristeinheit;
    kuendigungsfristBezug: Fristbezug;
}): string {
    if (vertrag.laufzeitmodell === "befristet_ohne_verlaengerung") return "endet automatisch";
    return fristInWorten(
        vertrag.kuendigungsfristWert,
        vertrag.kuendigungsfristEinheit,
        vertrag.kuendigungsfristBezug,
    );
}

export function einheitInWorten(wert: number, einheit: Fristeinheit): string {
    const einzahl = { tage: "Tag", wochen: "Woche", monate: "Monat" }[einheit];
    const mehrzahl = { tage: "Tage", wochen: "Wochen", monate: "Monate" }[einheit];
    return `${wert} ${wert === 1 ? einzahl : mehrzahl}`;
}

export function monateInWorten(monate: number): string {
    if (monate <= 0) return "keine";
    if (monate % 12 === 0) {
        const jahre = monate / 12;
        return jahre === 1 ? "1 Jahr" : `${jahre} Jahre`;
    }
    return monate === 1 ? "1 Monat" : `${monate} Monate`;
}

export function euro(betragCent: number): string {
    return new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" }).format(
        betragCent / 100,
    );
}

/** Hochgerechnete Kosten pro Jahr in Cent; Einmalzahlungen zählen nicht mit. */
export function jahreskostenCent(betragCent: number, intervall: Zahlungsintervall): number {
    return Math.round(betragCent * ZAHLUNGEN_PRO_JAHR[intervall]);
}
