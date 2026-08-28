import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { baueApp } from "./app.ts";
import { oeffneDatenbank, type Db } from "./datenbank.ts";
import { planeErinnerungen } from "./erinnerungen.ts";
import { leseUmgebung, type Umgebung } from "./umgebung.ts";

const HEUTE = "2026-08-25";

let db: Db;
let app: FastifyInstance;
let umgebung: Umgebung;

beforeEach(async () => {
    db = oeffneDatenbank(":memory:");
    umgebung = { ...leseUmgebung({}), basisAdresse: "https://waechter.test" };
    app = baueApp({ db, umgebung, heuteGeben: () => HEUTE });
    await app.ready();
});

afterEach(async () => {
    await app.close();
    db.close();
});

async function konto(email = "chefin@beispiel.de"): Promise<string> {
    const antwort = await app.inject({
        method: "POST",
        url: "/api/registrierung",
        payload: {
            organisation: "Beispiel GmbH",
            name: "Anna Beispiel",
            email,
            kennwort: "sicher-genug-2026",
        },
    });
    expect(antwort.statusCode).toBe(201);
    const keks = antwort.cookies.find((k) => k.name === "waechter_sitzung");
    expect(keks).toBeDefined();
    return keks!.value as string;
}

function alsBenutzer(marke: string) {
    return { waechter_sitzung: marke };
}

const jahresvertrag = {
    bezeichnung: "Betriebshaftpflicht",
    anbieter: "Allianz",
    kategorie: "versicherung",
    beginn: "2020-01-01",
    laufzeitmodell: "befristet_mit_verlaengerung",
    erstlaufzeitMonate: 12,
    verlaengerungMonate: 12,
    kuendigungsfristWert: 3,
    kuendigungsfristEinheit: "monate",
    kuendigungsfristBezug: "zum_laufzeitende",
    betragCent: 248_400,
    zahlungsintervall: "jaehrlich",
};

async function legeAn(marke: string, daten: Record<string, unknown> = {}) {
    const antwort = await app.inject({
        method: "POST",
        url: "/api/vertraege",
        cookies: alsBenutzer(marke),
        payload: { ...jahresvertrag, ...daten },
    });
    expect(antwort.statusCode).toBe(201);
    return antwort.json().vertrag;
}

describe("Anmeldung", () => {
    test("Registrierung legt Organisation und Sitzung an", async () => {
        const marke = await konto();
        const ich = await app.inject({ method: "GET", url: "/api/ich", cookies: alsBenutzer(marke) });
        expect(ich.statusCode).toBe(200);
        expect(ich.json().organisation.name).toBe("Beispiel GmbH");
        expect(ich.json().benutzer.rolle).toBe("inhaber");
        expect(ich.json().kalenderAdresse).toMatch(/^https:\/\/waechter\.test\/kalender\/.+\.ics$/);
    });

    test("dieselbe Adresse kann sich nicht zweimal registrieren", async () => {
        await konto();
        const zweiter = await app.inject({
            method: "POST",
            url: "/api/registrierung",
            payload: {
                organisation: "Andere GmbH",
                name: "Bert",
                email: "chefin@beispiel.de",
                kennwort: "auch-sicher-2026",
            },
        });
        expect(zweiter.statusCode).toBe(409);
    });

    test("zu kurzes Kennwort wird abgelehnt", async () => {
        const antwort = await app.inject({
            method: "POST",
            url: "/api/registrierung",
            payload: { organisation: "X GmbH", name: "Bert", email: "b@x.de", kennwort: "kurz" },
        });
        expect(antwort.statusCode).toBe(400);
        expect(antwort.json().felder.kennwort).toContain("10 Zeichen");
    });

    test("falsches Kennwort meldet 401", async () => {
        await konto();
        const antwort = await app.inject({
            method: "POST",
            url: "/api/anmeldung",
            payload: { email: "chefin@beispiel.de", kennwort: "falsch-falsch-falsch" },
        });
        expect(antwort.statusCode).toBe(401);
    });

    test("richtiges Kennwort meldet an", async () => {
        await konto();
        const antwort = await app.inject({
            method: "POST",
            url: "/api/anmeldung",
            payload: { email: "CHEFIN@beispiel.de", kennwort: "sicher-genug-2026" },
        });
        expect(antwort.statusCode).toBe(200);
        expect(antwort.cookies.some((k) => k.name === "waechter_sitzung")).toBe(true);
    });

    test("ohne Anmeldung gibt es keine Verträge", async () => {
        const antwort = await app.inject({ method: "GET", url: "/api/vertraege" });
        expect(antwort.statusCode).toBe(401);
    });

    test("Abmeldung entwertet die Sitzung", async () => {
        const marke = await konto();
        await app.inject({ method: "POST", url: "/api/abmeldung", cookies: alsBenutzer(marke) });
        const antwort = await app.inject({ method: "GET", url: "/api/ich", cookies: alsBenutzer(marke) });
        expect(antwort.statusCode).toBe(401);
    });
});

describe("Verträge", () => {
    test("werden mit berechneten Fristen zurückgegeben", async () => {
        const marke = await konto();
        const vertrag = await legeAn(marke);
        expect(vertrag.fristen.stichtag).toBe("2026-09-30");
        expect(vertrag.fristen.tageBisStichtag).toBe(36);
        expect(vertrag.fristen.wirksamesVertragsende).toBe("2026-12-31");
        expect(vertrag.ampel).toBe("warnung");
        expect(vertrag.jahreskostenCent).toBe(248_400);
    });

    test("unsinnige Eingaben werden mit Feldmeldungen abgelehnt", async () => {
        const marke = await konto();
        const antwort = await app.inject({
            method: "POST",
            url: "/api/vertraege",
            cookies: alsBenutzer(marke),
            payload: { ...jahresvertrag, verlaengerungMonate: 0, beginn: "31.12.2020" },
        });
        expect(antwort.statusCode).toBe(400);
        expect(antwort.json().felder).toHaveProperty("beginn");
        expect(antwort.json().felder).toHaveProperty("verlaengerungMonate");
    });

    test("die Liste sortiert nach nächstem Stichtag", async () => {
        const marke = await konto();
        // Ein Monat Frist ergibt den 30.11., zwei Monate den 31.10.
        await legeAn(marke, { bezeichnung: "Später", kuendigungsfristWert: 1 });
        await legeAn(marke, { bezeichnung: "Früher", kuendigungsfristWert: 2 });
        const antwort = await app.inject({ method: "GET", url: "/api/vertraege", cookies: alsBenutzer(marke) });
        const namen = antwort.json().vertraege.map((v: { bezeichnung: string }) => v.bezeichnung);
        expect(namen).toEqual(["Früher", "Später"]);
    });

    test("die Suche filtert über Anbieter und Nummer", async () => {
        const marke = await konto();
        await legeAn(marke, { bezeichnung: "Softwareabo", anbieter: "Pipedrive" });
        await legeAn(marke, { bezeichnung: "Haftpflicht", anbieter: "Allianz" });
        const antwort = await app.inject({
            method: "GET",
            url: "/api/vertraege?suche=pipedrive",
            cookies: alsBenutzer(marke),
        });
        expect(antwort.json().vertraege).toHaveLength(1);
        expect(antwort.json().vertraege[0].bezeichnung).toBe("Softwareabo");
    });

    test("Kündigung setzt Status und Endedatum", async () => {
        const marke = await konto();
        const vertrag = await legeAn(marke);
        const antwort = await app.inject({
            method: "POST",
            url: `/api/vertraege/${vertrag.id}/kuendigung`,
            cookies: alsBenutzer(marke),
            payload: { notiz: "Per Einschreiben verschickt" },
        });
        expect(antwort.statusCode).toBe(200);
        const gekuendigt = antwort.json().vertrag;
        expect(gekuendigt.status).toBe("gekuendigt");
        expect(gekuendigt.gekuendigtZum).toBe("2026-12-31");
        expect(gekuendigt.ampel).toBe("gekuendigt");
        expect(gekuendigt.notizen).toContain("Einschreiben");
    });

    test("eine Kündigung lässt sich zurücknehmen", async () => {
        const marke = await konto();
        const vertrag = await legeAn(marke);
        await app.inject({
            method: "POST",
            url: `/api/vertraege/${vertrag.id}/kuendigung`,
            cookies: alsBenutzer(marke),
            payload: {},
        });
        const antwort = await app.inject({
            method: "POST",
            url: `/api/vertraege/${vertrag.id}/reaktivierung`,
            cookies: alsBenutzer(marke),
        });
        expect(antwort.json().vertrag.status).toBe("aktiv");
        expect(antwort.json().vertrag.gekuendigtZum).toBeNull();
    });

    test("Bearbeiten rechnet die Fristen neu", async () => {
        const marke = await konto();
        const vertrag = await legeAn(marke);
        const antwort = await app.inject({
            method: "PUT",
            url: `/api/vertraege/${vertrag.id}`,
            cookies: alsBenutzer(marke),
            payload: { ...jahresvertrag, kuendigungsfristWert: 1 },
        });
        expect(antwort.json().vertrag.fristen.stichtag).toBe("2026-11-30");
    });

    test("fremde Verträge bleiben unsichtbar", async () => {
        const ersteMarke = await konto("erste@beispiel.de");
        const vertrag = await legeAn(ersteMarke);
        const zweiteMarke = await konto("zweite@andere.de");
        const lesen = await app.inject({
            method: "GET",
            url: `/api/vertraege/${vertrag.id}`,
            cookies: alsBenutzer(zweiteMarke),
        });
        expect(lesen.statusCode).toBe(404);
        const liste = await app.inject({ method: "GET", url: "/api/vertraege", cookies: alsBenutzer(zweiteMarke) });
        expect(liste.json().vertraege).toHaveLength(0);
    });
});

describe("Übersicht", () => {
    test("summiert Kosten und zählt die Ampelstufen", async () => {
        const marke = await konto();
        await legeAn(marke);
        await legeAn(marke, {
            bezeichnung: "Software",
            betragCent: 10_000,
            zahlungsintervall: "monatlich",
            kuendigungsfristWert: 2,
        });
        const antwort = await app.inject({ method: "GET", url: "/api/uebersicht", cookies: alsBenutzer(marke) });
        const uebersicht = antwort.json();
        expect(uebersicht.anzahlAktiv).toBe(2);
        expect(uebersicht.jahreskostenCent).toBe(248_400 + 120_000);
        expect(uebersicht.nachAmpel.warnung).toBe(1);
        expect(uebersicht.nachAmpel.hinweis).toBe(1);
        expect(uebersicht.fristenIn90).toBe(2);
        expect(uebersicht.naechsteFristen[0].fristen.stichtag).toBe("2026-09-30");
    });
});

describe("Fristenlauf", () => {
    test("legt Erinnerungen an und schreibt eine Sammelmail in den Postausgang", async () => {
        const marke = await konto();
        await legeAn(marke);
        const ergebnis = await planeErinnerungen(db, umgebung, HEUTE);
        expect(ergebnis.neueErinnerungen).toBe(1); // nur die 90-Tage-Stufe ist fällig
        const post = await app.inject({ method: "GET", url: "/api/postausgang", cookies: alsBenutzer(marke) });
        const nachricht = post.json().nachrichten[0];
        expect(nachricht.empfaenger).toBe("chefin@beispiel.de");
        expect(nachricht.betreff).toContain("Betriebshaftpflicht");
        expect(nachricht.inhalt).toContain("30.09.2026");
        expect(nachricht.versendet_am).toBeNull(); // ohne SMTP nur abgelegt
    });

    test("ein zweiter Lauf am selben Tag erzeugt nichts Neues", async () => {
        const marke = await konto();
        await legeAn(marke);
        await planeErinnerungen(db, umgebung, HEUTE);
        const zweiter = await planeErinnerungen(db, umgebung, HEUTE);
        expect(zweiter.neueErinnerungen).toBe(0);
    });

    test("mehrere fällige Stufen ergeben eine Mail, nicht drei", async () => {
        const marke = await konto();
        // Laufzeitende 30.11., Stichtag also der 31.08. — die Stufen 90, 30
        // und 14 Tage sind an diesem Tag alle gleichzeitig fällig.
        await legeAn(marke, { beginn: "2020-12-01" });
        const ergebnis = await planeErinnerungen(db, umgebung, HEUTE);
        expect(ergebnis.neueErinnerungen).toBe(3);
        const post = await app.inject({ method: "GET", url: "/api/postausgang", cookies: alsBenutzer(marke) });
        expect(post.json().nachrichten).toHaveLength(1);
    });

    test("überholte Vorlaufstufen stehen nicht mehr offen", async () => {
        const marke = await konto();
        await legeAn(marke, { beginn: "2020-12-01" });
        await planeErinnerungen(db, umgebung, HEUTE);
        const liste = await app.inject({ method: "GET", url: "/api/erinnerungen", cookies: alsBenutzer(marke) });
        const eintraege = liste.json().erinnerungen as { vorlauf_tage: number; erledigt_am: string | null }[];
        expect(eintraege).toHaveLength(3);
        // Offen bleibt allein die dringlichste Stufe.
        const offen = eintraege.filter((e) => !e.erledigt_am);
        expect(offen).toHaveLength(1);
        expect(offen[0]!.vorlauf_tage).toBe(14);
    });

    test("gekündigte Verträge werden nicht mehr erinnert", async () => {
        const marke = await konto();
        const vertrag = await legeAn(marke);
        await app.inject({
            method: "POST",
            url: `/api/vertraege/${vertrag.id}/kuendigung`,
            cookies: alsBenutzer(marke),
            payload: {},
        });
        const ergebnis = await planeErinnerungen(db, umgebung, HEUTE);
        expect(ergebnis.neueErinnerungen).toBe(0);
    });

    test("Erinnerungen lassen sich abhaken", async () => {
        const marke = await konto();
        await legeAn(marke);
        await planeErinnerungen(db, umgebung, HEUTE);
        const liste = await app.inject({ method: "GET", url: "/api/erinnerungen", cookies: alsBenutzer(marke) });
        const erste = liste.json().erinnerungen[0];
        expect(erste.erledigt_am).toBeNull();
        const antwort = await app.inject({
            method: "POST",
            url: `/api/erinnerungen/${erste.id}/erledigt`,
            cookies: alsBenutzer(marke),
        });
        expect(antwort.statusCode).toBe(200);
    });
});

describe("Ausgaben", () => {
    test("CSV enthält Kopfzeile und Vertrag", async () => {
        const marke = await konto();
        await legeAn(marke);
        const antwort = await app.inject({
            method: "GET",
            url: "/api/export/vertraege.csv",
            cookies: alsBenutzer(marke),
        });
        expect(antwort.headers["content-type"]).toContain("text/csv");
        expect(antwort.body).toContain("Nächster Stichtag");
        expect(antwort.body).toContain("Betriebshaftpflicht;Allianz");
        expect(antwort.body).toContain("30.09.2026");
    });

    test("der Kalender ist über den Schlüssel öffentlich abrufbar", async () => {
        const marke = await konto();
        await legeAn(marke);
        const ich = await app.inject({ method: "GET", url: "/api/ich", cookies: alsBenutzer(marke) });
        const adresse = new URL(ich.json().kalenderAdresse).pathname;
        const antwort = await app.inject({ method: "GET", url: adresse });
        expect(antwort.statusCode).toBe(200);
        expect(antwort.headers["content-type"]).toContain("text/calendar");
        expect(antwort.body).toContain("BEGIN:VEVENT");
        expect(antwort.body).toContain("DTSTART;VALUE=DATE:20260930");
        expect(antwort.body).toContain("SUMMARY:Kündigungsfrist: Betriebshaftpflicht");
    });

    test("ein falscher Kalenderschlüssel liefert 404", async () => {
        const antwort = await app.inject({ method: "GET", url: "/kalender/gibtsnicht.ics" });
        expect(antwort.statusCode).toBe(404);
    });
});

describe("Demodaten", () => {
    test("legen einen Bestand mit dringenden und ruhigen Fristen an", async () => {
        const marke = await konto();
        const antwort = await app.inject({ method: "POST", url: "/api/demodaten", cookies: alsBenutzer(marke) });
        expect(antwort.json().angelegt).toBeGreaterThan(5);
        const liste = await app.inject({ method: "GET", url: "/api/vertraege", cookies: alsBenutzer(marke) });
        const ampeln = liste.json().vertraege.map((v: { ampel: string }) => v.ampel);
        expect(ampeln).toContain("kritisch");
        expect(ampeln).toContain("warnung");
        expect(ampeln).toContain("ok");
        expect(ampeln).toContain("gekuendigt");
    });
});

describe("Einstellungen", () => {
    test("Vorlaufzeiten werden sortiert und entdoppelt gespeichert", async () => {
        const marke = await konto();
        const antwort = await app.inject({
            method: "PUT",
            url: "/api/organisation",
            cookies: alsBenutzer(marke),
            payload: {
                name: "Beispiel GmbH & Co. KG",
                erinnerungsvorlauf: [30, 120, 30, 7],
                verteiler: ["buchhaltung@beispiel.de"],
            },
        });
        expect(antwort.statusCode).toBe(200);
        expect(antwort.json().organisation.erinnerungsvorlauf).toEqual([120, 30, 7]);
        expect(antwort.json().organisation.verteiler).toEqual(["buchhaltung@beispiel.de"]);
    });

    test("der Kalenderschlüssel lässt sich erneuern", async () => {
        const marke = await konto();
        const vorher = (await app.inject({ method: "GET", url: "/api/ich", cookies: alsBenutzer(marke) })).json()
            .kalenderAdresse;
        const antwort = await app.inject({
            method: "POST",
            url: "/api/kalenderschluessel",
            cookies: alsBenutzer(marke),
        });
        expect(antwort.json().kalenderAdresse).not.toBe(vorher);
        const alt = await app.inject({ method: "GET", url: new URL(vorher).pathname });
        expect(alt.statusCode).toBe(404);
    });
});
