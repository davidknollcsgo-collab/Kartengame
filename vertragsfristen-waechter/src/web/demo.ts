// Browser-Demo: dieselbe Oberfläche, dieselbe Fristenrechnung, aber ohne
// Server. Alles liegt im localStorage des Betrachters und verlässt den
// Browser nicht. Gedacht zum Ausprobieren, nicht als Ablage für echte
// Verträge — der Fristenlauf läuft nur, während die Seite offen ist.

import { beispielvertraege } from "../fachlogik/beispiele.ts";
import { heute, istVor, plusTage, tageBis } from "../fachlogik/datum.ts";
import { baueCsv } from "../fachlogik/csv.ts";
import { bewerteVertrag, type Ampel } from "../fachlogik/fristen.ts";
import { jahreskostenCent } from "../fachlogik/formate.ts";
import { baueSammelmail } from "../fachlogik/mailtext.ts";
import type { Organisation, Vertrag } from "../fachlogik/typen.ts";
import type { Api, Filter } from "./api.ts";
import type {
    Erinnerung,
    Nachricht,
    Uebersicht,
    Verlaufseintrag,
    VertragEingabe,
    VertragMitFristen,
} from "./typen.ts";

const ABLAGE = "vertragsfristen-waechter.demo.v1";

interface Bestand {
    organisation: Organisation;
    vertraege: Vertrag[];
    erinnerungen: Erinnerung[];
    postausgang: Nachricht[];
    verlauf: (Verlaufseintrag & { vertrag_id: string | null })[];
}

function frischerBestand(): Bestand {
    const basis = heute();
    const jetzt = new Date().toISOString();
    return {
        organisation: {
            id: "demo",
            name: "Beispiel GmbH",
            erinnerungsvorlauf: [90, 30, 14, 3],
            verteiler: ["buchhaltung@beispiel.de"],
            kalenderSchluessel: "demo",
            erstelltAm: jetzt,
        },
        vertraege: beispielvertraege(basis).map((vertrag) => ({
            ...vertrag,
            id: crypto.randomUUID(),
            organisationId: "demo",
            erstelltAm: jetzt,
            geaendertAm: jetzt,
        })),
        erinnerungen: [],
        postausgang: [],
        verlauf: [],
    };
}

function lade(): Bestand {
    try {
        const roh = localStorage.getItem(ABLAGE);
        if (roh) return JSON.parse(roh) as Bestand;
    } catch {
        // Privates Fenster oder gesperrter Speicher: dann eben flüchtig.
    }
    const bestand = frischerBestand();
    sichere(bestand);
    return bestand;
}

let bestand: Bestand | null = null;

function daten(): Bestand {
    bestand ??= lade();
    return bestand;
}

function sichere(neu: Bestand = daten()): void {
    bestand = neu;
    try {
        localStorage.setItem(ABLAGE, JSON.stringify(neu));
    } catch {
        // Nicht schlimm — der Bestand lebt dann nur bis zum Neuladen.
    }
}

function notiere(aktion: string, beschreibung: string, vertragId: string | null = null): void {
    daten().verlauf.unshift({
        id: crypto.randomUUID(),
        aktion,
        beschreibung,
        zeitpunkt: new Date().toISOString(),
        vertrag_id: vertragId,
    });
}

function mitFristen(vertrag: Vertrag, basis: string): VertragMitFristen {
    const { fristen, ampel } = bewerteVertrag(vertrag, basis);
    return {
        ...vertrag,
        fristen,
        ampel,
        jahreskostenCent: jahreskostenCent(vertrag.betragCent, vertrag.zahlungsintervall),
    };
}

function finde(id: string): Vertrag {
    const vertrag = daten().vertraege.find((v) => v.id === id);
    if (!vertrag) throw new Error("Vertrag nicht gefunden");
    return vertrag;
}

async function warte<T>(wert: T): Promise<T> {
    return wert;
}

export const demoApi: Api = {
    demo: true,

    async ich() {
        return {
            benutzer: {
                id: "demo",
                organisationId: "demo",
                name: "Anna Beispiel",
                email: "anna@beispiel.de",
                rolle: "inhaber",
                erstelltAm: daten().organisation.erstelltAm,
            },
            organisation: daten().organisation,
            heute: heute(),
            kalenderAdresse: "",
        };
    },

    async anmelden() {},
    async registrieren() {},
    async abmelden() {
        localStorage.removeItem(ABLAGE);
        bestand = null;
    },

    async vertraege(filter: Filter = {}) {
        const basis = heute();
        const suche = (filter.suche ?? "").trim().toLowerCase();
        let liste = daten().vertraege.map((v) => mitFristen(v, basis));
        if (filter.kategorie) liste = liste.filter((v) => v.kategorie === filter.kategorie);
        if (filter.status) liste = liste.filter((v) => v.status === filter.status);
        if (filter.ampel) liste = liste.filter((v) => v.ampel === filter.ampel);
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
        return warte({ vertraege: liste, heute: basis });
    },

    async vertrag(id) {
        return warte({
            vertrag: mitFristen(finde(id), heute()),
            verlauf: daten().verlauf.filter((e) => e.vertrag_id === id),
            erinnerungen: daten().erinnerungen.filter((e) => e.vertrag_id === id),
        });
    },

    async anlegen(eingabe: VertragEingabe) {
        const jetzt = new Date().toISOString();
        const vertrag: Vertrag = {
            ...eingabe,
            id: crypto.randomUUID(),
            organisationId: "demo",
            erstelltAm: jetzt,
            geaendertAm: jetzt,
        };
        daten().vertraege.push(vertrag);
        notiere("angelegt", `„${vertrag.bezeichnung}“ angelegt`, vertrag.id);
        sichere();
        return mitFristen(vertrag, heute());
    },

    async aendern(id, eingabe) {
        const vertrag = finde(id);
        Object.assign(vertrag, eingabe, { geaendertAm: new Date().toISOString() });
        notiere("geaendert", `„${vertrag.bezeichnung}“ bearbeitet`, id);
        sichere();
        return mitFristen(vertrag, heute());
    },

    async loeschen(id) {
        const vertrag = finde(id);
        daten().vertraege = daten().vertraege.filter((v) => v.id !== id);
        daten().erinnerungen = daten().erinnerungen.filter((e) => e.vertrag_id !== id);
        notiere("geloescht", `„${vertrag.bezeichnung}“ gelöscht`);
        sichere();
    },

    async kuendigen(id, angaben) {
        const basis = heute();
        const vertrag = finde(id);
        const { fristen } = bewerteVertrag(vertrag, basis);
        const ende = angaben.gekuendigtZum ?? fristen.wirksamesVertragsende ?? basis;
        vertrag.status = istVor(ende, basis) ? "beendet" : "gekuendigt";
        vertrag.gekuendigtZum = ende;
        if (angaben.notiz) {
            vertrag.notizen = `${vertrag.notizen}\n[${basis}] Kündigung: ${angaben.notiz}`.trim();
        }
        vertrag.geaendertAm = new Date().toISOString();
        for (const erinnerung of daten().erinnerungen) {
            if (erinnerung.vertrag_id === id && !erinnerung.erledigt_am) {
                erinnerung.erledigt_am = new Date().toISOString();
            }
        }
        notiere("gekuendigt", `„${vertrag.bezeichnung}“ zum ${ende} gekündigt`, id);
        sichere();
        return mitFristen(vertrag, basis);
    },

    async reaktivieren(id) {
        const vertrag = finde(id);
        vertrag.status = "aktiv";
        vertrag.gekuendigtZum = null;
        vertrag.geaendertAm = new Date().toISOString();
        notiere("reaktiviert", `Kündigung von „${vertrag.bezeichnung}“ zurückgenommen`, id);
        sichere();
        return mitFristen(vertrag, heute());
    },

    async uebersicht(): Promise<Uebersicht> {
        const basis = heute();
        const alle = daten().vertraege.map((v) => mitFristen(v, basis));
        const aktive = alle.filter((v) => v.status === "aktiv");
        const nachAmpel: Record<Ampel, number> = {
            kritisch: 0, warnung: 0, hinweis: 0, ok: 0, jederzeit: 0, gekuendigt: 0, beendet: 0,
        };
        for (const vertrag of alle) nachAmpel[vertrag.ampel] += 1;

        const nachKategorie: Uebersicht["nachKategorie"] = {};
        for (const vertrag of aktive) {
            const eintrag = (nachKategorie[vertrag.kategorie] ??= { anzahl: 0, jahreskostenCent: 0 });
            eintrag.anzahl += 1;
            eintrag.jahreskostenCent += vertrag.jahreskostenCent;
        }
        const inTagen = (tage: number) =>
            aktive.filter(
                (v) =>
                    v.fristen.tageBisStichtag !== null &&
                    v.fristen.tageBisStichtag >= 0 &&
                    v.fristen.tageBisStichtag <= tage,
            ).length;

        return warte({
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
                .sort((a, b) => (a.fristen.stichtag ?? "").localeCompare(b.fristen.stichtag ?? ""))
                .slice(0, 8),
            offeneErinnerungen: {
                anzahl: daten().erinnerungen.filter((e) => !e.erledigt_am).length,
            },
        });
    },

    async erinnerungen() {
        const sortiert = [...daten().erinnerungen].sort((a, b) => {
            const erledigt = Number(Boolean(a.erledigt_am)) - Number(Boolean(b.erledigt_am));
            return erledigt || b.faellig_am.localeCompare(a.faellig_am);
        });
        return warte({ erinnerungen: sortiert, heute: heute() });
    },

    async erinnerungErledigt(id) {
        const erinnerung = daten().erinnerungen.find((e) => e.id === id);
        if (erinnerung) erinnerung.erledigt_am = new Date().toISOString();
        sichere();
    },

    async postausgang() {
        return warte({ nachrichten: [...daten().postausgang], smtpEingerichtet: false });
    },

    async fristenlauf() {
        const basis = heute();
        const bestandJetzt = daten();
        const vorlauf = bestandJetzt.organisation.erinnerungsvorlauf;
        const neue: { vertrag: Vertrag; stichtag: string; tageBisStichtag: number; vorlauf: number }[] = [];

        for (const vertrag of bestandJetzt.vertraege) {
            if (vertrag.status !== "aktiv") continue;
            const stichtag = bewerteVertrag(vertrag, basis).ueberwachungsdatum;
            if (!stichtag || istVor(stichtag, basis)) continue;
            for (const tage of vorlauf) {
                const faellig = plusTage(stichtag, -tage);
                if (istVor(basis, faellig)) continue;
                const schonDa = bestandJetzt.erinnerungen.some(
                    (e) => e.vertrag_id === vertrag.id && e.stichtag === stichtag && e.vorlauf_tage === tage,
                );
                if (schonDa) continue;
                bestandJetzt.erinnerungen.push({
                    id: crypto.randomUUID(),
                    vertrag_id: vertrag.id,
                    stichtag,
                    vorlauf_tage: tage,
                    faellig_am: faellig,
                    erzeugt_am: new Date().toISOString(),
                    versendet_am: null,
                    erledigt_am: null,
                    bezeichnung: vertrag.bezeichnung,
                    anbieter: vertrag.anbieter,
                    kategorie: vertrag.kategorie,
                });
                neue.push({ vertrag, stichtag, tageBisStichtag: tageBis(basis, stichtag), vorlauf: tage });
            }
        }

        if (neue.length > 0) {
            const jeVertrag = new Map<string, (typeof neue)[number]>();
            for (const eintrag of neue) {
                const bisher = jeVertrag.get(eintrag.vertrag.id);
                if (!bisher || eintrag.vorlauf < bisher.vorlauf) jeVertrag.set(eintrag.vertrag.id, eintrag);
            }
            const mail = baueSammelmail(
                bestandJetzt.organisation.name,
                [...jeVertrag.values()].sort((a, b) => a.tageBisStichtag - b.tageBisStichtag),
                window.location.origin,
            );
            bestandJetzt.postausgang.unshift({
                id: crypto.randomUUID(),
                empfaenger: ["anna@beispiel.de", ...bestandJetzt.organisation.verteiler].join(", "),
                betreff: mail.betreff,
                inhalt: mail.inhalt,
                erzeugt_am: new Date().toISOString(),
                versendet_am: null,
                fehler: null,
            });
        }
        // Von einer dringlicheren Stufe überholte Erinnerungen schließen.
        for (const erinnerung of bestandJetzt.erinnerungen) {
            if (erinnerung.erledigt_am) continue;
            const juengere = bestandJetzt.erinnerungen.some(
                (andere) =>
                    !andere.erledigt_am &&
                    andere.vertrag_id === erinnerung.vertrag_id &&
                    andere.stichtag === erinnerung.stichtag &&
                    andere.vorlauf_tage < erinnerung.vorlauf_tage,
            );
            if (juengere) erinnerung.erledigt_am = new Date().toISOString();
        }
        sichere();
        return {
            geprueft: bestandJetzt.vertraege.filter((v) => v.status === "aktiv").length,
            neueErinnerungen: neue.length,
            versendeteMails: 0,
        };
    },

    async organisationSpeichern(angaben) {
        const organisation = daten().organisation;
        organisation.name = angaben.name;
        organisation.erinnerungsvorlauf = [...new Set(angaben.erinnerungsvorlauf)].sort((a, b) => b - a);
        organisation.verteiler = angaben.verteiler;
        sichere();
        return organisation;
    },

    async kalenderErneuern() {
        return { kalenderAdresse: "" };
    },

    async demodaten() {
        const jetzt = new Date().toISOString();
        const neu = beispielvertraege(heute()).map((vertrag) => ({
            ...vertrag,
            id: crypto.randomUUID(),
            organisationId: "demo",
            erstelltAm: jetzt,
            geaendertAm: jetzt,
        }));
        daten().vertraege.push(...neu);
        sichere();
        return { angelegt: neu.length };
    },

    async csv() {
        return baueCsv(daten().vertraege, heute());
    },
};
