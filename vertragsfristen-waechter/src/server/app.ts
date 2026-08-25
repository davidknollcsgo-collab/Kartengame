// HTTP-Schnittstelle. Alle Antworten sind JSON, alle Fehler haben die Form
// { fehler: "Klartext", felder?: { feldname: "Meldung" } }.

import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import cookie from "@fastify/cookie";
import statisch from "@fastify/static";
import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from "fastify";
import { heute, istVor } from "../fachlogik/datum.ts";
import { bewerteVertrag, type Ampel } from "../fachlogik/fristen.ts";
import { jahreskostenCent } from "../fachlogik/formate.ts";
import type { Benutzer, Organisation, Vertrag } from "../fachlogik/typen.ts";
import { baueCsv } from "./csv.ts";
import {
    neuerKalenderschluessel,
    protokolliere,
    zuBenutzer,
    zuOrganisation,
    zuVertrag,
    type BenutzerZeile,
    type Db,
    type OrganisationZeile,
    type VertragZeile,
} from "./datenbank.ts";
import { planeErinnerungen } from "./erinnerungen.ts";
import { baueKalender } from "./kalender.ts";
import { hashe, markenHash, stimmt } from "./kennwort.ts";
import {
    anmeldungSchema,
    felderfehler,
    kuendigungSchema,
    organisationSchema,
    registrierungSchema,
    vertragSchema,
} from "./pruefung.ts";
import { schluessel, type Umgebung } from "./umgebung.ts";
import { setzeDemodaten } from "./demodaten.ts";

const SITZUNGSKEKS = "waechter_sitzung";

export interface AppOptionen {
    db: Db;
    umgebung: Umgebung;
    /** Überschreibbar für Tests. */
    heuteGeben?: () => string;
    protokoll?: boolean;
}

interface Angemeldet {
    benutzer: Benutzer;
    organisation: Organisation;
}

declare module "fastify" {
    interface FastifyRequest {
        angemeldet?: Angemeldet;
    }
}

export function baueApp(optionen: AppOptionen): FastifyInstance {
    const { db, umgebung } = optionen;
    const heuteGeben = optionen.heuteGeben ?? (() => heute());
    const app = Fastify({ logger: optionen.protokoll ?? false });

    app.register(cookie);

    // --- Hilfsfunktionen --------------------------------------------------

    function ladeSitzung(request: FastifyRequest): Angemeldet | null {
        const marke = request.cookies[SITZUNGSKEKS];
        if (!marke) return null;
        const zeile = db
            .prepare(
                `SELECT b.* FROM sitzungen s
                 JOIN benutzer b ON b.id = s.benutzer_id
                 WHERE s.marke_hash = ? AND s.laeuft_ab_am > ?`,
            )
            .get(markenHash(marke), new Date().toISOString()) as BenutzerZeile | undefined;
        if (!zeile) return null;
        const organisation = db
            .prepare(`SELECT * FROM organisationen WHERE id = ?`)
            .get(zeile.organisation_id) as OrganisationZeile | undefined;
        if (!organisation) return null;
        return { benutzer: zuBenutzer(zeile), organisation: zuOrganisation(organisation) };
    }

    async function verlangeAnmeldung(request: FastifyRequest, reply: FastifyReply): Promise<void> {
        const sitzung = ladeSitzung(request);
        if (!sitzung) {
            reply.code(401).send({ fehler: "Bitte zuerst anmelden" });
            return;
        }
        request.angemeldet = sitzung;
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

    function ladeVertrag(organisationId: string, id: string): Vertrag | null {
        const zeile = db
            .prepare(`SELECT * FROM vertraege WHERE id = ? AND organisation_id = ?`)
            .get(id, organisationId) as VertragZeile | undefined;
        return zeile ? zuVertrag(zeile) : null;
    }

    function ladeVertraege(organisationId: string): Vertrag[] {
        return (
            db
                .prepare(`SELECT * FROM vertraege WHERE organisation_id = ? ORDER BY bezeichnung`)
                .all(organisationId) as VertragZeile[]
        ).map(zuVertrag);
    }

    /** Vertrag samt berechneter Fristen — die Form, die die Oberfläche erwartet. */
    function mitFristen(vertrag: Vertrag, basis: string) {
        const { fristen, ampel } = bewerteVertrag(vertrag, basis);
        return {
            ...vertrag,
            fristen,
            ampel,
            jahreskostenCent: jahreskostenCent(vertrag.betragCent, vertrag.zahlungsintervall),
        };
    }

    // --- Anmeldung --------------------------------------------------------

    app.post("/api/registrierung", async (request, reply) => {
        const ergebnis = registrierungSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const daten = ergebnis.data;
        const vorhanden = db
            .prepare(`SELECT id FROM benutzer WHERE email = ? COLLATE NOCASE`)
            .get(daten.email);
        if (vorhanden) {
            return reply
                .code(409)
                .send({ fehler: "Für diese Adresse gibt es bereits ein Konto", felder: { email: "Bereits vergeben" } });
        }
        const jetzt = new Date().toISOString();
        const organisationId = crypto.randomUUID();
        const benutzerId = crypto.randomUUID();
        db.prepare(
            `INSERT INTO organisationen (id, name, kalender_schluessel, erstellt_am) VALUES (?, ?, ?, ?)`,
        ).run(organisationId, daten.organisation, neuerKalenderschluessel(), jetzt);
        db.prepare(
            `INSERT INTO benutzer (id, organisation_id, name, email, kennwort_hash, rolle, erstellt_am)
             VALUES (?, ?, ?, ?, ?, 'inhaber', ?)`,
        ).run(benutzerId, organisationId, daten.name, daten.email, await hashe(daten.kennwort), jetzt);
        protokolliere(db, {
            organisationId,
            benutzerId,
            aktion: "registrierung",
            beschreibung: `${daten.name} hat ${daten.organisation} angelegt`,
        });
        setzeSitzung(reply, benutzerId);
        return reply.code(201).send({ organisation: daten.organisation });
    });

    app.post("/api/anmeldung", async (request, reply) => {
        const ergebnis = anmeldungSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Eingaben unvollständig", felder: felderfehler(ergebnis.error) });
        }
        const zeile = db
            .prepare(`SELECT * FROM benutzer WHERE email = ? COLLATE NOCASE`)
            .get(ergebnis.data.email) as BenutzerZeile | undefined;
        // Auch ohne Treffer wird gehasht, damit die Antwortzeit nichts verrät.
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
            benutzer: sitzung.benutzer,
            organisation: sitzung.organisation,
            heute: heuteGeben(),
            kalenderAdresse: `${umgebung.basisAdresse}/kalender/${sitzung.organisation.kalenderSchluessel}.ics`,
        };
    });

    // --- Verträge ---------------------------------------------------------

    app.get("/api/vertraege", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisation } = request.angemeldet!;
        const basis = heuteGeben();
        const abfrage = request.query as Record<string, string | undefined>;
        const suche = (abfrage.suche ?? "").trim().toLowerCase();

        let liste = ladeVertraege(organisation.id).map((v) => mitFristen(v, basis));
        if (abfrage.kategorie) liste = liste.filter((v) => v.kategorie === abfrage.kategorie);
        if (abfrage.status) liste = liste.filter((v) => v.status === abfrage.status);
        if (abfrage.ampel) liste = liste.filter((v) => v.ampel === abfrage.ampel);
        if (suche) {
            liste = liste.filter((v) =>
                [v.bezeichnung, v.anbieter, v.vertragsnummer, v.abteilung, v.notizen]
                    .join(" ")
                    .toLowerCase()
                    .includes(suche),
            );
        }
        liste.sort((a, b) => {
            const av = a.fristen.stichtag;
            const bv = b.fristen.stichtag;
            if (av && bv) return av.localeCompare(bv) || a.bezeichnung.localeCompare(b.bezeichnung);
            if (av) return -1;
            if (bv) return 1;
            return a.bezeichnung.localeCompare(b.bezeichnung);
        });
        return { vertraege: liste, heute: basis };
    });

    app.get("/api/vertraege/:id", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation } = request.angemeldet!;
        const vertrag = ladeVertrag(organisation.id, (request.params as { id: string }).id);
        if (!vertrag) return reply.code(404).send({ fehler: "Vertrag nicht gefunden" });
        const verlauf = db
            .prepare(`SELECT * FROM verlauf WHERE vertrag_id = ? ORDER BY zeitpunkt DESC LIMIT 50`)
            .all(vertrag.id);
        const erinnerungen = db
            .prepare(`SELECT * FROM erinnerungen WHERE vertrag_id = ? ORDER BY faellig_am DESC LIMIT 50`)
            .all(vertrag.id);
        return { vertrag: mitFristen(vertrag, heuteGeben()), verlauf, erinnerungen };
    });

    app.post("/api/vertraege", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation, benutzer } = request.angemeldet!;
        const ergebnis = vertragSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Bitte Eingaben prüfen", felder: felderfehler(ergebnis.error) });
        }
        const daten = ergebnis.data;
        const id = crypto.randomUUID();
        const jetzt = new Date().toISOString();
        db.prepare(
            `INSERT INTO vertraege (
                id, organisation_id, bezeichnung, anbieter, kategorie, vertragsnummer, abteilung,
                ansprechpartner, beginn, laufzeitmodell, erstlaufzeit_monate, verlaengerung_monate,
                kuendigungsfrist_wert, kuendigungsfrist_einheit, kuendigungsfrist_bezug, betrag_cent,
                zahlungsintervall, status, gekuendigt_zum, dokument_link, notizen, erstellt_am, geaendert_am
             ) VALUES (
                @id, @organisationId, @bezeichnung, @anbieter, @kategorie, @vertragsnummer, @abteilung,
                @ansprechpartner, @beginn, @laufzeitmodell, @erstlaufzeitMonate, @verlaengerungMonate,
                @kuendigungsfristWert, @kuendigungsfristEinheit, @kuendigungsfristBezug, @betragCent,
                @zahlungsintervall, @status, @gekuendigtZum, @dokumentLink, @notizen, @jetzt, @jetzt
             )`,
        ).run({ ...daten, id, organisationId: organisation.id, jetzt });
        protokolliere(db, {
            organisationId: organisation.id,
            vertragId: id,
            benutzerId: benutzer.id,
            aktion: "angelegt",
            beschreibung: `${benutzer.name} hat „${daten.bezeichnung}“ angelegt`,
        });
        const vertrag = ladeVertrag(organisation.id, id)!;
        return reply.code(201).send({ vertrag: mitFristen(vertrag, heuteGeben()) });
    });

    app.put("/api/vertraege/:id", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation, benutzer } = request.angemeldet!;
        const id = (request.params as { id: string }).id;
        const vorher = ladeVertrag(organisation.id, id);
        if (!vorher) return reply.code(404).send({ fehler: "Vertrag nicht gefunden" });
        const ergebnis = vertragSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Bitte Eingaben prüfen", felder: felderfehler(ergebnis.error) });
        }
        const daten = ergebnis.data;
        db.prepare(
            `UPDATE vertraege SET
                bezeichnung = @bezeichnung, anbieter = @anbieter, kategorie = @kategorie,
                vertragsnummer = @vertragsnummer, abteilung = @abteilung, ansprechpartner = @ansprechpartner,
                beginn = @beginn, laufzeitmodell = @laufzeitmodell, erstlaufzeit_monate = @erstlaufzeitMonate,
                verlaengerung_monate = @verlaengerungMonate, kuendigungsfrist_wert = @kuendigungsfristWert,
                kuendigungsfrist_einheit = @kuendigungsfristEinheit, kuendigungsfrist_bezug = @kuendigungsfristBezug,
                betrag_cent = @betragCent, zahlungsintervall = @zahlungsintervall, status = @status,
                gekuendigt_zum = @gekuendigtZum, dokument_link = @dokumentLink, notizen = @notizen,
                geaendert_am = @jetzt
             WHERE id = @id AND organisation_id = @organisationId`,
        ).run({ ...daten, id, organisationId: organisation.id, jetzt: new Date().toISOString() });
        protokolliere(db, {
            organisationId: organisation.id,
            vertragId: id,
            benutzerId: benutzer.id,
            aktion: "geaendert",
            beschreibung: `${benutzer.name} hat „${daten.bezeichnung}“ bearbeitet`,
        });
        return { vertrag: mitFristen(ladeVertrag(organisation.id, id)!, heuteGeben()) };
    });

    app.delete("/api/vertraege/:id", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation, benutzer } = request.angemeldet!;
        const id = (request.params as { id: string }).id;
        const vertrag = ladeVertrag(organisation.id, id);
        if (!vertrag) return reply.code(404).send({ fehler: "Vertrag nicht gefunden" });
        db.prepare(`DELETE FROM vertraege WHERE id = ? AND organisation_id = ?`).run(id, organisation.id);
        protokolliere(db, {
            organisationId: organisation.id,
            benutzerId: benutzer.id,
            aktion: "geloescht",
            beschreibung: `${benutzer.name} hat „${vertrag.bezeichnung}“ gelöscht`,
        });
        return { geloescht: true };
    });

    app.post("/api/vertraege/:id/kuendigung", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation, benutzer } = request.angemeldet!;
        const id = (request.params as { id: string }).id;
        const vertrag = ladeVertrag(organisation.id, id);
        if (!vertrag) return reply.code(404).send({ fehler: "Vertrag nicht gefunden" });
        const ergebnis = kuendigungSchema.safeParse(request.body ?? {});
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Bitte Eingaben prüfen", felder: felderfehler(ergebnis.error) });
        }
        const basis = heuteGeben();
        const { fristen } = bewerteVertrag(vertrag, basis);
        const ende = ergebnis.data.gekuendigtZum ?? fristen.wirksamesVertragsende ?? basis;
        const status = istVor(ende, basis) ? "beendet" : "gekuendigt";
        const notiz = ergebnis.data.notiz
            ? `${vertrag.notizen}\n[${basis}] Kündigung: ${ergebnis.data.notiz}`.trim()
            : vertrag.notizen;
        db.prepare(
            `UPDATE vertraege SET status = ?, gekuendigt_zum = ?, notizen = ?, geaendert_am = ?
             WHERE id = ? AND organisation_id = ?`,
        ).run(status, ende, notiz, new Date().toISOString(), id, organisation.id);
        db.prepare(`UPDATE erinnerungen SET erledigt_am = ? WHERE vertrag_id = ? AND erledigt_am IS NULL`).run(
            new Date().toISOString(),
            id,
        );
        protokolliere(db, {
            organisationId: organisation.id,
            vertragId: id,
            benutzerId: benutzer.id,
            aktion: "gekuendigt",
            beschreibung: `${benutzer.name} hat „${vertrag.bezeichnung}“ zum ${ende} gekündigt`,
        });
        return { vertrag: mitFristen(ladeVertrag(organisation.id, id)!, basis) };
    });

    app.post("/api/vertraege/:id/reaktivierung", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation, benutzer } = request.angemeldet!;
        const id = (request.params as { id: string }).id;
        const vertrag = ladeVertrag(organisation.id, id);
        if (!vertrag) return reply.code(404).send({ fehler: "Vertrag nicht gefunden" });
        db.prepare(
            `UPDATE vertraege SET status = 'aktiv', gekuendigt_zum = NULL, geaendert_am = ?
             WHERE id = ? AND organisation_id = ?`,
        ).run(new Date().toISOString(), id, organisation.id);
        protokolliere(db, {
            organisationId: organisation.id,
            vertragId: id,
            benutzerId: benutzer.id,
            aktion: "reaktiviert",
            beschreibung: `${benutzer.name} hat die Kündigung von „${vertrag.bezeichnung}“ zurückgenommen`,
        });
        return { vertrag: mitFristen(ladeVertrag(organisation.id, id)!, heuteGeben()) };
    });

    // --- Übersicht --------------------------------------------------------

    app.get("/api/uebersicht", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisation } = request.angemeldet!;
        const basis = heuteGeben();
        const alle = ladeVertraege(organisation.id).map((v) => mitFristen(v, basis));
        const aktive = alle.filter((v) => v.status === "aktiv");

        const nachAmpel: Record<Ampel, number> = {
            kritisch: 0, warnung: 0, hinweis: 0, ok: 0, jederzeit: 0, gekuendigt: 0, beendet: 0,
        };
        for (const vertrag of alle) nachAmpel[vertrag.ampel] += 1;

        const nachKategorie: Record<string, { anzahl: number; jahreskostenCent: number }> = {};
        for (const vertrag of aktive) {
            const eintrag = (nachKategorie[vertrag.kategorie] ??= { anzahl: 0, jahreskostenCent: 0 });
            eintrag.anzahl += 1;
            eintrag.jahreskostenCent += vertrag.jahreskostenCent;
        }

        const inTagen = (tage: number) =>
            aktive.filter(
                (v) =>
                    v.fristen.stichtag !== null &&
                    v.fristen.tageBisStichtag !== null &&
                    v.fristen.tageBisStichtag >= 0 &&
                    v.fristen.tageBisStichtag <= tage,
            ).length;

        return {
            heute: basis,
            anzahlGesamt: alle.length,
            anzahlAktiv: aktive.length,
            jahreskostenCent: aktive.reduce((summe, v) => summe + v.jahreskostenCent, 0),
            gefaehrdeteKostenCent: aktive
                .filter((v) => v.ampel === "kritisch" || v.ampel === "warnung")
                .reduce((summe, v) => summe + v.jahreskostenCent, 0),
            nachAmpel,
            nachKategorie,
            fristenIn30: inTagen(30),
            fristenIn90: inTagen(90),
            naechsteFristen: aktive
                .filter((v) => v.fristen.stichtag !== null)
                .slice(0, 8),
            offeneErinnerungen: db
                .prepare(
                    `SELECT COUNT(*) AS anzahl FROM erinnerungen
                     WHERE organisation_id = ? AND erledigt_am IS NULL`,
                )
                .get(organisation.id),
        };
    });

    // --- Erinnerungen -----------------------------------------------------

    app.get("/api/erinnerungen", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisation } = request.angemeldet!;
        const zeilen = db
            .prepare(
                `SELECT e.*, v.bezeichnung, v.anbieter, v.kategorie
                 FROM erinnerungen e JOIN vertraege v ON v.id = e.vertrag_id
                 WHERE e.organisation_id = ?
                 ORDER BY e.erledigt_am IS NOT NULL, e.faellig_am DESC
                 LIMIT 200`,
            )
            .all(organisation.id);
        return { erinnerungen: zeilen, heute: heuteGeben() };
    });

    app.post("/api/erinnerungen/:id/erledigt", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation } = request.angemeldet!;
        const id = (request.params as { id: string }).id;
        const ergebnis = db
            .prepare(`UPDATE erinnerungen SET erledigt_am = ? WHERE id = ? AND organisation_id = ?`)
            .run(new Date().toISOString(), id, organisation.id);
        if (ergebnis.changes === 0) return reply.code(404).send({ fehler: "Erinnerung nicht gefunden" });
        return { erledigt: true };
    });

    app.get("/api/postausgang", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisation } = request.angemeldet!;
        return {
            nachrichten: db
                .prepare(
                    `SELECT * FROM postausgang WHERE organisation_id = ? ORDER BY erzeugt_am DESC LIMIT 50`,
                )
                .all(organisation.id),
            smtpEingerichtet: umgebung.smtpUrl !== null,
        };
    });

    /** Stößt den Fristenlauf von Hand an — nützlich zum Ausprobieren. */
    app.post("/api/fristenlauf", { preHandler: verlangeAnmeldung }, async (request) => {
        return await planeErinnerungen(db, umgebung, heuteGeben(), app.log);
    });

    // --- Organisation -----------------------------------------------------

    app.put("/api/organisation", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation, benutzer } = request.angemeldet!;
        const ergebnis = organisationSchema.safeParse(request.body);
        if (!ergebnis.success) {
            return reply.code(400).send({ fehler: "Bitte Eingaben prüfen", felder: felderfehler(ergebnis.error) });
        }
        const daten = ergebnis.data;
        db.prepare(
            `UPDATE organisationen SET name = ?, erinnerungsvorlauf = ?, verteiler = ? WHERE id = ?`,
        ).run(
            daten.name,
            JSON.stringify(daten.erinnerungsvorlauf),
            JSON.stringify(daten.verteiler),
            organisation.id,
        );
        protokolliere(db, {
            organisationId: organisation.id,
            benutzerId: benutzer.id,
            aktion: "einstellungen",
            beschreibung: `${benutzer.name} hat die Einstellungen geändert`,
        });
        const zeile = db
            .prepare(`SELECT * FROM organisationen WHERE id = ?`)
            .get(organisation.id) as OrganisationZeile;
        return { organisation: zuOrganisation(zeile) };
    });

    app.post("/api/kalenderschluessel", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisation } = request.angemeldet!;
        const neu = neuerKalenderschluessel();
        db.prepare(`UPDATE organisationen SET kalender_schluessel = ? WHERE id = ?`).run(neu, organisation.id);
        return { kalenderAdresse: `${umgebung.basisAdresse}/kalender/${neu}.ics` };
    });

    app.post("/api/demodaten", { preHandler: verlangeAnmeldung }, async (request) => {
        const { organisation } = request.angemeldet!;
        const anzahl = setzeDemodaten(db, organisation.id, heuteGeben());
        return { angelegt: anzahl };
    });

    // --- Ausgaben ---------------------------------------------------------

    app.get("/api/export/vertraege.csv", { preHandler: verlangeAnmeldung }, async (request, reply) => {
        const { organisation } = request.angemeldet!;
        const csv = baueCsv(ladeVertraege(organisation.id), heuteGeben());
        return reply
            .header("content-type", "text/csv; charset=utf-8")
            .header("content-disposition", `attachment; filename="vertraege-${heuteGeben()}.csv"`)
            .send(csv);
    });

    /** Öffentlicher Kalender: der Schlüssel in der Adresse ist der Zugang. */
    app.get("/kalender/:schluessel.ics", async (request, reply) => {
        const kennung = (request.params as Record<string, string>)["schluessel"];
        const zeile = db
            .prepare(`SELECT * FROM organisationen WHERE kalender_schluessel = ?`)
            .get(kennung) as OrganisationZeile | undefined;
        if (!zeile) return reply.code(404).send({ fehler: "Kalender nicht gefunden" });
        const organisation = zuOrganisation(zeile);
        const vertraege = ladeVertraege(organisation.id).filter((v) => v.status === "aktiv");
        return reply
            .header("content-type", "text/calendar; charset=utf-8")
            .send(baueKalender(organisation.name, vertraege, heuteGeben(), umgebung.basisAdresse));
    });

    app.get("/api/gesundheit", async () => ({
        zustand: "läuft",
        heute: heuteGeben(),
        vertraege: (db.prepare(`SELECT COUNT(*) AS n FROM vertraege`).get() as { n: number }).n,
    }));

    // --- Oberfläche ausliefern -------------------------------------------

    const hier = dirname(fileURLToPath(import.meta.url));
    const webOrdner = [
        resolve(hier, "../../bau/web"),
        resolve(hier, "../../../bau/web"),
    ].find((pfad) => existsSync(join(pfad, "index.html")));
    if (webOrdner) {
        app.register(statisch, { root: webOrdner });
        app.setNotFoundHandler((request, reply) => {
            if (request.url.startsWith("/api/")) {
                return reply.code(404).send({ fehler: "Unbekannter Aufruf" });
            }
            return reply.sendFile("index.html");
        });
    }

    return app;
}

/** Startet den Fristenlauf beim Hochfahren und danach im eingestellten Takt. */
export function startePlaner(
    db: Db,
    umgebung: Umgebung,
    protokoll: { info(n: string): void; warn(n: string): void },
): NodeJS.Timeout {
    const lauf = () => {
        planeErinnerungen(db, umgebung, heute(), protokoll).catch((fehler: unknown) => {
            protokoll.warn(`Fristenlauf fehlgeschlagen: ${String(fehler)}`);
        });
    };
    lauf();
    const uhr = setInterval(lauf, umgebung.planerTaktMinuten * 60_000);
    uhr.unref();
    return uhr;
}
