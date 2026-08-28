// Kern des Wächters: aus Vertragsbedingungen den nächsten Kündigungsstichtag
// berechnen. Reine Funktionen ohne Datenbank- oder Netzbezug — Server und
// Oberfläche rechnen mit demselben Code, und die Regeln lassen sich testen.

import {
    heute as heuteBerlin,
    istNichtVor,
    istVor,
    jahresEnde,
    monatsEnde,
    plusMonate,
    plusTage,
    quartalsEnde,
    spaeteres,
    tageBis,
    type IsoDatum,
} from "./datum.ts";
import { datumKurz, einheitInWorten } from "./formate.ts";
import type {
    Fristbezug,
    Fristeinheit,
    Vertrag,
    Vertragsbedingungen,
    Vertragsstatus,
} from "./typen.ts";

export type Fristart =
    /** Es gibt einen Termin, bis zu dem gekündigt werden muss. */
    | "kuendigungsstichtag"
    /** Der Vertrag endet von selbst; zu überwachen ist der Auslauf. */
    | "vertragsende"
    /** Kündigung ist ohne Termin möglich. */
    | "jederzeit_kuendbar"
    /** Nichts mehr zu überwachen (bereits beendet oder ausgelaufen). */
    | "keine";

export interface Fristberechnung {
    art: Fristart;
    /** Letzter Tag, an dem die Kündigung zugehen muss (bzw. Auslaufdatum). */
    stichtag: IsoDatum | null;
    tageBisStichtag: number | null;
    /** Ende der derzeit laufenden Vertragsperiode. */
    laufzeitende: IsoDatum | null;
    /** Vertragsende, wenn zum nächsten Stichtag gekündigt wird. */
    wirksamesVertragsende: IsoDatum | null;
    /** Wie oft sich der Vertrag bereits automatisch verlängert hat. */
    verlaengerungenBisher: number;
    /**
     * Wahr, wenn der Stichtag für die laufende Periode schon verstrichen ist
     * und der Vertrag deshalb bereits in die nächste Verlängerung läuft.
     */
    fristVerstrichen: boolean;
    hinweis: string;
}

export const SCHLEIFENGRENZE = 2000;

export interface Schwellen {
    kritisch: number;
    warnung: number;
    hinweis: number;
}

export const STANDARD_SCHWELLEN: Schwellen = { kritisch: 14, warnung: 45, hinweis: 90 };

export type Ampel = "kritisch" | "warnung" | "hinweis" | "ok" | "jederzeit" | "gekuendigt" | "beendet";

export const AMPEL_TEXT: Record<Ampel, string> = {
    kritisch: "Frist läuft ab",
    warnung: "Bald handeln",
    hinweis: "In Sicht",
    ok: "Alles ruhig",
    jederzeit: "Jederzeit kündbar",
    gekuendigt: "Gekündigt",
    beendet: "Beendet",
};

/** Zieht die Kündigungsfrist von einem Beendigungstermin ab. */
export function stichtagFuer(ende: IsoDatum, wert: number, einheit: Fristeinheit): IsoDatum {
    const betrag = Math.max(0, Math.trunc(wert));
    if (betrag === 0) return ende;
    switch (einheit) {
        case "monate":
            return plusMonate(ende, -betrag);
        case "wochen":
            return plusTage(ende, -betrag * 7);
        case "tage":
            return plusTage(ende, -betrag);
    }
}

/** Addiert eine Kündigungsfrist auf ein Datum — die Umkehrung von stichtagFuer. */
export function fristAufschlagen(datum: IsoDatum, wert: number, einheit: Fristeinheit): IsoDatum {
    const betrag = Math.max(0, Math.trunc(wert));
    switch (einheit) {
        case "monate":
            return plusMonate(datum, betrag);
        case "wochen":
            return plusTage(datum, betrag * 7);
        case "tage":
            return plusTage(datum, betrag);
    }
}

function periodenEnde(datum: IsoDatum, bezug: Fristbezug): IsoDatum {
    switch (bezug) {
        case "zum_quartalsende":
            return quartalsEnde(datum);
        case "zum_jahresende":
            return jahresEnde(datum);
        default:
            return monatsEnde(datum);
    }
}

function bezugName(bezug: Fristbezug): string {
    switch (bezug) {
        case "zum_quartalsende":
            return "Quartalsende";
        case "zum_jahresende":
            return "Jahresende";
        default:
            return "Monatsende";
    }
}

/** Letzter Tag der Erst- bzw. Mindestlaufzeit; null, wenn es keine gibt. */
export function erstlaufzeitEnde(b: Vertragsbedingungen): IsoDatum | null {
    const monate = Math.max(0, Math.trunc(b.erstlaufzeitMonate));
    if (monate === 0) return null;
    return plusTage(plusMonate(b.beginn, monate), -1);
}

/**
 * Ende der k-ten Vertragsperiode (k = 0 ist die Erstlaufzeit).
 *
 * Gerechnet wird immer vom Vertragsbeginn aus, nicht Periode für Periode:
 * Kettenrechnung driftet über kurze Monate weg (ein am 31. beginnender
 * Monatsvertrag wandert sonst nach jedem Februar einen Tag nach vorn).
 */
export function periodenendeNr(b: Vertragsbedingungen, k: number): IsoDatum {
    const erst = Math.max(1, Math.trunc(b.erstlaufzeitMonate));
    const verlaengerung = Math.max(1, Math.trunc(b.verlaengerungMonate));
    return plusTage(plusMonate(b.beginn, erst + k * verlaengerung), -1);
}

/** Nummer der Periode, die `datum` enthält (0 = Erstlaufzeit). */
function periodeAm(b: Vertragsbedingungen, datum: IsoDatum): number {
    let k = 0;
    while (istVor(periodenendeNr(b, k), datum) && k < SCHLEIFENGRENZE) k += 1;
    return k;
}

function leereBerechnung(hinweis: string, laufzeitende: IsoDatum | null = null): Fristberechnung {
    return {
        art: "keine",
        stichtag: null,
        tageBisStichtag: null,
        laufzeitende,
        wirksamesVertragsende: null,
        verlaengerungenBisher: 0,
        fristVerstrichen: false,
        hinweis,
    };
}

/**
 * Berechnet den nächsten Kündigungsstichtag.
 *
 * `basis` ist der Tag, von dem aus gerechnet wird (voreingestellt: heute in
 * deutscher Ortszeit). Ein Stichtag zählt bis einschließlich dieses Tages als
 * erreichbar — wer am Stichtag selbst kündigt, ist fristgerecht.
 */
export function berechneFristen(
    b: Vertragsbedingungen,
    basis: IsoDatum = heuteBerlin(),
): Fristberechnung {
    const frist = Math.max(0, Math.trunc(b.kuendigungsfristWert));
    const einheit = b.kuendigungsfristEinheit;
    const mindestende = erstlaufzeitEnde(b);

    // 1. Jederzeit kündbar: kein Termin, nur eine Auslauffrist.
    if (b.kuendigungsfristBezug === "jederzeit") {
        const frueheste = fristAufschlagen(basis, frist, einheit);
        const ende = mindestende && istVor(frueheste, mindestende) ? mindestende : frueheste;
        const nochGebunden = mindestende !== null && istVor(basis, mindestende);
        return {
            art: "jederzeit_kuendbar",
            stichtag: null,
            tageBisStichtag: null,
            laufzeitende: nochGebunden ? mindestende : null,
            wirksamesVertragsende: ende,
            verlaengerungenBisher: 0,
            fristVerstrichen: false,
            hinweis: nochGebunden
                ? `Mindestlaufzeit bis ${datumKurz(mindestende)}. Danach jederzeit mit ` +
                  `${einheitInWorten(frist, einheit)} Frist kündbar.`
                : `Jederzeit kündbar. Bei Kündigung heute endet der Vertrag am ${datumKurz(ende)}.`,
        };
    }

    // 2. Feste Laufzeit ohne Verlängerung: der Vertrag endet von selbst.
    const ohneVerlaengerung =
        b.laufzeitmodell === "befristet_ohne_verlaengerung" ||
        (b.laufzeitmodell === "befristet_mit_verlaengerung" &&
            Math.trunc(b.verlaengerungMonate) <= 0);
    if (ohneVerlaengerung) {
        const ende = mindestende ?? b.beginn;
        if (istVor(ende, basis)) {
            return leereBerechnung(`Der Vertrag ist am ${datumKurz(ende)} ausgelaufen.`, ende);
        }
        return {
            art: "vertragsende",
            stichtag: ende,
            tageBisStichtag: tageBis(basis, ende),
            laufzeitende: ende,
            wirksamesVertragsende: ende,
            verlaengerungenBisher: 0,
            fristVerstrichen: false,
            hinweis:
                `Endet automatisch am ${datumKurz(ende)}, eine Kündigung ist nicht nötig. ` +
                `Rechtzeitig über einen Anschlussvertrag entscheiden.`,
        };
    }

    // 3. Feste Laufzeit mit automatischer Verlängerung, Kündigung zum Laufzeitende.
    if (
        b.laufzeitmodell === "befristet_mit_verlaengerung" &&
        b.kuendigungsfristBezug === "zum_laufzeitende"
    ) {
        const laufendeNr = periodeAm(b, basis);
        const laufzeitende = periodenendeNr(b, laufendeNr);
        let nr = laufendeNr;
        let ende = laufzeitende;
        let stichtag = stichtagFuer(ende, frist, einheit);
        while (istVor(stichtag, basis) && nr - laufendeNr < SCHLEIFENGRENZE) {
            nr += 1;
            ende = periodenendeNr(b, nr);
            stichtag = stichtagFuer(ende, frist, einheit);
        }
        const verstrichen = nr > laufendeNr;
        return {
            art: "kuendigungsstichtag",
            stichtag,
            tageBisStichtag: tageBis(basis, stichtag),
            laufzeitende,
            wirksamesVertragsende: ende,
            verlaengerungenBisher: laufendeNr,
            fristVerstrichen: verstrichen,
            hinweis: verstrichen
                ? `Die Frist für den ${datumKurz(laufzeitende)} ist verstrichen — der Vertrag ` +
                  `verlängert sich. Nächste Gelegenheit: Kündigung bis ${datumKurz(stichtag)} ` +
                  `zum ${datumKurz(ende)}.`
                : `Kündigung muss bis ${datumKurz(stichtag)} zugehen, sonst verlängert sich der ` +
                  `Vertrag ab ${datumKurz(plusTage(ende, 1))} automatisch.`,
        };
    }

    // 4. Unbefristet (oder Kündigung zu einem festen Kalendertermin):
    //    der nächste erreichbare Monats-, Quartals- oder Jahreswechsel.
    const bezug = b.kuendigungsfristBezug;
    const untergrenze = mindestende ?? b.beginn;
    let kandidat = periodenEnde(spaeteres(basis, untergrenze), bezug);
    let schritte = 0;
    while (
        (istVor(kandidat, untergrenze) || istVor(stichtagFuer(kandidat, frist, einheit), basis)) &&
        schritte < SCHLEIFENGRENZE
    ) {
        kandidat = periodenEnde(plusTage(kandidat, 1), bezug);
        schritte += 1;
    }
    const stichtag = stichtagFuer(kandidat, frist, einheit);
    const nochGebunden = mindestende !== null && istNichtVor(mindestende, basis);
    return {
        art: "kuendigungsstichtag",
        stichtag,
        tageBisStichtag: tageBis(basis, stichtag),
        laufzeitende: nochGebunden ? mindestende : null,
        wirksamesVertragsende: kandidat,
        verlaengerungenBisher: 0,
        fristVerstrichen: false,
        hinweis: nochGebunden
            ? `Mindestlaufzeit bis ${datumKurz(mindestende)}. Frühestmöglicher Schluss: ` +
              `${datumKurz(kandidat)}, Kündigung bis ${datumKurz(stichtag)}.`
            : `Kündigung bis ${datumKurz(stichtag)} beendet den Vertrag zum ` +
              `${bezugName(bezug)} am ${datumKurz(kandidat)}.`,
    };
}

export function bestimmeAmpel(
    fristen: Fristberechnung,
    status: Vertragsstatus,
    schwellen: Schwellen = STANDARD_SCHWELLEN,
): Ampel {
    if (status === "beendet") return "beendet";
    if (status === "gekuendigt") return "gekuendigt";
    if (fristen.art === "keine") return "beendet";
    if (fristen.art === "jederzeit_kuendbar") return "jederzeit";
    const tage = fristen.tageBisStichtag;
    if (tage === null) return "ok";
    if (tage <= schwellen.kritisch) return "kritisch";
    if (tage <= schwellen.warnung) return "warnung";
    if (tage <= schwellen.hinweis) return "hinweis";
    return "ok";
}

export interface Vertragsbewertung {
    fristen: Fristberechnung;
    ampel: Ampel;
    /** Datum, das die Erinnerungen auslöst; null, wenn nichts zu überwachen ist. */
    ueberwachungsdatum: IsoDatum | null;
}

/**
 * Bewertet einen gespeicherten Vertrag: Fristen, Ampel und das Datum, an dem
 * sich die Erinnerungen orientieren. Ein gekündigter Vertrag wird bis zu seinem
 * Ende weiter geführt, löst aber keine Kündigungserinnerung mehr aus.
 */
export function bewerteVertrag(
    vertrag: Vertrag,
    basis: IsoDatum = heuteBerlin(),
    schwellen: Schwellen = STANDARD_SCHWELLEN,
): Vertragsbewertung {
    if (vertrag.status === "beendet") {
        return {
            fristen: leereBerechnung(
                vertrag.gekuendigtZum
                    ? `Beendet am ${datumKurz(vertrag.gekuendigtZum)}.`
                    : "Vertrag ist beendet.",
                vertrag.gekuendigtZum,
            ),
            ampel: "beendet",
            ueberwachungsdatum: null,
        };
    }
    if (vertrag.status === "gekuendigt") {
        const ende = vertrag.gekuendigtZum;
        return {
            fristen: {
                art: ende && istNichtVor(ende, basis) ? "vertragsende" : "keine",
                stichtag: ende,
                tageBisStichtag: ende ? tageBis(basis, ende) : null,
                laufzeitende: ende,
                wirksamesVertragsende: ende,
                verlaengerungenBisher: 0,
                fristVerstrichen: false,
                hinweis: ende
                    ? `Gekündigt, läuft noch bis ${datumKurz(ende)}.`
                    : "Gekündigt.",
            },
            ampel: "gekuendigt",
            ueberwachungsdatum: null,
        };
    }
    const fristen = berechneFristen(vertrag, basis);
    return {
        fristen,
        ampel: bestimmeAmpel(fristen, vertrag.status, schwellen),
        ueberwachungsdatum: fristen.art === "jederzeit_kuendbar" ? null : fristen.stichtag,
    };
}
