import { z } from "zod";
import { BEFUND_STATUS } from "../fachlogik/typen.ts";

const text = (max: number) => z.string().trim().max(max);

export const registrierungSchema = z.object({
    organisation: text(120).min(2, "Name der Organisation fehlt"),
    name: text(120).min(2, "Bitte einen Namen angeben"),
    email: z.email("Bitte eine gültige E-Mail-Adresse angeben"),
    kennwort: z.string().min(12, "Das Kennwort braucht mindestens 12 Zeichen").max(200),
});

export const anmeldungSchema = z.object({
    email: z.email("Bitte eine gültige E-Mail-Adresse angeben"),
    kennwort: z.string().min(1, "Kennwort fehlt"),
});

export const mandantSchema = z.object({
    name: text(120).min(2, "Name fehlt"),
    notiz: text(500).default(""),
});

export const standSchema = z.object({
    status: z.enum(BEFUND_STATUS),
    notiz: text(500).default(""),
});

export const preiseSchema = z.object({
    preise: z
        .array(
            z.object({
                sku: text(80).min(1),
                cent: z.number().int().min(0).max(1_000_000),
            }),
        )
        .max(200),
});

export const einladungSchema = z.object({
    name: text(120).min(2, "Bitte einen Namen angeben"),
    email: z.email("Bitte eine gültige E-Mail-Adresse angeben"),
    kennwort: z.string().min(12, "Das Kennwort braucht mindestens 12 Zeichen").max(200),
    rolle: z.enum(["inhaber", "mitglied"]).default("mitglied"),
});

export function felderfehler(fehler: z.ZodError): Record<string, string> {
    const felder: Record<string, string> = {};
    for (const problem of fehler.issues) {
        const feld = problem.path.join(".") || "_";
        felder[feld] ??= problem.message;
    }
    return felder;
}
