import { useEffect, useState } from "react";
import { PREISSTAND } from "../../fachlogik/skus.ts";
import { api, type Fehler, type Preiszeile } from "../api.ts";
import type { Werkzeug } from "../App.tsx";

export function Preise({ werkzeug }: { werkzeug: Werkzeug }) {
    const [preise, setPreise] = useState<Preiszeile[] | null>(null);
    const [entwurf, setEntwurf] = useState<Record<string, string>>({});
    const [meldung, setMeldung] = useState<string | null>(null);
    const [fehler, setFehler] = useState<string | null>(null);
    const darfAendern = werkzeug.anmeldung.benutzer.rolle === "inhaber";

    useEffect(() => {
        void api.preise(werkzeug.mandant.id).then(({ preise: liste }) => {
            setPreise(liste);
            setEntwurf(
                Object.fromEntries(
                    liste
                        .filter((p) => p.eigenCent !== null)
                        .map((p) => [p.sku, (p.eigenCent! / 100).toFixed(2)]),
                ),
            );
        });
    }, [werkzeug.mandant.id]);

    if (!preise) return <p className="lade">Preise werden geladen …</p>;

    async function speichern() {
        setFehler(null);
        setMeldung(null);
        const gesetzt = Object.entries(entwurf)
            .map(([sku, wert]) => ({ sku, cent: Math.round(Number(wert.replace(",", ".")) * 100) }))
            .filter((p) => Number.isFinite(p.cent) && p.cent > 0);
        try {
            await api.preiseSpeichern(werkzeug.mandant.id, gesetzt);
            setMeldung(
                `${gesetzt.length} eigene Preise gespeichert. Sie gelten ab der nächsten Auswertung.`,
            );
        } catch (problem) {
            setFehler((problem as Fehler).message);
        }
    }

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Preise</h1>
                    <p>
                        Kaum ein Unternehmen zahlt Listenpreis. Tragen Sie hier ein, was Sie
                        tatsächlich je Platz und Monat zahlen — der Lotse rechnet die Ersparnis
                        dann mit Ihren Zahlen statt mit Richtwerten.
                    </p>
                </div>
                {darfAendern ? (
                    <button type="button" className="knopf haupt" onClick={() => void speichern()}>
                        Preise speichern
                    </button>
                ) : null}
            </header>

            {meldung ? (
                <div className="hinweisleiste">
                    <p>{meldung}</p>
                </div>
            ) : null}
            {fehler ? <p className="fehlerleiste">{fehler}</p> : null}
            {!darfAendern ? (
                <div className="hinweisleiste">
                    <p>Preise ändern darf nur der Inhaber des Kontos.</p>
                </div>
            ) : null}

            <section className="karte">
                <div className="karte-kopf">
                    <h2>Produkte</h2>
                    <span style={{ color: "var(--gedaempft)", fontSize: 13 }}>
                        Richtwerte: Listenpreise, Stand {PREISSTAND}
                    </span>
                </div>
                <div className="tabellenrahmen">
                    <table className="liste">
                        <thead>
                            <tr>
                                <th>Produkt</th>
                                <th>Kennung</th>
                                <th style={{ textAlign: "right" }}>Richtwert</th>
                                <th style={{ width: 180 }}>Ihr Preis (€/Monat)</th>
                            </tr>
                        </thead>
                        <tbody>
                            {preise.map((preis) => (
                                <tr key={preis.sku}>
                                    <td>{preis.name}</td>
                                    <td style={{ fontFamily: "var(--schrift-daten)", fontSize: 12, color: "var(--gedaempft)" }}>
                                        {preis.sku}
                                    </td>
                                    <td className="betrag" style={{ color: "var(--gedaempft)" }}>
                                        {(preis.katalogCent / 100).toFixed(2).replace(".", ",")} €
                                    </td>
                                    <td>
                                        <input
                                            type="text"
                                            inputMode="decimal"
                                            disabled={!darfAendern}
                                            value={entwurf[preis.sku] ?? ""}
                                            placeholder="Richtwert"
                                            onChange={(e) =>
                                                setEntwurf((bisher) => ({
                                                    ...bisher,
                                                    [preis.sku]: e.target.value,
                                                }))
                                            }
                                            style={{
                                                font: "inherit",
                                                fontFamily: "var(--schrift-daten)",
                                                padding: "5px 8px",
                                                border: "1px solid var(--linie-stark)",
                                                borderRadius: 5,
                                                background: "var(--flaeche)",
                                                color: "var(--tinte)",
                                                width: "100%",
                                            }}
                                        />
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </section>
        </>
    );
}
