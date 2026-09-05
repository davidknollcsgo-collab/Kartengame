// HTTP-Schnittstelle des Lotsen.
//
// Alle Antworten sind JSON, alle Fehler haben die Form
// { fehler: "Klartext", felder?: { feldname: "Meldung" } }.
//
// Sicherheitsgrundsätze, die überall gelten:
//  - Jede Abfrage filtert nach organisation_id aus der Sitzung. Es gibt keine
//    Zugriffsprüfung "nachträglich", sondern nur Abfragen, die fremde Daten
//    gar nicht erst finden.
//  - Alle SQL-Anweisungen sind vorbereitet; nichts wird zusammengesetzt.
//  - Schreibende Zugriffe verlangen die Rolle "inhaber", wo es um Geld,
//    Zugänge oder Löschungen geht.

import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import cookie from "@fastify/cookie";
import multipart from "@fastify/multipart";
import ratenbremse from "@fastify/rate-limit";
import statisch from "@fastify/static";
import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from "fastify";
import { werteAus, type Auswertung } from "../fachlogik/analyse.ts";
import { heute } from "../fachlogik/datum.ts";
import { baueBestand, type Quelldatei } from "../fachlogik/import.ts";
import { preisliste, skuName, SKUS } from "../fachlogik/skus.ts";
import type { Befundstatus } from "../fachlogik/typen.ts";
import { oeffneDatenbank, protokolliere, type Db } from "./datenbank.ts";
import { beispielausgaben } from "./demodaten.ts";
import { hashe, markenHash, stimmt } from "./kennwort.ts";
import {
    anmeldungSchema,
    einladungSchema,
    felderfehler,
    mandantSchema,
    preiseSchema,
    registrierungSchema,
    standSchema,
} from "./pruefung.ts";
import { schluessel, type Umgebung } from "./umgebung.ts";

const SITZUNGSKEKS = "lotse_sitzung";

export interface AppOptionen {
    db: Db;
    umgebung: Umgebung;
    heuteGeben?: () => string;
    protokoll?: boolean;
}

interface Angemeldet {
    benutzerId: string;
    organisationId: string;
    name: string;
    email: string;
    rolle: "inhaber" | "mitglied";
    organisationName: string;
}

declare module "fastify" {
    interface FastifyRequest {
        angemeldet?: Angemeldet;
    }
}

export function baueApp(optionen: AppOptionen): FastifyInstance {
    const { db, umgebung } = optionen;
    const heuteGeben = optionen.heuteGeben ?? (() => heute());
    const app = Fastify({ logger: optionen.protokoll ?? false, bodyLimit: 1_000_000 });

    app.register(cookie);
    app.register(multipart, {
        limits: { fileSize: umgebung.maxDateigroesseMb * 1024 * 1024, files: 6 },
    });
    // Bremst Anmeldeversuche und Massenabfragen. Bewusst großzügig für den
    // normalen Betrieb, eng genug gegen das Durchprobieren von Kennwörtern.
    app.register(ratenbremse, {
        max: 300,
        timeWindow: "1 minute",
        allowList: () => umgebung.entwicklung,
    });

    // --- Sitzungen --------------------------------------------------------

    function ladeSitzung(request: FastifyRequest): Angemeldet | null {
        const marke = request.cookies[SITZUNGSKEKS];
        if (!marke) return null;
        const zeile = db
            .prepare(
                `SELECT b.id, b.organisation_id, b.name, b.email, b.rolle, o.name AS organisation_name
                 FROM sitzungen s
                 JOIN benutzer b ON b.id = s.benutzer_id
                 JOIN organisationen o ON o.id = b.organisation_id
                 WHERE s.marke_hash = ? AND s.laeuft_ab_am > ?`,
            )
            .get(markenHash(marke), new Date().toISOString()) as
            | {
                  id: string;
                  organisation_id: string;
                  name: string;
                  email: string;
                  rolle: string;
                  organisation_name: string;
              }
            | undefined;
        if (!zeile) return null;
        return {
            benutzerId: zeile.id,
            organisationId: zeile.organisation_id,
            name: zeile.name,
            email: zeile.email,
            rolle: zeile.rolle === "inhaber" ? "inhaber" : "mitglied",
            organisationName: zeile.organisation_name,
        };
    }

    async function verlangeAnmeldung(request: FastifyRequest, reply: FastifyReply): Promise<void> {
        const sitzung = ladeSitzung(request);
        if (!sitzung) {
            reply.code(401).send({ fehler: "Bitte zuerst anmelden" });
            return;
        }
        request.angemeldet = sitzung;
    }

    async function verlangeInhaber(request: FastifyRequest, reply: FastifyReply): Promise<void> {
        await verlangeAnmeldung(request, reply);
        if (reply.sent) return;
        if (request.angemeldet!.rolle !== "inhaber") {
            reply.code(403).send({ fehler: "Dafür fehlt die Berechtigung — das darf nur der Inhaber" });
        }
    }

    function setzeSitzung(reply: FastifyReply, benutzerId: string): void {
        const marke = schluessel(32);
        const ablauf = new Date(Date.now() + umgebung.sitzungsdauerTage * 86_400_000);
        db.prepare(
            `INSERT INTO sitzungen (marke_hash, benutzer_id, erstellt_am, laeuft_ab_am) VALUES (?, ?, ?, ?)`,
        ).run(markenHash(marke), benutzerId, new Date().toISOString(), ablauf.toISOString());
        reply.setCookie(SITZUNGSKEKS, marke, {
            path: "/",
            httpOnly: true,
            sameSite: "lax",
            secure: !umgebung.entwicklung,
            expires: ablauf,
        });
    }

    // --- Mandanten und Preise --------------------------------------------

    function mandantVon(organisationId: string, id: string) {
        return db
            .prepare(`SELECT * FROM mandanten WHERE id = ? AND organisation_id = ?`)
            .get(id, organisationId) as
            | { id: string; name: string; notiz: string; erstellt_am: string }
            | undefined;
    }

    function preisFuer(mandantId: string) {
        const eigene = db
            .prepare(`SELECT sku, cent FROM preise WHERE mandant_id = ?`)
            .all(mandantId) as { sku: string; cent: number }[];
        return preisliste(Object.fromEntries(eigene.map((p) => [p.sku, p.cent])));
    }

    /** Befunde der jüngsten Auswertung, angereichert um den Bearbeitungsstand. */
    function befundeMitStand(mandantId: string, auswertungId: string) {
        return db
            .prepare(
                `SELECT b.*, COALESCE(s.status, 'offen') AS status, COALESCE(s.notiz, '') AS stand_notiz,
                        s.geaendert_am AS stand_geaendert_am
                 FROM befunde b
                 LEFT JOIN befund_stand s
                        ON s.mandant_id = b.mandant_id AND s.schluessel = b.schluessel
                 WHERE b.auswertung_id = ? AND b.mandant_id = ?
                 ORDER BY b.ersparnis_cent DESC`,
            )
            .all(auswertungId, mandantId) as Record<string, unknown>[];
    }

    function juengsteAuswertung(mandantId: string) {
        return db
            .prepare(
                `SELECT * FROM auswertungen WHERE mandant_id = ? ORDER BY erstellt_am DESC LIMIT 1`,
            )
            .get(mandantId) as Record<string, unknown> | undefined;
    }

    function speichereAuswertung(
        mandantId: string,
        benutzerId: string,
        ergebnis: Auswertung,
        warnungen: string[],
        quelle: string,
    ): string {
        const id = crypto.randomUUID();
        const jetzt = new Date().toISOString();
        const einfuegen = db.prepare(
            `INSERT INTO befunde (id, auswertung_id, mandant_id, schluessel, art, sicherheit, titel,
                                  begruendung, empfehlung, upn, anzeigename, sku, ziel_sku, anzahl, ersparnis_cent)
             VALUES (@id, @auswertungId, @mandantId, @schluessel, @art, @sicherheit, @titel,
                     @begruendung, @empfehlung, @upn, @anzeigename, @sku, @zielSku, @anzahl, @ersparnisCent)`,
        );
        db.transaction(() => {
            db.prepare(
                `INSERT INTO auswertungen (id, mandant_id, stichtag, erstellt_am, erstellt_von, quelle,
                                           anzahl_konten, anzahl_zuweisungen, lizenzkosten_cent,
                                           ersparnis_cent, ersparnis_sicher_cent, ersparnis_pruefen_cent, warnungen)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            ).run(
                id,
                mandantId,
                ergebnis.stichtag,
                jetzt,
                benutzerId,
                quelle,
                ergebnis.anzahlKonten,
                ergebnis.anzahlZuweisungen,
                ergebnis.lizenzkostenCentMonat,
                ergebnis.ersparnisCentMonat,
                ergebnis.ersparnisSicherCentMonat,
                ergebnis.ersparnisPruefenCentMonat,
                JSON.stringify(warnungen),
            );
            for (const befund of ergebnis.befunde) {
                einfuegen.run({
                    id: crypto.randomUUID(),
                    auswertungId: id,
                    mandantId,
                    schluessel: befund.id,
                    art: befund.art,
                    sicherheit: befund.sicherheit,
                    titel: befund.titel,
                    begruendung: befund.begruendung,
                    empfehlung: befund.empfehlung,
                    upn: befund.upn,
                    anzeigename: befund.anzeigename,
                    sku: befund.sku,
                    zielSku: befund.zielSku,
                    anzahl: befund.anzahl,
                    ersparnisCent: befund.ersparnisCentMonat,
                });
            }
        })();
        return id;
    }

    // --- Konto anlegen und anmelden --------------------------------------

    app.post("/api/registrierung", { config: { rateLimit: { max: 10, timeWindow: "10 minutes" } } },
        async (request, reply) => {
        const ergebnis = registrierungSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const daten = ergebnis.data;
        if (db.prepare(`SELECT id FROM benutzer WHERE email = ? COLLATE NOCASE`).get(daten.email)) {
            return reply
                .code(409)
                .send({ fehler: "Für diese Adresse gibt es bereits ein Konto", felder: { email: "Bereits vergeben" } });
        }
        const jetzt = new Date().toISOString();
        const organisationId = crypto.randomUUID();
        const benutzerId = crypto.randomUUID();
        const mandantId = crypto.randomUUID();
        const hash = await hashe(daten.kennwort);
        db.transaction(() => {
            db.prepare(`INSERT INTO organisationen (id, name, erstellt_am) VALUES (?, ?, ?)`).run(
                organisationId, daten.organisation, jetzt,
            );
            db.prepare(
                `INSERT INTO benutzer (id, organisation_id, name, email, kennwort_hash, rolle, erstellt_am)
                 VALUES (?, ?, ?, ?, ?, 'inhaber', ?)`,
            ).run(benutzerId, organisationId, daten.name, daten.email, hash, jetzt);
            // Ein erster Mandant, damit niemand vor einer leeren Seite steht.
            db.prepare(
                `INSERT INTO mandanten (id, organisation_id, name, erstellt_am) VALUES (?, ?, ?, ?)`,
            ).run(mandantId, organisationId, daten.organisation, jetzt);
        })();
        protokolliere(db, {
            organisationId, benutzerId, aktion: "registrierung",
            beschreibung: `${daten.name} hat ${daten.organisation} angelegt`,
        });
        setzeSitzung(reply, benutzerId);
        return reply.code(201).send({ organisation: daten.organisation, mandantId });
    });

    app.post("/api/anmeldung", { config: { rateLimit: { max: 20, timeWindow: "10 minutes" } } },
        async (request, reply) => {
        const ergebnis = anmeldungSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const zeile = db
            .prepare(`SELECT id, kennwort_hash FROM benutzer WHERE email = ? COLLATE NOCASE`)
            .get(ergebnis.data.email) as { id: string; kennwort_hash: string } | undefined;
        // Auch ohne Treffer wird gehasht, damit die Antwortzeit nicht verrät,
        // ob es die Adresse gibt.
        const hash = zeile?.kennwort_hash ?? "scrypt$16384$8$1$AAAAAAAAAAAAAAAAAAAAAA==$AAAA";
        const passt = await stimmt(ergebnis.data.kennwort, hash);
        if (!zeile || !passt) {
            return reply.code(401).send({ fehler: "E-Mail-Adresse oder Kennwort stimmt nicht" });
        }
        setzeSitzung(reply, zeile.id);
        return { angemeldet: true };
    });

    app.post("/api/abmeldung", async (request, reply) => {
        const marke = request.cookies[SITZUNGSKEKS];
        if (marke) db.prepare(`DELETE FROM sitzungen WHERE marke_hash = ?`).run(markenHash(marke));
        reply.clearCookie(SITZUNGSKEKS, { path: "/" });
        return { abgemeldet: true };
    });

    app.get("/api/ich", async (request, reply) => {
        const sitzung = ladeSitzung(request);
        if (!sitzung) return reply.code(401).send({ fehler: "Nicht angemeldet" });
        return {
            benutzer: {
                id: sitzung.benutzerId, name: sitzung.name, email: sitzung.email, rolle: sitzung.rolle,
            },
            organisation: { id: sitzung.organisationId, name: sitzung.organisationName },
            heute: heuteGeben(),
        };
    });

    app.post("/api/benutzer", { preHandler: verlangeInhaber }, async (request, reply) => {
        const { organisationId, benutzerId, name } = request.angemeldet!;
        const ergebnis = einladungSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const daten = ergebnis.data;
        if (db.prepare(`SELECT id FROM benutzer WHERE email = ? COLLATE NOCASE`).get(daten.email)) {
            return reply.code(409).send({ fehler: "Diese Adresse hat bereits ein Konto", felder: { email: "Bereits vergeben" } });
        }
        const id = crypto.randomUUID();
        db.prepare(
            `INSERT INTO benutzer (id, organisation_id, name, email, kennwort_hash, rolle, erstellt_am)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
        ).run(id, organisationId, daten.name, daten.email, await hashe(daten.kennwort), daten.rolle, new Date().toISOString());
        protokolliere(db, {
            organisationId, benutzerId, aktion: "benutzer_angelegt",
            beschreibung: `${name} hat ${daten.name} (${daten.rolle}) angelegt`,
        });
        return reply.code(201).send({ id });
    });

    app.get("/api/benutzer", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisationId } = request.angemeldet!;
        return {
            benutzer: db
                .prepare(
                    `SELECT id, name, email, rolle, erstellt_am FROM benutzer
                     WHERE organisation_id = ? ORDER BY erstellt_am`,
                )
                .all(organisationId),
        };
    });

    // --- Mandanten --------------------------------------------------------

    app.get("/api/mandanten", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisationId } = request.angemeldet!;
        const mandanten = db
            .prepare(
                `SELECT m.*,
                        (SELECT a.erstellt_am FROM auswertungen a WHERE a.mandant_id = m.id
                          ORDER BY a.erstellt_am DESC LIMIT 1) AS letzte_auswertung,
                        (SELECT a.ersparnis_cent FROM auswertungen a WHERE a.mandant_id = m.id
                          ORDER BY a.erstellt_am DESC LIMIT 1) AS ersparnis_cent,
                        (SELECT a.lizenzkosten_cent FROM auswertungen a WHERE a.mandant_id = m.id
                          ORDER BY a.erstellt_am DESC LIMIT 1) AS lizenzkosten_cent
                 FROM mandanten m WHERE m.organisation_id = ? ORDER BY m.name`,
            )
            .all(organisationId);
        return { mandanten };
    });

    app.post("/api/mandanten", { preHandler: verlangeInhaber }, async (request, reply) => {
        const { organisationId, benutzerId, name } = request.angemeldet!;
        const ergebnis = mandantSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const id = crypto.randomUUID();
        db.prepare(
            `INSERT INTO mandanten (id, organisation_id, name, notiz, erstellt_am) VALUES (?, ?, ?, ?, ?)`,
        ).run(id, organisationId, ergebnis.data.name, ergebnis.data.notiz, new Date().toISOString());
        protokolliere(db, {
            organisationId, mandantId: id, benutzerId, aktion: "mandant_angelegt",
            beschreibung: `${name} hat den Mandanten „${ergebnis.data.name}“ angelegt`,
        });
        return reply.code(201).send({ id });
    });

    app.delete("/api/mandanten/:id", { preHandler: verlangeInhaber }, async (request, reply) => {
        const { organisationId, benutzerId, name } = request.angemeldet!;
        const id = (request.params as { id: string }).id;
        const mandant = mandantVon(organisationId, id);
        if (!mandant) return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        db.prepare(`DELETE FROM mandanten WHERE id = ? AND organisation_id = ?`).run(id, organisationId);
        protokolliere(db, {
            organisationId, benutzerId, aktion: "mandant_geloescht",
            beschreibung: `${name} hat den Mandanten „${mandant.name}“ samt Auswertungen gelöscht`,
        });
        return { geloescht: true };
    });

    // --- Auswertung -------------------------------------------------------

    app.post("/api/mandanten/:id/auswertung", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisationId, benutzerId, name } = request.angemeldet!;
        const mandantId = (request.params as { id: string }).id;
        const mandant = mandantVon(organisationId, mandantId);
        if (!mandant) return reply.code(404).send({ fehler: "Mandant nicht gefunden" });

        const dateien: Quelldatei[] = [];
        try {
            for await (const teil of request.parts()) {
                if (teil.type !== "file") continue;
                const inhalt = (await teil.toBuffer()).toString("utf8");
                dateien.push({ name: teil.filename || "ausgabe.csv", inhalt });
            }
        } catch (fehler) {
            request.log.warn({ fehler }, "Ausgabe konnte nicht gelesen werden");
            return reply.code(413).send({
                fehler: `Die Datei ist zu groß. Erlaubt sind ${umgebung.maxDateigroesseMb} MB je Datei.`,
            });
        }
        if (dateien.length === 0) {
            return reply.code(400).send({ fehler: "Es wurde keine Datei übermittelt" });
        }

        const stichtag = heuteGeben();
        const { bestand, warnungen, dateien: uebersicht } = baueBestand(dateien, stichtag);
        if (bestand.konten.length === 0) {
            return reply.code(422).send({
                fehler: "In den Dateien standen keine Konten. Bitte die Benutzerliste aus dem Adminportal mitgeben.",
                warnungen,
                dateien: uebersicht,
            });
        }
        const ergebnis = werteAus(bestand, preisFuer(mandantId));
        const auswertungId = speichereAuswertung(mandantId, benutzerId, ergebnis, warnungen, "csv");
        protokolliere(db, {
            organisationId, mandantId, benutzerId, aktion: "auswertung",
            beschreibung:
                `${name} hat ${bestand.konten.length} Konten ausgewertet — ` +
                `${(ergebnis.ersparnisCentMonat / 100).toFixed(2)} € je Monat gefunden`,
        });
        return reply.code(201).send({ auswertungId, warnungen, dateien: uebersicht });
    });

    app.get("/api/mandanten/:id/uebersicht", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisationId } = request.angemeldet!;
        const mandantId = (request.params as { id: string }).id;
        const mandant = mandantVon(organisationId, mandantId);
        if (!mandant) return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        const auswertung = juengsteAuswertung(mandantId);
        if (!auswertung) return { mandant, auswertung: null, befunde: [], verlauf: [] };

        const befunde = befundeMitStand(mandantId, auswertung["id"] as string);
        const offen = befunde.filter((b) => b["status"] === "offen");
        const erledigt = befunde.filter((b) => b["status"] === "erledigt");
        return {
            mandant,
            auswertung: { ...auswertung, warnungen: JSON.parse(String(auswertung["warnungen"] ?? "[]")) },
            befunde,
            kennzahlen: {
                offenCent: offen.reduce((wert, b) => wert + Number(b["ersparnis_cent"]), 0),
                offenSicherCent: offen
                    .filter((b) => b["sicherheit"] === "sicher")
                    .reduce((wert, b) => wert + Number(b["ersparnis_cent"]), 0),
                erledigtCent: erledigt.reduce((wert, b) => wert + Number(b["ersparnis_cent"]), 0),
                anzahlOffen: offen.length,
                anzahlErledigt: erledigt.length,
            },
            verlauf: db
                .prepare(
                    `SELECT id, stichtag, erstellt_am, ersparnis_cent, ersparnis_sicher_cent,
                            lizenzkosten_cent, anzahl_konten
                     FROM auswertungen WHERE mandant_id = ? ORDER BY erstellt_am DESC LIMIT 12`,
                )
                .all(mandantId),
        };
    });

    app.post("/api/mandanten/:id/befunde/:schluessel/stand", { preHandler: verlangeAnmeldung },
        async (request, reply) => {
        const { organisationId, benutzerId, name } = request.angemeldet!;
        const { id: mandantId, schluessel: befundschluessel } = request.params as {
            id: string; schluessel: string;
        };
        if (!mandantVon(organisationId, mandantId)) {
            return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        }
        const ergebnis = standSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const bekannt = db
            .prepare(`SELECT titel FROM befunde WHERE mandant_id = ? AND schluessel = ? LIMIT 1`)
            .get(mandantId, befundschluessel) as { titel: string } | undefined;
        if (!bekannt) return reply.code(404).send({ fehler: "Befund nicht gefunden" });

        db.prepare(
            `INSERT INTO befund_stand (mandant_id, schluessel, status, notiz, geaendert_am, geaendert_von)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT (mandant_id, schluessel)
             DO UPDATE SET status = excluded.status, notiz = excluded.notiz,
                           geaendert_am = excluded.geaendert_am, geaendert_von = excluded.geaendert_von`,
        ).run(
            mandantId, befundschluessel, ergebnis.data.status, ergebnis.data.notiz,
            new Date().toISOString(), benutzerId,
        );
        protokolliere(db, {
            organisationId, mandantId, benutzerId, aktion: `befund_${ergebnis.data.status}`,
            beschreibung: `${name}: „${bekannt.titel}“ → ${ergebnis.data.status}`,
        });
        return { status: ergebnis.data.status as Befundstatus };
    });

    // --- Preise -----------------------------------------------------------

    app.get("/api/mandanten/:id/preise", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisationId } = request.angemeldet!;
        const mandantId = (request.params as { id: string }).id;
        if (!mandantVon(organisationId, mandantId)) {
            return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        }
        const eigene = new Map(
            (db.prepare(`SELECT sku, cent FROM preise WHERE mandant_id = ?`).all(mandantId) as {
                sku: string; cent: number;
            }[]).map((p) => [p.sku, p.cent]),
        );
        // Nur Produkte, die im Bestand vorkommen, plus alle Katalogeinträge.
        const verwendet = db
            .prepare(
                `SELECT DISTINCT sku FROM befunde WHERE mandant_id = ? AND sku IS NOT NULL`,
            )
            .all(mandantId) as { sku: string }[];
        const kennungen = new Set([...SKUS.map((s) => s.id), ...verwendet.map((v) => v.sku)]);
        return {
            preise: [...kennungen].map((id) => ({
                sku: id,
                name: skuName(id),
                katalogCent: preisliste()(id),
                eigenCent: eigene.get(id) ?? null,
            })),
        };
    });

    app.put("/api/mandanten/:id/preise", { preHandler: verlangeInhaber }, async (request, reply) => {
        const { organisationId, benutzerId, name } = request.angemeldet!;
        const mandantId = (request.params as { id: string }).id;
        if (!mandantVon(organisationId, mandantId)) {
            return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        }
        const ergebnis = preiseSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        db.transaction(() => {
            db.prepare(`DELETE FROM preise WHERE mandant_id = ?`).run(mandantId);
            const einfuegen = db.prepare(
                `INSERT INTO preise (mandant_id, sku, cent) VALUES (?, ?, ?)`,
            );
            for (const preis of ergebnis.data.preise) einfuegen.run(mandantId, preis.sku, preis.cent);
        })();
        protokolliere(db, {
            organisationId, mandantId, benutzerId, aktion: "preise",
            beschreibung: `${name} hat ${ergebnis.data.preise.length} eigene Preise hinterlegt`,
        });
        return { gespeichert: ergebnis.data.preise.length };
    });

    // --- Beispieldaten und Ausgaben ---------------------------------------

    app.post("/api/mandanten/:id/demodaten", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisationId, benutzerId } = request.angemeldet!;
        const mandantId = (request.params as { id: string }).id;
        if (!mandantVon(organisationId, mandantId)) {
            return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        }
        const stichtag = heuteGeben();
        const { bestand, warnungen } = baueBestand(beispielausgaben(stichtag), stichtag);
        const ergebnis = werteAus(bestand, preisFuer(mandantId));
        const auswertungId = speichereAuswertung(mandantId, benutzerId, ergebnis, warnungen, "demo");
        return reply.code(201).send({ auswertungId, konten: bestand.konten.length });
    });

    app.get("/api/mandanten/:id/export.csv", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisationId } = request.angemeldet!;
        const mandantId = (request.params as { id: string }).id;
        const mandant = mandantVon(organisationId, mandantId);
        if (!mandant) return reply.code(404).send({ fehler: "Mandant nicht gefunden" });
        const auswertung = juengsteAuswertung(mandantId);
        if (!auswertung) return reply.code(404).send({ fehler: "Noch keine Auswertung vorhanden" });

        const befunde = befundeMitStand(mandantId, auswertung["id"] as string);
        const spalten = [
            "Befund", "Sicherheit", "Status", "Konto", "Anmeldename", "Produkt", "Zielprodukt",
            "Anzahl", "Ersparnis je Monat", "Ersparnis je Jahr", "Begründung", "Empfehlung",
        ];
        const feld = (wert: unknown) => {
            const text = wert === null || wert === undefined ? "" : String(wert);
            return /[";\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
        };
        const betrag = (cent: number) => (cent / 100).toFixed(2).replace(".", ",");
        const zeilen = [spalten.join(";")];
        for (const b of befunde) {
            const cent = Number(b["ersparnis_cent"]);
            zeilen.push(
                [
                    b["titel"], b["sicherheit"], b["status"], b["anzeigename"], b["upn"],
                    b["sku"] ? skuName(String(b["sku"])) : "",
                    b["ziel_sku"] ? skuName(String(b["ziel_sku"])) : "",
                    b["anzahl"], betrag(cent), betrag(cent * 12),
                    String(b["begruendung"]).replace(/\r?\n/g, " "),
                    String(b["empfehlung"]).replace(/\r?\n/g, " "),
                ].map(feld).join(";"),
            );
        }
        return reply
            .header("content-type", "text/csv; charset=utf-8")
            .header("content-disposition", `attachment; filename="lizenzbefunde-${auswertung["stichtag"]}.csv"`)
            .send("﻿" + zeilen.join("\r\n") + "\r\n");
    });

    app.get("/api/verlauf", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisationId } = request.angemeldet!;
        return {
            verlauf: db
                .prepare(
                    `SELECT v.*, b.name AS benutzer_name FROM verlauf v
                     LEFT JOIN benutzer b ON b.id = v.benutzer_id
                     WHERE v.organisation_id = ? ORDER BY v.zeitpunkt DESC LIMIT 100`,
                )
                .all(organisationId),
        };
    });

    app.get("/api/gesundheit", async () => ({ zustand: "läuft", heute: heuteGeben() }));

    // --- Oberfläche ausliefern -------------------------------------------

    const hier = dirname(fileURLToPath(import.meta.url));
    const webOrdner = [resolve(hier, "../../bau/web"), resolve(hier, "../../../bau/web")].find(
        (pfad) => existsSync(join(pfad, "index.html")),
    );
    if (webOrdner) {
        app.register(statisch, { root: webOrdner });
        app.setNotFoundHandler((request, reply) => {
            if (request.url.startsWith("/api/")) return reply.code(404).send({ fehler: "Unbekannter Aufruf" });
            return reply.sendFile("index.html");
        });
    }

    return app;
}

export { oeffneDatenbank };
