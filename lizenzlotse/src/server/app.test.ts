import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { baueApp } from "./app.ts";
import { oeffneDatenbank, type Db } from "./datenbank.ts";
import { beispielausgaben } from "./demodaten.ts";
import { leseUmgebung, type Umgebung } from "./umgebung.ts";

const HEUTE = "2026-09-03";

let db: Db;
let app: FastifyInstance;
let umgebung: Umgebung;

beforeEach(async () => {
    db = oeffneDatenbank(":memory:");
    umgebung = leseUmgebung({});
    app = baueApp({ db, umgebung, heuteGeben: () => HEUTE });
    await app.ready();
});

afterEach(async () => {
    await app.close();
    db.close();
});

const KENNWORT = "wirklich-sicher-2026";

async function konto(email = "chefin@nordwerk.de") {
    const antwort = await app.inject({
        method: "POST",
        url: "/api/registrierung",
        payload: { organisation: "Nordwerk GmbH", name: "Anna Nord", email, kennwort: KENNWORT },
    });
    expect(antwort.statusCode).toBe(201);
    return {
        marke: antwort.cookies.find((k) => k.name === "lotse_sitzung")!.value as string,
        mandantId: antwort.json().mandantId as string,
    };
}

function als(marke: string) {
    return { lotse_sitzung: marke };
}

async function mitglied(marke: string, email = "kollege@nordwerk.de") {
    const angelegt = await app.inject({
        method: "POST",
        url: "/api/benutzer",
        cookies: als(marke),
        payload: { name: "Bert Kollege", email, kennwort: KENNWORT, rolle: "mitglied" },
    });
    expect(angelegt.statusCode).toBe(201);
    const anmeldung = await app.inject({
        method: "POST",
        url: "/api/anmeldung",
        payload: { email, kennwort: KENNWORT },
    });
    return anmeldung.cookies.find((k) => k.name === "lotse_sitzung")!.value as string;
}

function multipart(dateien: { name: string; inhalt: string }[]) {
    const grenze = "----lotsegrenze";
    const teile = dateien.map(
        (datei) =>
            `--${grenze}\r\n` +
            `Content-Disposition: form-data; name="dateien"; filename="${datei.name}"\r\n` +
            `Content-Type: text/csv\r\n\r\n${datei.inhalt}\r\n`,
    );
    return {
        headers: { "content-type": `multipart/form-data; boundary=${grenze}` },
        payload: teile.join("") + `--${grenze}--\r\n`,
    };
}

describe("Anmeldung und Rollen", () => {
    test("Registrierung legt Organisation, Inhaber und ersten Mandanten an", async () => {
        const { marke, mandantId } = await konto();
        const ich = await app.inject({ method: "GET", url: "/api/ich", cookies: als(marke) });
        expect(ich.json().benutzer.rolle).toBe("inhaber");
        expect(ich.json().organisation.name).toBe("Nordwerk GmbH");
        expect(mandantId).toBeTruthy();
    });

    test("kurze Kennwörter werden abgelehnt", async () => {
        const antwort = await app.inject({
            method: "POST",
            url: "/api/registrierung",
            payload: { organisation: "X GmbH", name: "Bert", email: "b@x.de", kennwort: "kurz123" },
        });
        expect(antwort.statusCode).toBe(400);
        expect(antwort.json().felder.kennwort).toContain("12 Zeichen");
    });

    test("falsches Kennwort meldet 401", async () => {
        await konto();
        const antwort = await app.inject({
            method: "POST",
            url: "/api/anmeldung",
            payload: { email: "chefin@nordwerk.de", kennwort: "ganz-falsch-2026" },
        });
        expect(antwort.statusCode).toBe(401);
    });

    test("ohne Sitzung gibt es keine Daten", async () => {
        expect((await app.inject({ method: "GET", url: "/api/mandanten" })).statusCode).toBe(401);
    });

    test("Mitglieder dürfen lesen, aber keine Mandanten anlegen", async () => {
        const { marke } = await konto();
        const zweite = await mitglied(marke);
        expect((await app.inject({ method: "GET", url: "/api/mandanten", cookies: als(zweite) })).statusCode).toBe(200);
        const verboten = await app.inject({
            method: "POST",
            url: "/api/mandanten",
            cookies: als(zweite),
            payload: { name: "Fremdfirma" },
        });
        expect(verboten.statusCode).toBe(403);
        expect(verboten.json().fehler).toContain("Berechtigung");
    });

    test("Mitglieder dürfen keine Preise ändern", async () => {
        const { marke, mandantId } = await konto();
        const zweite = await mitglied(marke);
        const antwort = await app.inject({
            method: "PUT",
            url: `/api/mandanten/${mandantId}/preise`,
            cookies: als(zweite),
            payload: { preise: [{ sku: "SPB", cent: 1000 }] },
        });
        expect(antwort.statusCode).toBe(403);
    });
});

describe("Mandantentrennung", () => {
    test("fremde Mandanten sind unsichtbar, nicht nur gesperrt", async () => {
        const erste = await konto("erste@nordwerk.de");
        const zweite = await konto("zweite@suedwerk.de");
        const fremd = await app.inject({
            method: "GET",
            url: `/api/mandanten/${erste.mandantId}/uebersicht`,
            cookies: als(zweite.marke),
        });
        expect(fremd.statusCode).toBe(404);
        const liste = await app.inject({ method: "GET", url: "/api/mandanten", cookies: als(zweite.marke) });
        expect(liste.json().mandanten.map((m: { id: string }) => m.id)).not.toContain(erste.mandantId);
    });

    test("fremde Befunde lassen sich nicht abhaken", async () => {
        const erste = await konto("erste@nordwerk.de");
        await app.inject({ method: "POST", url: `/api/mandanten/${erste.mandantId}/demodaten`, cookies: als(erste.marke) });
        const zweite = await konto("zweite@suedwerk.de");
        const antwort = await app.inject({
            method: "POST",
            url: `/api/mandanten/${erste.mandantId}/befunde/irgendwas/stand`,
            cookies: als(zweite.marke),
            payload: { status: "erledigt" },
        });
        expect(antwort.statusCode).toBe(404);
    });
});

describe("Auswertung", () => {
    test("Beispieldaten ergeben Befunde in allen wichtigen Kategorien", async () => {
        const { marke, mandantId } = await konto();
        const erzeugt = await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/demodaten`,
            cookies: als(marke),
        });
        expect(erzeugt.statusCode).toBe(201);
        expect(erzeugt.json().konten).toBeGreaterThan(50);

        const uebersicht = await app.inject({
            method: "GET",
            url: `/api/mandanten/${mandantId}/uebersicht`,
            cookies: als(marke),
        });
        const daten = uebersicht.json();
        const arten = new Set(daten.befunde.map((b: { art: string }) => b.art));
        expect(arten).toContain("gesperrt_lizenziert");
        expect(arten).toContain("inaktiv");
        expect(arten).toContain("nie_aktiv");
        expect(arten).toContain("regallizenz");
        expect(arten).toContain("doppelte_lizenz");
        expect(arten).toContain("ungenutztes_zusatzprodukt");
        expect(arten).toContain("ueberdimensioniert");
        expect(daten.auswertung.ersparnis_cent).toBeGreaterThan(50_000);
        expect(daten.kennzahlen.offenCent).toBe(daten.auswertung.ersparnis_cent);
    });

    test("hochgeladene Ausgaben werden verarbeitet", async () => {
        const { marke, mandantId } = await konto();
        const dateien = beispielausgaben(HEUTE).map((d) => ({ name: d.name, inhalt: d.inhalt }));
        const antwort = await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/auswertung`,
            cookies: als(marke),
            ...multipart(dateien),
        });
        expect(antwort.statusCode).toBe(201);
        expect(antwort.json().dateien).toHaveLength(3);
        expect(antwort.json().dateien.map((d: { art: string }) => d.art).sort()).toEqual([
            "abonnements", "konten", "nutzung",
        ]);
    });

    test("eine Ausgabe ohne Konten wird mit Begründung abgelehnt", async () => {
        const { marke, mandantId } = await konto();
        const antwort = await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/auswertung`,
            cookies: als(marke),
            ...multipart([{ name: "urlaub.csv", inhalt: "a,b\n1,2\n" }]),
        });
        expect(antwort.statusCode).toBe(422);
        expect(antwort.json().fehler).toContain("keine Konten");
    });

    test("ohne Datei kommt eine verständliche Meldung", async () => {
        const { marke, mandantId } = await konto();
        const antwort = await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/auswertung`,
            cookies: als(marke),
            ...multipart([]),
        });
        expect(antwort.statusCode).toBe(400);
    });
});

describe("Bearbeitungsstand", () => {
    test("überlebt eine neue Auswertung", async () => {
        const { marke, mandantId } = await konto();
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        const erste = await app.inject({
            method: "GET", url: `/api/mandanten/${mandantId}/uebersicht`, cookies: als(marke),
        });
        const befund = erste.json().befunde[0];
        expect(befund.status).toBe("offen");

        const gesetzt = await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/befunde/${encodeURIComponent(befund.schluessel)}/stand`,
            cookies: als(marke),
            payload: { status: "ignoriert", notiz: "Konto bleibt für die Nachbearbeitung" },
        });
        expect(gesetzt.statusCode).toBe(200);

        // Zweiter Lauf mit denselben Daten — der Stand muss haften bleiben.
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        const zweite = await app.inject({
            method: "GET", url: `/api/mandanten/${mandantId}/uebersicht`, cookies: als(marke),
        });
        const wieder = zweite.json().befunde.find(
            (b: { schluessel: string }) => b.schluessel === befund.schluessel,
        );
        expect(wieder.status).toBe("ignoriert");
        expect(wieder.stand_notiz).toContain("Nachbearbeitung");
    });

    test("erledigte Befunde zählen nicht mehr als offenes Potenzial", async () => {
        const { marke, mandantId } = await konto();
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        const vorher = await app.inject({
            method: "GET", url: `/api/mandanten/${mandantId}/uebersicht`, cookies: als(marke),
        });
        const befund = vorher.json().befunde[0];
        await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/befunde/${encodeURIComponent(befund.schluessel)}/stand`,
            cookies: als(marke),
            payload: { status: "erledigt" },
        });
        const nachher = await app.inject({
            method: "GET", url: `/api/mandanten/${mandantId}/uebersicht`, cookies: als(marke),
        });
        expect(nachher.json().kennzahlen.offenCent).toBe(
            vorher.json().kennzahlen.offenCent - befund.ersparnis_cent,
        );
        expect(nachher.json().kennzahlen.erledigtCent).toBe(befund.ersparnis_cent);
    });

    test("unbekannte Befundschlüssel werden abgewiesen", async () => {
        const { marke, mandantId } = await konto();
        const antwort = await app.inject({
            method: "POST",
            url: `/api/mandanten/${mandantId}/befunde/gibtsnicht/stand`,
            cookies: als(marke),
            payload: { status: "erledigt" },
        });
        expect(antwort.statusCode).toBe(404);
    });
});

describe("Eigene Preise", () => {
    test("verändern die ausgewiesene Ersparnis", async () => {
        const { marke, mandantId } = await konto();
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        const mitKatalog = (
            await app.inject({ method: "GET", url: `/api/mandanten/${mandantId}/uebersicht`, cookies: als(marke) })
        ).json().auswertung.ersparnis_cent;

        await app.inject({
            method: "PUT",
            url: `/api/mandanten/${mandantId}/preise`,
            cookies: als(marke),
            payload: { preise: [{ sku: "SPB", cent: 100 }] },
        });
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        const mitEigenem = (
            await app.inject({ method: "GET", url: `/api/mandanten/${mandantId}/uebersicht`, cookies: als(marke) })
        ).json().auswertung.ersparnis_cent;

        expect(mitEigenem).toBeLessThan(mitKatalog);
    });

    test("die Preisliste nennt Katalog- und eigenen Wert", async () => {
        const { marke, mandantId } = await konto();
        await app.inject({
            method: "PUT",
            url: `/api/mandanten/${mandantId}/preise`,
            cookies: als(marke),
            payload: { preise: [{ sku: "SPB", cent: 2000 }] },
        });
        const antwort = await app.inject({
            method: "GET", url: `/api/mandanten/${mandantId}/preise`, cookies: als(marke),
        });
        const spb = antwort.json().preise.find((p: { sku: string }) => p.sku === "SPB");
        expect(spb.katalogCent).toBe(2610);
        expect(spb.eigenCent).toBe(2000);
        expect(spb.name).toBe("Microsoft 365 Business Premium");
    });
});

describe("Ausgaben und Verlauf", () => {
    test("CSV enthält Befunde mit Jahresbetrag", async () => {
        const { marke, mandantId } = await konto();
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        const antwort = await app.inject({
            method: "GET", url: `/api/mandanten/${mandantId}/export.csv`, cookies: als(marke),
        });
        expect(antwort.headers["content-type"]).toContain("text/csv");
        expect(antwort.body).toContain("Ersparnis je Jahr");
        expect(antwort.body).toContain("gesperrt");
    });

    test("der Verlauf protokolliert, wer was getan hat", async () => {
        const { marke, mandantId } = await konto();
        await app.inject({ method: "POST", url: `/api/mandanten/${mandantId}/demodaten`, cookies: als(marke) });
        await app.inject({
            method: "POST", url: "/api/mandanten", cookies: als(marke), payload: { name: "Zweitfirma" },
        });
        const verlauf = (await app.inject({ method: "GET", url: "/api/verlauf", cookies: als(marke) })).json().verlauf;
        const aktionen = verlauf.map((v: { aktion: string }) => v.aktion);
        expect(aktionen).toContain("registrierung");
        expect(aktionen).toContain("mandant_angelegt");
        expect(verlauf[0].benutzer_name).toBe("Anna Nord");
    });
});
