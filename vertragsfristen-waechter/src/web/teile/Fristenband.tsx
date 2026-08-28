// Zwölf Monate auf einen Blick: wo häufen sich die Stichtage? Jeder Punkt ist
// ein Vertrag, die Farbe zeigt die Dringlichkeit. Der laufende Monat ist
// hervorgehoben.

import { monatsErster, plusMonate, teile } from "../../fachlogik/datum.ts";
import type { VertragMitFristen } from "../typen.ts";

const MONATSKUERZEL = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"];

export function Fristenband({ vertraege, heute }: { vertraege: VertragMitFristen[]; heute: string }) {
    const monate = Array.from({ length: 12 }, (_, versatz) => {
        const monatsanfang = monatsErster(plusMonate(heute, versatz));
        const { jahr, monat } = teile(monatsanfang);
        const treffer = vertraege.filter(
            (vertrag) => vertrag.fristen.stichtag?.startsWith(monatsanfang.slice(0, 7)) ?? false,
        );
        return { monatsanfang, jahr, monat, treffer, jetzt: versatz === 0 };
    });
    const hoechste = Math.max(1, ...monate.map((m) => m.treffer.length));

    return (
        <div>
            <div className="band">
                {monate.map((monat) => (
                    <div
                        key={monat.monatsanfang}
                        className={`band-monat${monat.jetzt ? " jetzt" : ""}`}
                        title={
                            monat.treffer.length === 0
                                ? "keine Frist"
                                : monat.treffer.map((v) => v.bezeichnung).join(", ")
                        }
                    >
                        <div className="band-saeule">
                            {monat.treffer.slice(0, 6).map((vertrag) => (
                                <span key={vertrag.id} className={`band-punkt ampel-${vertrag.ampel}`} />
                            ))}
                        </div>
                        <span className="beschriftung">
                            {MONATSKUERZEL[monat.monat - 1]}
                            {monat.monat === 1 || monat.jetzt ? ` ${String(monat.jahr).slice(2)}` : ""}
                        </span>
                    </div>
                ))}
            </div>
            <p className="nebenzeile" style={{ marginBottom: 0, marginTop: 10 }}>
                {hoechste === 1
                    ? "Ein Punkt je Vertrag, gesetzt auf den Monat des Kündigungsstichtags."
                    : `Ein Punkt je Vertrag. Am dichtesten ist ${
                          MONATSKUERZEL[(monate.find((m) => m.treffer.length === hoechste)?.monat ?? 1) - 1]
                      } mit ${hoechste} Fristen.`}
            </p>
        </div>
    );
}
