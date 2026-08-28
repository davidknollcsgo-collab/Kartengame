import { useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { datumKurz, euro, kuendigungsregel, tageInWorten } from "../../fachlogik/formate.ts";
import { KATEGORIEN, KATEGORIE_TEXT, VERTRAGSSTATUS, VERTRAGSSTATUS_TEXT } from "../../fachlogik/typen.ts";
import { api } from "../api.ts";
import { Laedt, Leerzustand, Plakette } from "../teile/bausteine.tsx";
import type { VertragMitFristen } from "../typen.ts";

export function Vertragsliste() {
    const [suchparameter, setSuchparameter] = useSearchParams();
    const [vertraege, setVertraege] = useState<VertragMitFristen[] | null>(null);
    const [csv, setCsv] = useState<string | null>(null);

    const suche = suchparameter.get("suche") ?? "";
    const kategorie = suchparameter.get("kategorie") ?? "";
    const status = suchparameter.get("status") ?? "";
    const ampel = suchparameter.get("ampel") ?? "";

    useEffect(() => {
        let abgebrochen = false;
        void api.vertraege({ suche, kategorie, status, ampel }).then((antwort) => {
            if (!abgebrochen) setVertraege(antwort.vertraege);
        });
        return () => {
            abgebrochen = true;
        };
    }, [suche, kategorie, status, ampel]);

    function setze(feld: string, wert: string) {
        const naechste = new URLSearchParams(suchparameter);
        if (wert) naechste.set(feld, wert);
        else naechste.delete(feld);
        setSuchparameter(naechste, { replace: true });
    }

    const summe = (vertraege ?? [])
        .filter((v) => v.status === "aktiv")
        .reduce((wert, v) => wert + v.jahreskostenCent, 0);

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Verträge</h1>
                    <p>
                        {vertraege
                            ? `${vertraege.length} Verträge, zusammen ${euro(summe)} im Jahr`
                            : "Wird geladen …"}
                    </p>
                </div>
                <div className="knopfreihe">
                    <button
                        type="button"
                        className="knopf"
                        onClick={async () => {
                            const inhalt = await api.csv();
                            if (api.demo) {
                                setCsv(inhalt);
                                return;
                            }
                            const adresse = URL.createObjectURL(
                                new Blob([inhalt], { type: "text/csv;charset=utf-8" }),
                            );
                            const verweis = document.createElement("a");
                            verweis.href = adresse;
                            verweis.download = "vertraege.csv";
                            verweis.click();
                            URL.revokeObjectURL(adresse);
                        }}
                    >
                        Als CSV
                    </button>
                    <Link className="knopf haupt" to="/vertraege/neu">
                        Vertrag anlegen
                    </Link>
                </div>
            </header>

            <div className="werkzeugleiste">
                <input
                    type="search"
                    placeholder="Suchen in Bezeichnung, Anbieter, Nummer, Notizen"
                    value={suche}
                    onChange={(e) => setze("suche", e.target.value)}
                />
                <select value={kategorie} onChange={(e) => setze("kategorie", e.target.value)}>
                    <option value="">Alle Kategorien</option>
                    {KATEGORIEN.map((k) => (
                        <option key={k} value={k}>
                            {KATEGORIE_TEXT[k]}
                        </option>
                    ))}
                </select>
                <select value={status} onChange={(e) => setze("status", e.target.value)}>
                    <option value="">Jeder Status</option>
                    {VERTRAGSSTATUS.map((s) => (
                        <option key={s} value={s}>
                            {VERTRAGSSTATUS_TEXT[s]}
                        </option>
                    ))}
                </select>
                <select value={ampel} onChange={(e) => setze("ampel", e.target.value)}>
                    <option value="">Jede Dringlichkeit</option>
                    <option value="kritisch">Frist läuft ab</option>
                    <option value="warnung">Bald handeln</option>
                    <option value="hinweis">In Sicht</option>
                    <option value="ok">Alles ruhig</option>
                    <option value="jederzeit">Jederzeit kündbar</option>
                </select>
                {suche || kategorie || status || ampel ? (
                    <button
                        type="button"
                        className="knopf leise"
                        onClick={() => setSuchparameter(new URLSearchParams(), { replace: true })}
                    >
                        Filter zurücksetzen
                    </button>
                ) : null}
            </div>

            {!vertraege ? (
                <Laedt />
            ) : vertraege.length === 0 ? (
                <div className="karte">
                    <Leerzustand
                        titel="Kein Vertrag passt dazu"
                        text="Ändern Sie die Filter oder legen Sie einen neuen Vertrag an."
                        aktion={
                            <Link className="knopf haupt" to="/vertraege/neu">
                                Vertrag anlegen
                            </Link>
                        }
                    />
                </div>
            ) : (
                <div className="tabellenrahmen">
                    <table className="liste">
                        <thead>
                            <tr>
                                <th>Vertrag</th>
                                <th>Kündigungsfrist</th>
                                <th>Stichtag</th>
                                <th>Verbleibend</th>
                                <th style={{ textAlign: "right" }}>Kosten/Jahr</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {vertraege.map((vertrag) => (
                                <tr key={vertrag.id} className={`ampel-${vertrag.ampel}`}>
                                    <td>
                                        <Link className="vertragsname" to={`/vertraege/${vertrag.id}`}>
                                            {vertrag.bezeichnung}
                                        </Link>
                                        <div className="nebenzeile">
                                            {[vertrag.anbieter, KATEGORIE_TEXT[vertrag.kategorie], vertrag.abteilung]
                                                .filter(Boolean)
                                                .join(" · ")}
                                        </div>
                                    </td>
                                    <td className="nebenzeile">
                                        {kuendigungsregel(vertrag)}
                                    </td>
                                    <td className="datum">{datumKurz(vertrag.fristen.stichtag)}</td>
                                    <td className="datum">
                                        <span className="rest">
                                            {vertrag.fristen.tageBisStichtag === null
                                                ? "—"
                                                : tageInWorten(vertrag.fristen.tageBisStichtag)}
                                        </span>
                                    </td>
                                    <td className="zahl">{euro(vertrag.jahreskostenCent)}</td>
                                    <td>
                                        <Plakette ampel={vertrag.ampel} />
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {csv !== null ? (
                <div className="schleier" onClick={() => setCsv(null)}>
                    <div className="dialog" onClick={(e) => e.stopPropagation()}>
                        <h2>Ausgabe als CSV</h2>
                        <p style={{ margin: 0, fontSize: 13.5, color: "var(--gedaempft)" }}>
                            In der Demo kann die Seite keine Datei speichern. Der Inhalt lässt sich
                            kopieren und in Excel einfügen — mit Semikolon als Trennzeichen.
                        </p>
                        <pre>{csv}</pre>
                        <div className="knopfreihe">
                            <button
                                type="button"
                                className="knopf haupt"
                                onClick={() => void navigator.clipboard?.writeText(csv)}
                            >
                                In die Zwischenablage
                            </button>
                            <button type="button" className="knopf leise" onClick={() => setCsv(null)}>
                                Schließen
                            </button>
                        </div>
                    </div>
                </div>
            ) : null}
        </>
    );
}
