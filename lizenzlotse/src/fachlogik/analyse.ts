// Kern des Lotsen: aus einem Lizenzbestand werden Befunde mit einem Betrag in
// Euro. Reine Funktionen ohne Datenbank- und Netzbezug — die Regeln lassen
// sich damit einzeln testen, und Server wie Oberfläche rechnen dasselbe.
//
// Zwei Grundsätze ziehen sich durch alle Regeln:
//
//  1. Lieber zu wenig ausweisen als zu viel. Wo eine Annahme nötig ist, wird
//     die vorsichtigere gewählt — eine zu hohe Ersparnis im ersten Bericht
//     kostet Vertrauen, das nicht wiederkommt.
//  2. Kein Befund zählt doppelt. Ein gesperrtes Konto ist nicht zusätzlich
//     "inaktiv", und ein doppelt lizenziertes Konto bekommt keine
//     Abstufungsempfehlung obendrauf.

import { istVor, tageBis, type IsoDatum } from "./datum.ts";
import { istBasisplan, sku, skuName } from "./skus.ts";
import {
    DIENSTE,
    DIENST_TEXT,
    type Befund,
    type Befundart,
    type Bestand,
    type Dienst,
    type Konto,
} from "./typen.ts";
import { anzahl as inWorten, datumKurz, euro } from "./formate.ts";

export interface Regelwerk {
    /** Ab wann gilt ein Konto als inaktiv. */
    inaktivTage: number;
    /** Wie alt ein nie genutztes Konto sein muss, bevor es auffällt. */
    nieAktivTage: number;
    /** Ab wann gilt ein Zusatzprodukt als ungenutzt. */
    zusatzInaktivTage: number;
    /** Wie viele nicht zugewiesene Lizenzen als Reserve durchgehen. */
    reserveLizenzen: number;
}

export const STANDARD_REGELWERK: Regelwerk = {
    inaktivTage: 90,
    nieAktivTage: 45,
    zusatzInaktivTage: 60,
    reserveLizenzen: 2,
};

export type Preis = (skuId: string) => number;

export interface Auswertung {
    stichtag: IsoDatum;
    befunde: Befund[];
    /** Summe der Ersparnis aller Befunde, je Monat. */
    ersparnisCentMonat: number;
    /**
     * Anteil, der ohne weitere Klärung gehoben werden kann. Diese Zahl geht
     * in den Bericht an die Geschäftsführung — sie muss halten.
     */
    ersparnisSicherCentMonat: number;
    /** Zusätzliches Potenzial, das erst nach Rückfrage feststeht. */
    ersparnisPruefenCentMonat: number;
    /** Laufende Lizenzkosten des Mandanten, je Monat. */
    lizenzkostenCentMonat: number;
    anzahlKonten: number;
    anzahlZuweisungen: number;
    nachArt: Record<Befundart, { anzahl: number; ersparnisCentMonat: number }>;
}

function leereZaehlung(): Auswertung["nachArt"] {
    return {
        gesperrt_lizenziert: { anzahl: 0, ersparnisCentMonat: 0 },
        nie_aktiv: { anzahl: 0, ersparnisCentMonat: 0 },
        inaktiv: { anzahl: 0, ersparnisCentMonat: 0 },
        regallizenz: { anzahl: 0, ersparnisCentMonat: 0 },
        doppelte_lizenz: { anzahl: 0, ersparnisCentMonat: 0 },
        ungenutztes_zusatzprodukt: { anzahl: 0, ersparnisCentMonat: 0 },
        ueberdimensioniert: { anzahl: 0, ersparnisCentMonat: 0 },
    };
}

/** Die jüngste Aktivität über alle Dienste hinweg; null heißt "nie". */
export function letzteAktivitaet(konto: Konto): IsoDatum | null {
    let juengste: IsoDatum | null = null;
    for (const dienst of DIENSTE) {
        const wert = konto.letzteAktivitaet[dienst];
        if (!wert) continue;
        if (!juengste || istVor(juengste, wert)) juengste = wert;
    }
    return juengste;
}

/** Dienste, in denen das Konto überhaupt je aktiv war. */
export function genutzteDienste(konto: Konto): Dienst[] {
    return DIENSTE.filter((dienst) => Boolean(konto.letzteAktivitaet[dienst]));
}

function summe(skus: string[], preis: Preis): number {
    return skus.reduce((wert, id) => wert + preis(id), 0);
}

function befundId(art: Befundart, kontoId: string | null, skuId: string | null): string {
    return `${art}:${kontoId ?? "-"}:${skuId ?? "-"}`;
}

function skuListe(skus: string[]): string {
    return skus.map(skuName).join(", ");
}

export function werteAus(
    bestand: Bestand,
    preis: Preis,
    regelwerk: Regelwerk = STANDARD_REGELWERK,
): Auswertung {
    const befunde: Befund[] = [];
    const stichtag = bestand.stichtag;
    /** Konten, deren Lizenzen bereits vollständig von einer Regel erfasst sind. */
    const abgerechnet = new Set<string>();

    for (const konto of bestand.konten) {
        const lizenzen = konto.skus.filter((id) => preis(id) > 0 || sku(id));
        if (lizenzen.length === 0) continue;
        const kosten = summe(lizenzen, preis);
        const zuletzt = letzteAktivitaet(konto);

        // 1. Gesperrt, aber weiter lizenziert. Der eindeutigste Fall: das
        //    Konto kann sich nicht anmelden und kostet trotzdem jeden Monat.
        if (konto.gesperrt) {
            befunde.push({
                id: befundId("gesperrt_lizenziert", konto.id, null),
                art: "gesperrt_lizenziert",
                sicherheit: "sicher",
                titel: `${konto.anzeigename}: gesperrt, aber lizenziert`,
                begruendung:
                    `Die Anmeldung ist blockiert, ${inWorten(lizenzen.length, "Lizenz ist", "Lizenzen sind")} ` +
                    `weiterhin zugewiesen (${skuListe(lizenzen)}).`,
                empfehlung:
                    "Lizenzen entziehen. Postfach vorher als freigegebenes Postfach umwandeln, " +
                    "dann bleiben die Inhalte ohne Lizenz erhalten.",
                kontoId: konto.id,
                upn: konto.upn,
                anzeigename: konto.anzeigename,
                sku: null,
                zielSku: null,
                anzahl: lizenzen.length,
                ersparnisCentMonat: kosten,
            });
            abgerechnet.add(konto.id);
            continue;
        }

        // 2. Nie benutzt. Meist ein abgebrochenes Onboarding oder ein
        //    Dienstkonto, das keine Lizenz braucht.
        if (!zuletzt) {
            const alter = konto.erstelltAm ? tageBis(konto.erstelltAm, stichtag) : null;
            if (alter === null || alter >= regelwerk.nieAktivTage) {
                befunde.push({
                    id: befundId("nie_aktiv", konto.id, null),
                    art: "nie_aktiv",
                    sicherheit: "pruefen",
                    titel: `${konto.anzeigename}: Lizenz nie genutzt`,
                    begruendung:
                        `Seit Anlage des Kontos${alter !== null ? ` vor ${alter} Tagen` : ""} ist in keinem ` +
                        `Dienst Aktivität verzeichnet. Zugewiesen: ${skuListe(lizenzen)}.`,
                    empfehlung:
                        "Prüfen, ob die Person angefangen hat. Dienst- und Sammelpostfächer " +
                        "brauchen in der Regel keine Lizenz.",
                    kontoId: konto.id,
                    upn: konto.upn,
                    anzeigename: konto.anzeigename,
                    sku: null,
                    zielSku: null,
                    anzahl: lizenzen.length,
                    ersparnisCentMonat: kosten,
                });
                abgerechnet.add(konto.id);
            }
            continue;
        }

        // 3. Lange nicht mehr gesehen.
        const ruhetage = tageBis(zuletzt, stichtag);
        if (ruhetage > regelwerk.inaktivTage) {
            befunde.push({
                id: befundId("inaktiv", konto.id, null),
                art: "inaktiv",
                sicherheit: "pruefen",
                titel: `${konto.anzeigename}: seit ${ruhetage} Tagen inaktiv`,
                begruendung:
                    `Letzte Aktivität am ${datumKurz(zuletzt)}. Zugewiesen: ${skuListe(lizenzen)} ` +
                    `für ${euro(kosten)} im Monat.`,
                empfehlung:
                    "Klären, ob die Person noch im Unternehmen ist. Elternzeit und lange " +
                    "Krankheit sind gute Gründe — Ausscheiden ist der häufigere.",
                kontoId: konto.id,
                upn: konto.upn,
                anzeigename: konto.anzeigename,
                sku: null,
                zielSku: null,
                anzahl: lizenzen.length,
                ersparnisCentMonat: kosten,
            });
            abgerechnet.add(konto.id);
        }
    }

    // 4. Gekauft, aber niemandem zugewiesen.
    for (const abo of bestand.abonnements) {
        const offen = abo.gekauft - abo.zugewiesen;
        if (offen <= 0) continue;
        const wert = offen * preis(abo.sku);
        if (wert <= 0) continue;
        befunde.push({
            id: befundId("regallizenz", null, abo.sku),
            art: "regallizenz",
            sicherheit: offen > regelwerk.reserveLizenzen ? "sicher" : "pruefen",
            titel: `${skuName(abo.sku)}: ${inWorten(offen, "Platz", "Plätze")} unbenutzt gekauft`,
            begruendung:
                `${abo.gekauft} Plätze gekauft, ${abo.zugewiesen} zugewiesen. ` +
                `${inWorten(offen, "Platz kostet", "Plätze kosten")} ${euro(wert)} im Monat, ` +
                `ohne dass jemand sie nutzt.`,
            empfehlung:
                offen > regelwerk.reserveLizenzen
                    ? "Platzzahl zur nächsten Verlängerung reduzieren." +
                      (abo.laufzeitEnde ? ` Die Laufzeit endet am ${datumKurz(abo.laufzeitEnde)}.` : "")
                    : "Kleine Reserve für neue Mitarbeiter kann sinnvoll sein — bewusst entscheiden.",
            kontoId: null,
            upn: null,
            anzeigename: null,
            sku: abo.sku,
            zielSku: null,
            anzahl: offen,
            ersparnisCentMonat: wert,
        });
    }

    // 5.–7. Regeln für Konten, die tatsächlich benutzt werden.
    for (const konto of bestand.konten) {
        if (abgerechnet.has(konto.id)) continue;
        const lizenzen = konto.skus;
        const basisplaene = lizenzen.filter(istBasisplan);
        const genutzt = genutzteDienste(konto);

        // 5. Mehrere Basispläne auf einem Konto.
        if (basisplaene.length > 1) {
            const sortiert = [...basisplaene].sort((a, b) => preis(b) - preis(a));
            const behalten = sortiert[0]!;
            const ueberzaehlig = sortiert.slice(1);
            const wert = summe(ueberzaehlig, preis);
            if (wert > 0) {
                befunde.push({
                    id: befundId("doppelte_lizenz", konto.id, null),
                    art: "doppelte_lizenz",
                    sicherheit: "sicher",
                    titel: `${konto.anzeigename}: ${basisplaene.length} Basispläne gleichzeitig`,
                    begruendung:
                        `Zugewiesen sind ${skuListe(basisplaene)}. Die Funktionen überschneiden ` +
                        `sich weitgehend; ${skuName(behalten)} deckt sie ab.`,
                    empfehlung: `${skuListe(ueberzaehlig)} entziehen.`,
                    kontoId: konto.id,
                    upn: konto.upn,
                    anzeigename: konto.anzeigename,
                    sku: ueberzaehlig[0] ?? null,
                    zielSku: behalten,
                    anzahl: ueberzaehlig.length,
                    ersparnisCentMonat: wert,
                });
                continue; // keine Abstufung obendrauf
            }
        }

        // 6. Zusatzprodukte, deren Dienst nicht benutzt wird.
        for (const id of lizenzen) {
            const definition = sku(id);
            if (!definition || definition.art !== "zusatz" || !definition.belegtDurch) continue;
            const dienst = definition.belegtDurch;
            const letzte = konto.letzteAktivitaet[dienst];
            const ruhetage = letzte ? tageBis(letzte, stichtag) : null;
            if (ruhetage !== null && ruhetage <= regelwerk.zusatzInaktivTage) continue;
            const wert = preis(id);
            if (wert <= 0) continue;
            befunde.push({
                id: befundId("ungenutztes_zusatzprodukt", konto.id, id),
                art: "ungenutztes_zusatzprodukt",
                sicherheit: letzte ? "pruefen" : "sicher",
                titel: `${konto.anzeigename}: ${definition.name} ohne Nutzung`,
                begruendung: letzte
                    ? `${DIENST_TEXT[dienst]} wurde zuletzt am ${datumKurz(letzte)} genutzt, das ist ` +
                      `${ruhetage} Tage her.`
                    : `Für ${DIENST_TEXT[dienst]} ist keinerlei Nutzung verzeichnet.`,
                empfehlung:
                    `${definition.name} entziehen oder an jemanden vergeben, der damit arbeitet. ` +
                    `Bei Copilot lohnt vorher ein Gespräch — oft fehlt nur die Einführung.`,
                kontoId: konto.id,
                upn: konto.upn,
                anzeigename: konto.anzeigename,
                sku: id,
                zielSku: null,
                anzahl: 1,
                ersparnisCentMonat: wert,
            });
        }

        // 7. Großer Plan, kleiner Bedarf.
        //
        // Eine Abstufung wird nur vorgeschlagen, wenn der Bericht auch etwas
        // hergibt: Mindestens ein Dienst des laufenden Plans muss ungenutzt
        // sein. Ohne diese Bedingung empfiehlt die Regel jedem Business
        // Premium den Wechsel auf Business Standard — die beiden schalten
        // dieselben Dienste frei und unterscheiden sich in Verwaltung und
        // Sicherheit, wovon Nutzungsberichte nichts wissen. Solche Ersparnis
        // wäre erfunden.
        if (genutzt.length === 0) continue;
        for (const id of basisplaene) {
            const definition = sku(id);
            if (!definition?.abstufungen?.length) continue;
            const unbenutzteDienste = definition.dienste.filter((dienst) => !genutzt.includes(dienst));
            if (unbenutzteDienste.length === 0) continue;
            const kandidaten = definition.abstufungen
                .map((ziel) => sku(ziel))
                .filter((ziel): ziel is NonNullable<typeof ziel> => Boolean(ziel))
                .filter((ziel) => genutzt.every((dienst) => ziel.dienste.includes(dienst)))
                // Ein Plan mit demselben Dienstumfang ist kein Beleg, sondern
                // nur billiger — die Differenz steckt dann in Funktionen, die
                // hier niemand messen kann.
                .filter((ziel) => ziel.dienste.length < definition.dienste.length)
                .sort((a, b) => preis(a.id) - preis(b.id));
            const ziel = kandidaten[0];
            if (!ziel) continue;
            const wert = preis(id) - preis(ziel.id);
            if (wert <= 0) continue;
            const ungenutzt = unbenutzteDienste;
            befunde.push({
                id: befundId("ueberdimensioniert", konto.id, id),
                art: "ueberdimensioniert",
                sicherheit: "pruefen",
                titel: `${konto.anzeigename}: ${definition.name} reicht über den Bedarf hinaus`,
                begruendung:
                    `Genutzt werden ${genutzt.map((d) => DIENST_TEXT[d]).join(", ")}. ` +
                    (ungenutzt.length
                        ? `Ungenutzt bleiben ${ungenutzt.map((d) => DIENST_TEXT[d]).join(", ")}. `
                        : "") +
                    `${ziel.name} deckt den tatsächlichen Bedarf ab.`,
                empfehlung:
                    `Auf ${ziel.name} abstufen — spart ${euro(wert)} im Monat. Vorher prüfen, ` +
                    `ob Funktionen gebraucht werden, die in keinem Nutzungsbericht auftauchen: ` +
                    `Geräteverwaltung, erweiterter Bedrohungsschutz, Archivierung.`,
                kontoId: konto.id,
                upn: konto.upn,
                anzeigename: konto.anzeigename,
                sku: id,
                zielSku: ziel.id,
                anzahl: 1,
                ersparnisCentMonat: wert,
            });
        }
    }

    befunde.sort(
        (a, b) => b.ersparnisCentMonat - a.ersparnisCentMonat || a.titel.localeCompare(b.titel),
    );

    const nachArt = leereZaehlung();
    for (const befund of befunde) {
        nachArt[befund.art].anzahl += 1;
        nachArt[befund.art].ersparnisCentMonat += befund.ersparnisCentMonat;
    }

    return {
        stichtag,
        befunde,
        ersparnisCentMonat: befunde.reduce((wert, b) => wert + b.ersparnisCentMonat, 0),
        ersparnisSicherCentMonat: befunde
            .filter((b) => b.sicherheit === "sicher")
            .reduce((wert, b) => wert + b.ersparnisCentMonat, 0),
        ersparnisPruefenCentMonat: befunde
            .filter((b) => b.sicherheit === "pruefen")
            .reduce((wert, b) => wert + b.ersparnisCentMonat, 0),
        lizenzkostenCentMonat: bestand.abonnements.reduce(
            (wert, abo) => wert + abo.gekauft * preis(abo.sku),
            0,
        ),
        anzahlKonten: bestand.konten.length,
        anzahlZuweisungen: bestand.konten.reduce((wert, konto) => wert + konto.skus.length, 0),
        nachArt,
    };
}
