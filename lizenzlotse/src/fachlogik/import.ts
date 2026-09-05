// Einlesen der Ausgaben aus dem Microsoft-365-Adminportal.
//
// Das ist der Einstieg ohne jede Berechtigung: Wer den Lotsen ausprobieren
// will, lädt zwei bis drei CSV-Dateien hoch und bekommt sofort seinen
// Bericht — niemand muss vorher einer fremden Anwendung Zugriff auf seinen
// Mandanten geben.
//
// Die Exporte sehen je nach Sprache und Portalversion anders aus. Deshalb
// werden Spalten nicht über feste Positionen gefunden, sondern über eine
// Liste bekannter Bezeichnungen in Deutsch und Englisch.

import { istIsoDatum, type IsoDatum } from "./datum.ts";
import { SKUS, sku } from "./skus.ts";
import { DIENSTE, type Abonnement, type Bestand, type Dienst, type Konto } from "./typen.ts";

// --- CSV-Zerlegung ---------------------------------------------------------

export interface Tabelle {
    kopf: string[];
    zeilen: string[][];
}

/** Erkennt Semikolon oder Komma als Trennzeichen und versteht Anführungszeichen. */
export function zerlegeCsv(text: string): Tabelle {
    const ohneBom = text.replace(/^﻿/, "");
    const trenner = bestimmeTrenner(ohneBom);
    const zeilen: string[][] = [];
    let feld = "";
    let zeile: string[] = [];
    let inAnfuehrung = false;

    for (let i = 0; i < ohneBom.length; i += 1) {
        const zeichen = ohneBom[i]!;
        if (inAnfuehrung) {
            if (zeichen === '"') {
                if (ohneBom[i + 1] === '"') {
                    feld += '"';
                    i += 1;
                } else {
                    inAnfuehrung = false;
                }
            } else {
                feld += zeichen;
            }
            continue;
        }
        if (zeichen === '"') {
            inAnfuehrung = true;
        } else if (zeichen === trenner) {
            zeile.push(feld);
            feld = "";
        } else if (zeichen === "\n") {
            zeile.push(feld);
            if (zeile.some((wert) => wert.trim() !== "")) zeilen.push(zeile);
            zeile = [];
            feld = "";
        } else if (zeichen !== "\r") {
            feld += zeichen;
        }
    }
    zeile.push(feld);
    if (zeile.some((wert) => wert.trim() !== "")) zeilen.push(zeile);

    const kopf = (zeilen.shift() ?? []).map((wert) => wert.trim());
    return { kopf, zeilen };
}

function bestimmeTrenner(text: string): string {
    const ersteZeile = text.slice(0, text.indexOf("\n") + 1 || text.length);
    const semikola = (ersteZeile.match(/;/g) ?? []).length;
    const kommata = (ersteZeile.match(/,/g) ?? []).length;
    if (semikola > kommata) return ";";
    if (kommata > 0) return ",";
    if ((ersteZeile.match(/\t/g) ?? []).length > 0) return "\t";
    return ",";
}

/** Vergleichsform einer Spaltenüberschrift: ohne Umlaute, Leer- und Sonderzeichen. */
export function normalisiere(text: string): string {
    return text
        .toLowerCase()
        .replace(/ä/g, "ae")
        .replace(/ö/g, "oe")
        .replace(/ü/g, "ue")
        .replace(/ß/g, "ss")
        .replace(/[^a-z0-9]/g, "");
}

// --- Spaltenerkennung ------------------------------------------------------

const SPALTEN = {
    upn: ["userprincipalname", "benutzerprinzipalname", "benutzername", "upn", "emailadresse", "email"],
    anzeigename: ["displayname", "anzeigename", "name", "vollstaendigername"],
    abteilung: ["department", "abteilung"],
    gesperrt: ["signinblocked", "blockcredential", "anmeldungblockiert", "anmeldunggesperrt", "gesperrt"],
    aktiviert: ["accountenabled", "kontoaktiviert", "aktiviert", "signinallowed"],
    lizenzen: ["licenses", "lizenzen", "assignedlicenses", "zugewiesenelizenzen", "licenseassigned", "produktlizenzen"],
    erstelltAm: ["createddatetime", "created", "erstellungsdatum", "erstelltam", "erstelltdatum"],
    geloescht: ["isdeleted", "geloescht", "userdeleted"],
    produkt: ["productname", "produktname", "produkt", "subscriptionname", "skupartnumber", "sku", "licenseskuid"],
    gekauft: ["purchasedquantity", "totallicenses", "gekauft", "erworbeneanzahl", "gesamtlizenzen", "anzahlgekauft"],
    zugewiesen: ["assignedquantity", "assignedlicenses", "zugewiesen", "zugewieseneanzahl", "verwendetelizenzen"],
    laufzeitEnde: ["nextlifecycledate", "expirationdate", "ablaufdatum", "verlaengerungsdatum", "laufzeitende"],
} as const;

type Feld = keyof typeof SPALTEN;

/** Findet die Spalte zu einem Feld; -1, wenn die Tabelle sie nicht hat. */
export function findeSpalte(kopf: string[], feld: Feld): number {
    const kandidaten = SPALTEN[feld] as readonly string[];
    const normal = kopf.map(normalisiere);
    for (const kandidat of kandidaten) {
        const treffer = normal.indexOf(kandidat);
        if (treffer >= 0) return treffer;
    }
    // Zweiter Versuch: Überschrift enthält den Kandidaten (Exporte hängen
    // gern Zusätze an, etwa "Anzeigename (Display Name)").
    for (const kandidat of kandidaten) {
        const treffer = normal.findIndex((wert) => wert.includes(kandidat));
        if (treffer >= 0) return treffer;
    }
    return -1;
}

/** Spalten mit dem letzten Aktivitätsdatum je Dienst. */
const AKTIVITAETSSPALTEN: Record<Dienst, string[]> = {
    exchange: ["exchangelastactivitydate", "exchangeletzteaktivitaet", "letzteexchangeaktivitaet"],
    sharepoint: ["sharepointlastactivitydate", "sharepointletzteaktivitaet"],
    onedrive: ["onedrivelastactivitydate", "onedriveletzteaktivitaet"],
    teams: ["teamslastactivitydate", "microsoftteamslastactivitydate", "teamsletzteaktivitaet"],
    office: ["office365lastactivitydate", "officelastactivitydate", "officeletzteaktivitaet", "lastactivitydate"],
    copilot: ["copilotlastactivitydate", "copilotletzteaktivitaet", "m365copilotlastactivitydate"],
};

function findeAktivitaetsspalte(kopf: string[], dienst: Dienst): number {
    const normal = kopf.map(normalisiere);
    for (const kandidat of AKTIVITAETSSPALTEN[dienst]) {
        const treffer = normal.indexOf(kandidat);
        if (treffer >= 0) return treffer;
    }
    for (const kandidat of AKTIVITAETSSPALTEN[dienst]) {
        const treffer = normal.findIndex((wert) => wert.includes(kandidat));
        if (treffer >= 0) return treffer;
    }
    return -1;
}

// --- Wertumwandlung --------------------------------------------------------

const JA = new Set(["true", "ja", "yes", "1", "wahr", "x"]);
const NEIN = new Set(["false", "nein", "no", "0", "falsch", ""]);

function alsWahrheit(wert: string | undefined): boolean | null {
    const text = (wert ?? "").trim().toLowerCase();
    if (JA.has(text)) return true;
    if (NEIN.has(text)) return false;
    return null;
}

/** Nimmt ISO-Daten, deutsche Datumsangaben und Zeitstempel an. */
export function alsDatum(wert: string | undefined): IsoDatum | null {
    const text = (wert ?? "").trim();
    if (!text) return null;
    const iso = text.slice(0, 10);
    if (istIsoDatum(iso)) return iso;
    const deutsch = /^(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(text);
    if (deutsch) {
        const [, tag, monat, jahr] = deutsch;
        const gebaut = `${jahr}-${monat!.padStart(2, "0")}-${tag!.padStart(2, "0")}`;
        if (istIsoDatum(gebaut)) return gebaut;
    }
    return null;
}

function alsZahl(wert: string | undefined): number {
    const zahl = Number((wert ?? "").replace(/[^\d-]/g, ""));
    return Number.isFinite(zahl) ? zahl : 0;
}

const NAME_ZU_SKU = new Map<string, string>();
for (const eintrag of SKUS) {
    NAME_ZU_SKU.set(normalisiere(eintrag.name), eintrag.id);
    NAME_ZU_SKU.set(normalisiere(eintrag.id), eintrag.id);
}
// Schreibweisen, die in Exporten vorkommen, aber nicht dem Katalognamen gleichen.
for (const [alias, ziel] of [
    ["office365e3", "ENTERPRISEPACK"],
    ["office365e1", "STANDARDPACK"],
    ["office365e5", "ENTERPRISEPREMIUM"],
    ["microsoft365businessstandard", "O365_BUSINESS_PREMIUM"],
    ["microsoft365businessbasic", "O365_BUSINESS_ESSENTIALS"],
    ["microsoft365businesspremium", "SPB"],
    ["microsoft365apemiumforbusiness", "SPB"],
    ["microsoft365copilot", "Microsoft_365_Copilot"],
    ["copilotformicrosoft365", "Microsoft_365_Copilot"],
    ["visioplan2", "VISIOCLIENT"],
    ["visioonlineplan2", "VISIOCLIENT"],
    ["visioplan1", "VISIO_PLAN1_DEPT"],
    ["projectplan3", "PROJECTPROFESSIONAL"],
    ["projectonlineprofessional", "PROJECTPROFESSIONAL"],
    ["projectplan1", "PROJECT_P1"],
    ["powerbipro", "POWER_BI_PRO"],
    ["exchangeonlineplan1", "EXCHANGESTANDARD"],
    ["exchangeonlineplan2", "EXCHANGEENTERPRISE"],
    ["azureactivedirectorypremiump1", "AAD_PREMIUM"],
    ["azureactivedirectorypremiump2", "AAD_PREMIUM_P2"],
    ["microsoftentraidp1", "AAD_PREMIUM"],
    ["microsoftentraidp2", "AAD_PREMIUM_P2"],
    ["microsoftintuneplan1", "INTUNE_A"],
    ["microsoft365f3", "SPE_F3"],
    ["microsoft365f1", "SPE_F1"],
    ["microsoft365e3", "SPE_E3"],
    ["microsoft365e5", "SPE_E5"],
] as const) {
    NAME_ZU_SKU.set(alias, ziel);
}

/** Übersetzt einen Lizenznamen aus dem Export in eine Katalogkennung. */
export function erkenneSku(bezeichnung: string): string {
    const roh = bezeichnung.trim();
    if (!roh) return "";
    return NAME_ZU_SKU.get(normalisiere(roh)) ?? sku(roh)?.id ?? roh;
}

function zerlegeLizenzen(wert: string | undefined): string[] {
    return (wert ?? "")
        .split(/[+;,|]/)
        .map((teil) => erkenneSku(teil))
        .filter(Boolean);
}

// --- Zusammenbau -----------------------------------------------------------

export type Tabellenart = "konten" | "nutzung" | "abonnements" | "unbekannt";

export function erkenneTabellenart(kopf: string[]): Tabellenart {
    const hatAktivitaet = DIENSTE.some((dienst) => findeAktivitaetsspalte(kopf, dienst) >= 0);
    if (hatAktivitaet) return "nutzung";
    if (findeSpalte(kopf, "gekauft") >= 0 && findeSpalte(kopf, "produkt") >= 0) return "abonnements";
    if (findeSpalte(kopf, "upn") >= 0) return "konten";
    return "unbekannt";
}

export interface Importergebnis {
    bestand: Bestand;
    warnungen: string[];
    /** Welche Datei wofür gehalten wurde — steht so in der Oberfläche. */
    dateien: { name: string; art: Tabellenart; zeilen: number }[];
}

export interface Quelldatei {
    name: string;
    inhalt: string;
}

export function baueBestand(dateien: Quelldatei[], stichtag: IsoDatum): Importergebnis {
    const konten = new Map<string, Konto>();
    const abonnements: Abonnement[] = [];
    const warnungen: string[] = [];
    const uebersicht: Importergebnis["dateien"] = [];

    for (const datei of dateien) {
        const tabelle = zerlegeCsv(datei.inhalt);
        const art = erkenneTabellenart(tabelle.kopf);
        uebersicht.push({ name: datei.name, art, zeilen: tabelle.zeilen.length });

        if (art === "unbekannt") {
            warnungen.push(
                `„${datei.name}“ wurde nicht erkannt. Erwartet werden die Ausgaben aus ` +
                `Adminportal → Benutzer, Berichte → Nutzung und Abrechnung → Ihre Produkte.`,
            );
            continue;
        }
        if (art === "abonnements") {
            lesAbonnements(tabelle, abonnements);
            continue;
        }
        if (art === "konten") lesKonten(tabelle, konten);
        if (art === "nutzung") lesNutzung(tabelle, konten);
    }

    if (konten.size === 0) {
        warnungen.push("Keine Konten gefunden — ohne die Benutzerliste lässt sich nichts rechnen.");
    }
    // Es genügt, dass für kein einziges Konto Nutzungsdaten vorliegen — eine
    // Quote über alle Konten hätte hier den Fall verfehlt, in dem gesperrte
    // Konten die Zählung verwässern.
    const mitNutzung = [...konten.values()].filter(
        (konto) => Object.keys(konto.letzteAktivitaet).length > 0,
    ).length;
    if (konten.size > 0 && mitNutzung === 0) {
        warnungen.push(
            "Für kein Konto liegen Nutzungsdaten vor. Ohne den Bericht aus " +
            "Berichte → Nutzung → Microsoft 365 lassen sich inaktive Konten nur raten.",
        );
    }
    if (abonnements.length === 0) {
        warnungen.push(
            "Keine Abonnementdaten gefunden — gekaufte, aber nicht zugewiesene Lizenzen " +
            "bleiben dadurch unentdeckt.",
        );
    }

    return {
        bestand: { stichtag, konten: [...konten.values()], abonnements },
        warnungen,
        dateien: uebersicht,
    };
}

function schluessel(upn: string): string {
    return upn.trim().toLowerCase();
}

function lesKonten(tabelle: Tabelle, konten: Map<string, Konto>): void {
    const { kopf, zeilen } = tabelle;
    const sUpn = findeSpalte(kopf, "upn");
    if (sUpn < 0) return;
    const sName = findeSpalte(kopf, "anzeigename");
    const sAbteilung = findeSpalte(kopf, "abteilung");
    const sGesperrt = findeSpalte(kopf, "gesperrt");
    const sAktiviert = findeSpalte(kopf, "aktiviert");
    const sLizenzen = findeSpalte(kopf, "lizenzen");
    const sErstellt = findeSpalte(kopf, "erstelltAm");
    const sGeloescht = findeSpalte(kopf, "geloescht");

    for (const zeile of zeilen) {
        const upn = (zeile[sUpn] ?? "").trim();
        if (!upn) continue;
        if (sGeloescht >= 0 && alsWahrheit(zeile[sGeloescht]) === true) continue;

        const gesperrt =
            sGesperrt >= 0
                ? (alsWahrheit(zeile[sGesperrt]) ?? false)
                : sAktiviert >= 0
                  ? alsWahrheit(zeile[sAktiviert]) === false
                  : false;

        const vorhanden = konten.get(schluessel(upn));
        const konto: Konto = {
            id: schluessel(upn),
            upn,
            anzeigename: (sName >= 0 ? zeile[sName] : "")?.trim() || upn,
            abteilung: (sAbteilung >= 0 ? zeile[sAbteilung] : "")?.trim() || "",
            gesperrt,
            erstelltAm: sErstellt >= 0 ? alsDatum(zeile[sErstellt]) : null,
            letzteAktivitaet: vorhanden?.letzteAktivitaet ?? {},
            skus: sLizenzen >= 0 ? zerlegeLizenzen(zeile[sLizenzen]) : (vorhanden?.skus ?? []),
        };
        konten.set(konto.id, konto);
    }
}

function lesNutzung(tabelle: Tabelle, konten: Map<string, Konto>): void {
    const { kopf, zeilen } = tabelle;
    const sUpn = findeSpalte(kopf, "upn");
    if (sUpn < 0) return;
    const sName = findeSpalte(kopf, "anzeigename");
    const sGeloescht = findeSpalte(kopf, "geloescht");
    const spalten = DIENSTE.map((dienst) => [dienst, findeAktivitaetsspalte(kopf, dienst)] as const);

    for (const zeile of zeilen) {
        const upn = (zeile[sUpn] ?? "").trim();
        if (!upn) continue;
        if (sGeloescht >= 0 && alsWahrheit(zeile[sGeloescht]) === true) continue;
        const id = schluessel(upn);
        const konto: Konto = konten.get(id) ?? {
            id,
            upn,
            anzeigename: (sName >= 0 ? zeile[sName] : "")?.trim() || upn,
            abteilung: "",
            gesperrt: false,
            erstelltAm: null,
            letzteAktivitaet: {},
            skus: [],
        };
        for (const [dienst, spalte] of spalten) {
            if (spalte < 0) continue;
            const datum = alsDatum(zeile[spalte]);
            if (datum) konto.letzteAktivitaet[dienst] = datum;
        }
        konten.set(id, konto);
    }
}

function lesAbonnements(tabelle: Tabelle, ziel: Abonnement[]): void {
    const { kopf, zeilen } = tabelle;
    const sProdukt = findeSpalte(kopf, "produkt");
    const sGekauft = findeSpalte(kopf, "gekauft");
    const sZugewiesen = findeSpalte(kopf, "zugewiesen");
    const sEnde = findeSpalte(kopf, "laufzeitEnde");
    if (sProdukt < 0 || sGekauft < 0) return;

    for (const zeile of zeilen) {
        const bezeichnung = (zeile[sProdukt] ?? "").trim();
        if (!bezeichnung) continue;
        ziel.push({
            sku: erkenneSku(bezeichnung),
            gekauft: alsZahl(zeile[sGekauft]),
            zugewiesen: sZugewiesen >= 0 ? alsZahl(zeile[sZugewiesen]) : 0,
            laufzeitEnde: sEnde >= 0 ? alsDatum(zeile[sEnde]) : null,
        });
    }
}
