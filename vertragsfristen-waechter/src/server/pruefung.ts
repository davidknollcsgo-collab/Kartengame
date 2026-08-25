// Eingabeprüfung an der Schnittstelle. Alles, was von außen kommt, geht durch
// diese Schemata — die Fachlogik darf sich auf saubere Werte verlassen.

import { z } from "zod";
import { istIsoDatum } from "../fachlogik/datum.ts";
import {
    FRISTBEZUEGE,
    FRISTEINHEITEN,
    KATEGORIEN,
    LAUFZEITMODELLE,
    VERTRAGSSTATUS,
    ZAHLUNGSINTERVALLE,
} from "../fachlogik/typen.ts";

const datum = z.string().refine(istIsoDatum, "Datum im Format JJJJ-MM-TT erwartet");
const text = (max: number) => z.string().trim().max(max);

export const anmeldungSchema = z.object({
    email: z.email("Bitte eine gültige E-Mail-Adresse angeben"),
    kennwort: z.string().min(1, "Kennwort fehlt"),
});

export const registrierungSchema = z.object({
    organisation: text(120).min(2, "Name der Organisation fehlt"),
    name: text(120).min(2, "Bitte einen Namen angeben"),
    email: z.email("Bitte eine gültige E-Mail-Adresse angeben"),
    kennwort: z.string().min(10, "Das Kennwort braucht mindestens 10 Zeichen").max(200),
});

export const vertragSchema = z
    .object({
        bezeichnung: text(160).min(2, "Bezeichnung fehlt"),
        anbieter: text(160).default(""),
        kategorie: z.enum(KATEGORIEN).default("sonstiges"),
        vertragsnummer: text(80).default(""),
        abteilung: text(80).default(""),
        ansprechpartner: text(160).default(""),
        beginn: datum,
        laufzeitmodell: z.enum(LAUFZEITMODELLE),
        erstlaufzeitMonate: z.number().int().min(0).max(600).default(0),
        verlaengerungMonate: z.number().int().min(0).max(600).default(0),
        kuendigungsfristWert: z.number().int().min(0).max(999).default(0),
        kuendigungsfristEinheit: z.enum(FRISTEINHEITEN).default("monate"),
        kuendigungsfristBezug: z.enum(FRISTBEZUEGE).default("zum_laufzeitende"),
        betragCent: z.number().int().min(0).max(1_000_000_000).default(0),
        zahlungsintervall: z.enum(ZAHLUNGSINTERVALLE).default("jaehrlich"),
        status: z.enum(VERTRAGSSTATUS).default("aktiv"),
        gekuendigtZum: datum.nullable().default(null),
        dokumentLink: text(500).default(""),
        notizen: text(4000).default(""),
    })
    .superRefine((wert, ctx) => {
        if (wert.laufzeitmodell === "befristet_ohne_verlaengerung" && wert.erstlaufzeitMonate < 1) {
            ctx.addIssue({
                code: "custom",
                path: ["erstlaufzeitMonate"],
                message: "Ein befristeter Vertrag braucht eine Laufzeit in Monaten",
            });
        }
        if (wert.laufzeitmodell === "befristet_mit_verlaengerung") {
            if (wert.erstlaufzeitMonate < 1) {
                ctx.addIssue({
                    code: "custom",
                    path: ["erstlaufzeitMonate"],
                    message: "Ein befristeter Vertrag braucht eine Laufzeit in Monaten",
                });
            }
            if (wert.verlaengerungMonate < 1) {
                ctx.addIssue({
                    code: "custom",
                    path: ["verlaengerungMonate"],
                    message: "Bitte angeben, um wie viele Monate sich der Vertrag verlängert",
                });
            }
        }
        if (wert.status === "gekuendigt" && !wert.gekuendigtZum) {
            ctx.addIssue({
                code: "custom",
                path: ["gekuendigtZum"],
                message: "Bitte angeben, zu welchem Datum gekündigt wurde",
            });
        }
    });

export type VertragEingabe = z.infer<typeof vertragSchema>;

export const kuendigungSchema = z.object({
    gekuendigtZum: datum.nullable().default(null),
    notiz: text(500).default(""),
});

export const organisationSchema = z.object({
    name: text(120).min(2, "Name der Organisation fehlt"),
    erinnerungsvorlauf: z
        .array(z.number().int().min(0).max(365))
        .max(8, "Höchstens acht Erinnerungsstufen")
        .transform((liste) => [...new Set(liste)].sort((a, b) => b - a)),
    verteiler: z.array(z.email("Ungültige Adresse im Verteiler")).max(20).default([]),
});

/** Sammelt Zod-Fehler zu einem Feld-zu-Meldung-Verzeichnis für die Oberfläche. */
export function felderfehler(fehler: z.ZodError): Record<string, string> {
    const felder: Record<string, string> = {};
    for (const problem of fehler.issues) {
        const feld = problem.path.join(".") || "_";
        felder[feld] ??= problem.message;
    }
    return felder;
}
