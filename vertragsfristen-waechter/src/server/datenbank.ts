// SQLite-Ablage. Eine Datei, keine Serverinstallation — für ein Werkzeug, das
// pro Kunde ein paar hundert Verträge verwaltet, reicht das mit Abstand.

import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import Datenbank from "better-sqlite3";
import type { Database } from "better-sqlite3";
import { schluessel } from "./umgebung.ts";
import type {
    Benutzer,
    Kategorie,
    Organisation,
    Vertrag,
} from "../fachlogik/typen.ts";

export type Db = Database;

const SCHEMA_VERSION = 1;

const SCHEMA = `
CREATE TABLE organisationen (
    id                  TEXT PRIMARY KEY,
    name                TEXT NOT NULL,
    erinnerungsvorlauf  TEXT NOT NULL DEFAULT '[90,30,14,3]',
    verteiler           TEXT NOT NULL DEFAULT '[]',
    kalender_schluessel TEXT NOT NULL UNIQUE,
    erstellt_am         TEXT NOT NULL
);

CREATE TABLE benutzer (
    id              TEXT PRIMARY KEY,
    organisation_id TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    email           TEXT NOT NULL COLLATE NOCASE,
    kennwort_hash   TEXT NOT NULL,
    rolle           TEXT NOT NULL DEFAULT 'mitglied',
    erstellt_am     TEXT NOT NULL
);
CREATE UNIQUE INDEX benutzer_email ON benutzer(email COLLATE NOCASE);

CREATE TABLE sitzungen (
    marke_hash   TEXT PRIMARY KEY,
    benutzer_id  TEXT NOT NULL REFERENCES benutzer(id) ON DELETE CASCADE,
    erstellt_am  TEXT NOT NULL,
    laeuft_ab_am TEXT NOT NULL
);

CREATE TABLE vertraege (
    id                       TEXT PRIMARY KEY,
    organisation_id          TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    bezeichnung              TEXT NOT NULL,
    anbieter                 TEXT NOT NULL DEFAULT '',
    kategorie                TEXT NOT NULL DEFAULT 'sonstiges',
    vertragsnummer           TEXT NOT NULL DEFAULT '',
    abteilung                TEXT NOT NULL DEFAULT '',
    ansprechpartner          TEXT NOT NULL DEFAULT '',
    beginn                   TEXT NOT NULL,
    laufzeitmodell           TEXT NOT NULL,
    erstlaufzeit_monate      INTEGER NOT NULL DEFAULT 0,
    verlaengerung_monate     INTEGER NOT NULL DEFAULT 0,
    kuendigungsfrist_wert    INTEGER NOT NULL DEFAULT 0,
    kuendigungsfrist_einheit TEXT NOT NULL DEFAULT 'monate',
    kuendigungsfrist_bezug   TEXT NOT NULL DEFAULT 'zum_laufzeitende',
    betrag_cent              INTEGER NOT NULL DEFAULT 0,
    zahlungsintervall        TEXT NOT NULL DEFAULT 'jaehrlich',
    status                   TEXT NOT NULL DEFAULT 'aktiv',
    gekuendigt_zum           TEXT,
    dokument_link            TEXT NOT NULL DEFAULT '',
    notizen                  TEXT NOT NULL DEFAULT '',
    erstellt_am              TEXT NOT NULL,
    geaendert_am             TEXT NOT NULL
);
CREATE INDEX vertraege_organisation ON vertraege(organisation_id, status);

CREATE TABLE erinnerungen (
    id              TEXT PRIMARY KEY,
    organisation_id TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    vertrag_id      TEXT NOT NULL REFERENCES vertraege(id) ON DELETE CASCADE,
    stichtag        TEXT NOT NULL,
    vorlauf_tage    INTEGER NOT NULL,
    faellig_am      TEXT NOT NULL,
    erzeugt_am      TEXT NOT NULL,
    versendet_am    TEXT,
    erledigt_am     TEXT,
    UNIQUE (vertrag_id, stichtag, vorlauf_tage)
);
CREATE INDEX erinnerungen_faellig ON erinnerungen(organisation_id, faellig_am);

CREATE TABLE postausgang (
    id              TEXT PRIMARY KEY,
    organisation_id TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    empfaenger      TEXT NOT NULL,
    betreff         TEXT NOT NULL,
    inhalt          TEXT NOT NULL,
    erzeugt_am      TEXT NOT NULL,
    versendet_am    TEXT,
    fehler          TEXT
);
CREATE INDEX postausgang_organisation ON postausgang(organisation_id, erzeugt_am);

CREATE TABLE verlauf (
    id              TEXT PRIMARY KEY,
    organisation_id TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    vertrag_id      TEXT,
    benutzer_id     TEXT,
    aktion          TEXT NOT NULL,
    beschreibung    TEXT NOT NULL,
    zeitpunkt       TEXT NOT NULL
);
CREATE INDEX verlauf_organisation ON verlauf(organisation_id, zeitpunkt);
`;

export function oeffneDatenbank(datei: string): Db {
    if (datei !== ":memory:") mkdirSync(dirname(datei), { recursive: true });
    const db = new Datenbank(datei);
    db.pragma("journal_mode = WAL");
    db.pragma("foreign_keys = ON");
    const version = (db.pragma("user_version", { simple: true }) as number) ?? 0;
    if (version < 1) {
        db.exec(SCHEMA);
        db.pragma(`user_version = ${SCHEMA_VERSION}`);
    }
    return db;
}

// --- Zeilen ↔ Fachobjekte -------------------------------------------------
// Die Datenbank schreibt Unterstriche, die Fachlogik schreibt Binnenmajuskel.
// Diese beiden Funktionen sind die einzige Stelle, an der das übersetzt wird.

export interface VertragZeile {
    id: string;
    organisation_id: string;
    bezeichnung: string;
    anbieter: string;
    kategorie: string;
    vertragsnummer: string;
    abteilung: string;
    ansprechpartner: string;
    beginn: string;
    laufzeitmodell: string;
    erstlaufzeit_monate: number;
    verlaengerung_monate: number;
    kuendigungsfrist_wert: number;
    kuendigungsfrist_einheit: string;
    kuendigungsfrist_bezug: string;
    betrag_cent: number;
    zahlungsintervall: string;
    status: string;
    gekuendigt_zum: string | null;
    dokument_link: string;
    notizen: string;
    erstellt_am: string;
    geaendert_am: string;
}

export function zuVertrag(zeile: VertragZeile): Vertrag {
    return {
        id: zeile.id,
        organisationId: zeile.organisation_id,
        bezeichnung: zeile.bezeichnung,
        anbieter: zeile.anbieter,
        kategorie: zeile.kategorie as Kategorie,
        vertragsnummer: zeile.vertragsnummer,
        abteilung: zeile.abteilung,
        ansprechpartner: zeile.ansprechpartner,
        beginn: zeile.beginn,
        laufzeitmodell: zeile.laufzeitmodell as Vertrag["laufzeitmodell"],
        erstlaufzeitMonate: zeile.erstlaufzeit_monate,
        verlaengerungMonate: zeile.verlaengerung_monate,
        kuendigungsfristWert: zeile.kuendigungsfrist_wert,
        kuendigungsfristEinheit: zeile.kuendigungsfrist_einheit as Vertrag["kuendigungsfristEinheit"],
        kuendigungsfristBezug: zeile.kuendigungsfrist_bezug as Vertrag["kuendigungsfristBezug"],
        betragCent: zeile.betrag_cent,
        zahlungsintervall: zeile.zahlungsintervall as Vertrag["zahlungsintervall"],
        status: zeile.status as Vertrag["status"],
        gekuendigtZum: zeile.gekuendigt_zum,
        dokumentLink: zeile.dokument_link,
        notizen: zeile.notizen,
        erstelltAm: zeile.erstellt_am,
        geaendertAm: zeile.geaendert_am,
    };
}

export interface OrganisationZeile {
    id: string;
    name: string;
    erinnerungsvorlauf: string;
    verteiler: string;
    kalender_schluessel: string;
    erstellt_am: string;
}

export function zuOrganisation(zeile: OrganisationZeile): Organisation {
    return {
        id: zeile.id,
        name: zeile.name,
        erinnerungsvorlauf: jsonListe(zeile.erinnerungsvorlauf).map(Number).filter(Number.isFinite),
        verteiler: jsonListe(zeile.verteiler).map(String),
        kalenderSchluessel: zeile.kalender_schluessel,
        erstelltAm: zeile.erstellt_am,
    };
}

export interface BenutzerZeile {
    id: string;
    organisation_id: string;
    name: string;
    email: string;
    kennwort_hash: string;
    rolle: string;
    erstellt_am: string;
}

export function zuBenutzer(zeile: BenutzerZeile): Benutzer {
    return {
        id: zeile.id,
        organisationId: zeile.organisation_id,
        name: zeile.name,
        email: zeile.email,
        rolle: zeile.rolle === "inhaber" ? "inhaber" : "mitglied",
        erstelltAm: zeile.erstellt_am,
    };
}

function jsonListe(text: string): unknown[] {
    try {
        const wert = JSON.parse(text);
        return Array.isArray(wert) ? wert : [];
    } catch {
        return [];
    }
}

export function neuerKalenderschluessel(): string {
    return schluessel(18);
}

export function protokolliere(
    db: Db,
    eintrag: {
        organisationId: string;
        vertragId?: string | null;
        benutzerId?: string | null;
        aktion: string;
        beschreibung: string;
    },
): void {
    db.prepare(
        `INSERT INTO verlauf (id, organisation_id, vertrag_id, benutzer_id, aktion, beschreibung, zeitpunkt)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).run(
        crypto.randomUUID(),
        eintrag.organisationId,
        eintrag.vertragId ?? null,
        eintrag.benutzerId ?? null,
        eintrag.aktion,
        eintrag.beschreibung,
        new Date().toISOString(),
    );
}
