// SQLite als Ablage. Die Datenmengen sind klein — ein Mandant mit 500 Konten
// ergibt ein paar tausend Zeilen je Auswertung —, und eine Datei lässt sich
// verschlüsselt sichern, ohne einen Datenbankserver zu betreiben.
//
// Der Umstieg auf PostgreSQL ist vorbereitet: sämtliches SQL steht in dieser
// Datei und in app.ts, es gibt keine SQLite-Eigenheiten im Schema.

import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import Datenbank from "better-sqlite3";
import type { Database } from "better-sqlite3";

export type Db = Database;

const SCHEMA_VERSION = 1;

const SCHEMA = `
CREATE TABLE organisationen (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    tarif       TEXT NOT NULL DEFAULT 'test',
    erstellt_am TEXT NOT NULL
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

-- Der Microsoft-365-Mandant eines Kunden. Ein Systemhaus verwaltet mehrere.
CREATE TABLE mandanten (
    id              TEXT PRIMARY KEY,
    organisation_id TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    notiz           TEXT NOT NULL DEFAULT '',
    erstellt_am     TEXT NOT NULL
);
CREATE INDEX mandanten_organisation ON mandanten(organisation_id);

CREATE TABLE auswertungen (
    id                    TEXT PRIMARY KEY,
    mandant_id            TEXT NOT NULL REFERENCES mandanten(id) ON DELETE CASCADE,
    stichtag              TEXT NOT NULL,
    erstellt_am           TEXT NOT NULL,
    erstellt_von          TEXT,
    quelle                TEXT NOT NULL DEFAULT 'csv',
    anzahl_konten         INTEGER NOT NULL DEFAULT 0,
    anzahl_zuweisungen    INTEGER NOT NULL DEFAULT 0,
    lizenzkosten_cent     INTEGER NOT NULL DEFAULT 0,
    ersparnis_cent        INTEGER NOT NULL DEFAULT 0,
    ersparnis_sicher_cent INTEGER NOT NULL DEFAULT 0,
    ersparnis_pruefen_cent INTEGER NOT NULL DEFAULT 0,
    warnungen             TEXT NOT NULL DEFAULT '[]'
);
CREATE INDEX auswertungen_mandant ON auswertungen(mandant_id, erstellt_am DESC);

CREATE TABLE befunde (
    id             TEXT PRIMARY KEY,
    auswertung_id  TEXT NOT NULL REFERENCES auswertungen(id) ON DELETE CASCADE,
    mandant_id     TEXT NOT NULL REFERENCES mandanten(id) ON DELETE CASCADE,
    schluessel     TEXT NOT NULL,
    art            TEXT NOT NULL,
    sicherheit     TEXT NOT NULL,
    titel          TEXT NOT NULL,
    begruendung    TEXT NOT NULL,
    empfehlung     TEXT NOT NULL,
    upn            TEXT,
    anzeigename    TEXT,
    sku            TEXT,
    ziel_sku       TEXT,
    anzahl         INTEGER NOT NULL DEFAULT 1,
    ersparnis_cent INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX befunde_auswertung ON befunde(auswertung_id);
CREATE INDEX befunde_schluessel ON befunde(mandant_id, schluessel);

-- Der Bearbeitungsstand hängt am Befundschlüssel, nicht an der Auswertung:
-- nur so überlebt ein "ignoriert" den nächsten Import.
CREATE TABLE befund_stand (
    mandant_id   TEXT NOT NULL REFERENCES mandanten(id) ON DELETE CASCADE,
    schluessel   TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'offen',
    notiz        TEXT NOT NULL DEFAULT '',
    geaendert_am TEXT NOT NULL,
    geaendert_von TEXT,
    PRIMARY KEY (mandant_id, schluessel)
);

CREATE TABLE preise (
    mandant_id TEXT NOT NULL REFERENCES mandanten(id) ON DELETE CASCADE,
    sku        TEXT NOT NULL,
    cent       INTEGER NOT NULL,
    PRIMARY KEY (mandant_id, sku)
);

CREATE TABLE verlauf (
    id              TEXT PRIMARY KEY,
    organisation_id TEXT NOT NULL REFERENCES organisationen(id) ON DELETE CASCADE,
    mandant_id      TEXT,
    benutzer_id     TEXT,
    aktion          TEXT NOT NULL,
    beschreibung    TEXT NOT NULL,
    zeitpunkt       TEXT NOT NULL
);
CREATE INDEX verlauf_organisation ON verlauf(organisation_id, zeitpunkt DESC);
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

export function protokolliere(
    db: Db,
    eintrag: {
        organisationId: string;
        mandantId?: string | null;
        benutzerId?: string | null;
        aktion: string;
        beschreibung: string;
    },
): void {
    db.prepare(
        `INSERT INTO verlauf (id, organisation_id, mandant_id, benutzer_id, aktion, beschreibung, zeitpunkt)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).run(
        crypto.randomUUID(),
        eintrag.organisationId,
        eintrag.mandantId ?? null,
        eintrag.benutzerId ?? null,
        eintrag.aktion,
        eintrag.beschreibung,
        new Date().toISOString(),
    );
}
