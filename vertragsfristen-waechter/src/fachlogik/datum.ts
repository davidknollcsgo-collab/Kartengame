// Datumsrechnung für Kündigungsfristen.
//
// Alle Datumsangaben sind ISO-Kalendertage ("2026-03-31") ohne Uhrzeit und
// ohne Zeitzone. Gerechnet wird intern in UTC, damit Sommerzeit-Sprünge keine
// Rolle spielen: ein Kalendertag hat hier immer 24 Stunden.

export type IsoDatum = string;

const MS_PRO_TAG = 86_400_000;
const MUSTER = /^(\d{4})-(\d{2})-(\d{2})$/;

/** Zeitzone, in der "heute" bestimmt wird. Fristen laufen nach Ortszeit ab. */
export const ZEITZONE = "Europe/Berlin";

export function istIsoDatum(wert: unknown): wert is IsoDatum {
    if (typeof wert !== "string") return false;
    const treffer = MUSTER.exec(wert);
    if (!treffer) return false;
    const [, j, m, t] = treffer;
    const jahr = Number(j);
    const monat = Number(m);
    const tag = Number(t);
    if (monat < 1 || monat > 12) return false;
    if (tag < 1 || tag > letzterTagImMonat(jahr, monat)) return false;
    return true;
}

function pruefe(datum: IsoDatum): IsoDatum {
    if (!istIsoDatum(datum)) throw new RangeError(`Kein gültiges Datum: ${String(datum)}`);
    return datum;
}

export function ausTeilen(jahr: number, monat: number, tag: number): IsoDatum {
    const p = (n: number, stellen = 2) => String(n).padStart(stellen, "0");
    return `${p(jahr, 4)}-${p(monat)}-${p(tag)}`;
}

export function teile(datum: IsoDatum): { jahr: number; monat: number; tag: number } {
    const treffer = MUSTER.exec(pruefe(datum))!;
    return { jahr: Number(treffer[1]), monat: Number(treffer[2]), tag: Number(treffer[3]) };
}

export function letzterTagImMonat(jahr: number, monat: number): number {
    return new Date(Date.UTC(jahr, monat, 0)).getUTCDate();
}

/** Der heutige Kalendertag in der angegebenen Zeitzone. */
export function heute(jetzt: Date = new Date(), zeitzone: string = ZEITZONE): IsoDatum {
    // "sv-SE" formatiert als YYYY-MM-DD und ist damit direkt ISO-konform.
    return new Intl.DateTimeFormat("sv-SE", {
        timeZone: zeitzone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).format(jetzt);
}

function zuZeit(datum: IsoDatum): number {
    const { jahr, monat, tag } = teile(datum);
    return Date.UTC(jahr, monat - 1, tag);
}

function ausZeit(zeit: number): IsoDatum {
    const d = new Date(zeit);
    return ausTeilen(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate());
}

export function plusTage(datum: IsoDatum, tage: number): IsoDatum {
    return ausZeit(zuZeit(datum) + tage * MS_PRO_TAG);
}

/**
 * Verschiebt um ganze Monate. Der Tag im Monat bleibt erhalten, soweit es ihn
 * gibt: der 31. Januar plus einen Monat ist der 28. bzw. 29. Februar. Genauso
 * rechnen Verträge ihre Laufzeiten.
 */
export function plusMonate(datum: IsoDatum, monate: number): IsoDatum {
    const { jahr, monat, tag } = teile(datum);
    const gesamt = jahr * 12 + (monat - 1) + monate;
    const neuesJahr = Math.floor(gesamt / 12);
    const neuerMonat = (gesamt % 12) + 1;
    return ausTeilen(neuesJahr, neuerMonat, Math.min(tag, letzterTagImMonat(neuesJahr, neuerMonat)));
}

export function monatsErster(datum: IsoDatum): IsoDatum {
    const { jahr, monat } = teile(datum);
    return ausTeilen(jahr, monat, 1);
}

export function monatsEnde(datum: IsoDatum): IsoDatum {
    const { jahr, monat } = teile(datum);
    return ausTeilen(jahr, monat, letzterTagImMonat(jahr, monat));
}

export function quartalsEnde(datum: IsoDatum): IsoDatum {
    const { jahr, monat } = teile(datum);
    const letzterMonat = Math.ceil(monat / 3) * 3;
    return ausTeilen(jahr, letzterMonat, letzterTagImMonat(jahr, letzterMonat));
}

export function jahresEnde(datum: IsoDatum): IsoDatum {
    return ausTeilen(teile(datum).jahr, 12, 31);
}

/** Ganze Tage von `von` bis `bis`; negativ, wenn `bis` vor `von` liegt. */
export function tageBis(von: IsoDatum, bis: IsoDatum): number {
    return Math.round((zuZeit(bis) - zuZeit(von)) / MS_PRO_TAG);
}

export function vergleiche(a: IsoDatum, b: IsoDatum): number {
    return zuZeit(a) - zuZeit(b);
}

export function istVor(a: IsoDatum, b: IsoDatum): boolean {
    return vergleiche(a, b) < 0;
}

export function istNichtVor(a: IsoDatum, b: IsoDatum): boolean {
    return vergleiche(a, b) >= 0;
}

export function spaeteres(a: IsoDatum, b: IsoDatum): IsoDatum {
    return vergleiche(a, b) >= 0 ? a : b;
}

export function frueheres(a: IsoDatum, b: IsoDatum): IsoDatum {
    return vergleiche(a, b) <= 0 ? a : b;
}
