import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { datumKurz, euro, tageInWorten } from "../../fachlogik/formate.ts";
import { KATEGORIE_TEXT, type Kategorie } from "../../fachlogik/typen.ts";
import { api } from "../api.ts";
import { Fristenband } from "../teile/Fristenband.tsx";
import { Karte, Kennzahl, Laedt, Leerzustand, Plakette } from "../teile/bausteine.tsx";
import type { Anmeldedaten, Uebersicht as Zahlen, VertragMitFristen } from "../typen.ts";

export function Uebersicht({ anmeldung }: { anmeldung: Anmeldedaten }) {
    const [zahlen, setZahlen] = useState<Zahlen | null>(null);
    const [alle, setAlle] = useState<VertragMitFristen[]>([]);
    const [laeuftFristenlauf, setLaeuftFristenlauf] = useState(false);
    const [meldung, setMeldung] = useState<string | null>(null);

    async function laden() {
        const [uebersicht, liste] = await Promise.all([api.uebersicht(), api.vertraege()]);
        setZahlen(uebersicht);
        setAlle(liste.vertraege);
    }

    useEffect(() => {
        void laden();
    }, []);

    if (!zahlen) return <Laedt was="Fristen werden gerechnet" />;

    const leer = zahlen.anzahlGesamt === 0;
    const kategorien = Object.entries(zahlen.nachKategorie).sort(
        (a, b) => b[1].jahreskostenCent - a[1].jahreskostenCent,
    );
    const groesste = Math.max(1, ...kategorien.map(([, wert]) => wert.jahreskostenCent));

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Übersicht</h1>
                    <p>
                        Stand {datumKurz(zahlen.heute)} — {anmeldung.organisation.name}
                    </p>
                </div>
                <div className="knopfreihe">
                    <button
                        type="button"
                        className="knopf"
                        disabled={laeuftFristenlauf}
                        onClick={async () => {
                            setLaeuftFristenlauf(true);
                            const ergebnis = await api.fristenlauf();
                            setMeldung(
                                ergebnis.neueErinnerungen === 0
                                    ? "Alles im Blick — heute ist keine neue Erinnerung fällig."
                                    : `${ergebnis.neueErinnerungen} neue Erinnerung(en) erzeugt.`,
                            );
                            setLaeuftFristenlauf(false);
                            void laden();
                        }}
                    >
                        Fristenlauf jetzt ausführen
                    </button>
                    <Link className="knopf haupt" to="/vertraege/neu">
                        Vertrag anlegen
                    </Link>
                </div>
            </header>

            {meldung ? (
                <div className="hinweisleiste">
                    <p>{meldung}</p>
                </div>
            ) : null}

            {leer ? (
                <div className="karte">
                    <Leerzustand
                        titel="Noch keine Verträge erfasst"
                        text="Legen Sie den ersten Vertrag an — oder laden Sie einen Beispielbestand, um zu sehen, wie der Wächter arbeitet."
                        aktion={
                            <div className="knopfreihe">
                                <Link className="knopf haupt" to="/vertraege/neu">
                                    Vertrag anlegen
                                </Link>
                                <button
                                    type="button"
                                    className="knopf"
                                    onClick={async () => {
                                        await api.demodaten();
                                        void laden();
                                    }}
                                >
                                    Beispieldaten laden
                                </button>
                            </div>
                        }
                    />
                </div>
            ) : (
                <>
                    <div className="kennzahlen">
                        <Kennzahl
                            beschriftung="Fristen in 30 Tagen"
                            wert={zahlen.fristenIn30}
                            fussnote={`${zahlen.fristenIn90} in den nächsten 90 Tagen`}
                            dringend={zahlen.nachAmpel.kritisch > 0}
                        />
                        <Kennzahl
                            beschriftung="Aktive Verträge"
                            wert={zahlen.anzahlAktiv}
                            fussnote={`${zahlen.anzahlGesamt} insgesamt erfasst`}
                        />
                        <Kennzahl
                            beschriftung="Kosten pro Jahr"
                            wert={euro(zahlen.jahreskostenCent)}
                            fussnote="hochgerechnet aus allen aktiven Verträgen"
                        />
                        <Kennzahl
                            beschriftung="Davon bald fällig"
                            wert={euro(zahlen.gefaehrdeteKostenCent)}
                            fussnote="Verträge, deren Frist in Sichtweite ist"
                        />
                    </div>

                    <div className="stapel">
                        <Karte titel="Die nächsten zwölf Monate">
                            <Fristenband
                                vertraege={alle.filter((v) => v.status === "aktiv")}
                                heute={zahlen.heute}
                            />
                        </Karte>

                        <div className="zweispaltig">
                            <Karte
                                titel="Als Nächstes fällig"
                                aktion={
                                    <Link className="knopf leise" to="/vertraege">
                                        Alle Verträge
                                    </Link>
                                }
                                ohnePolster
                            >
                                {zahlen.naechsteFristen.length === 0 ? (
                                    <Leerzustand
                                        titel="Keine offenen Fristen"
                                        text="Alle aktiven Verträge sind entweder jederzeit kündbar oder haben noch keinen Stichtag in Sicht."
                                    />
                                ) : (
                                    <div className="tabellenrahmen blank">
                                        <table className="liste eng">
                                            <thead>
                                                <tr>
                                                    <th>Vertrag</th>
                                                    <th>Stichtag</th>
                                                    <th>Verbleibend</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {zahlen.naechsteFristen.map((vertrag) => (
                                                    <tr key={vertrag.id} className={`ampel-${vertrag.ampel}`}>
                                                        <td>
                                                            <Link className="vertragsname" to={`/vertraege/${vertrag.id}`}>
                                                                {vertrag.bezeichnung}
                                                            </Link>
                                                            <div className="nebenzeile">
                                                                {vertrag.anbieter || KATEGORIE_TEXT[vertrag.kategorie]}
                                                            </div>
                                                        </td>
                                                        <td className="datum">
                                                            {datumKurz(vertrag.fristen.stichtag)}
                                                        </td>
                                                        <td className="datum">
                                                            <span className="rest">
                                                                {tageInWorten(vertrag.fristen.tageBisStichtag)}
                                                            </span>
                                                        </td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </Karte>

                            <div className="stapel">
                                <Karte titel="Kosten nach Kategorie">
                                    <ul className="balkenliste">
                                        {kategorien.map(([schluessel, wert]) => (
                                            <li key={schluessel}>
                                                <span>
                                                    {KATEGORIE_TEXT[schluessel as Kategorie] ?? schluessel}
                                                </span>
                                                <span className="zahl">{euro(wert.jahreskostenCent)}</span>
                                                <span className="schiene">
                                                    <span
                                                        style={{
                                                            width: `${Math.max(3, (wert.jahreskostenCent / groesste) * 100)}%`,
                                                        }}
                                                    />
                                                </span>
                                            </li>
                                        ))}
                                    </ul>
                                </Karte>

                                <Karte titel="Ampel">
                                    <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                                        {(
                                            [
                                                ["kritisch", "Frist läuft ab"],
                                                ["warnung", "Bald handeln"],
                                                ["hinweis", "In Sicht"],
                                                ["ok", "Alles ruhig"],
                                                ["jederzeit", "Jederzeit kündbar"],
                                                ["gekuendigt", "Gekündigt"],
                                            ] as const
                                        )
                                            .filter(([stufe]) => zahlen.nachAmpel[stufe] > 0)
                                            .map(([stufe, text]) => (
                                                <Link
                                                    key={stufe}
                                                    to={`/vertraege?ampel=${stufe}`}
                                                    style={{ textDecoration: "none" }}
                                                >
                                                    <Plakette
                                                        ampel={stufe}
                                                        text={`${zahlen.nachAmpel[stufe]} × ${text}`}
                                                    />
                                                </Link>
                                            ))}
                                    </div>
                                    {zahlen.offeneErinnerungen.anzahl > 0 ? (
                                        <p style={{ marginBottom: 0, marginTop: 14, fontSize: 13.5 }}>
                                            <Link to="/erinnerungen">
                                                {zahlen.offeneErinnerungen.anzahl} offene Erinnerung(en)
                                            </Link>{" "}
                                            warten auf Bearbeitung.
                                        </p>
                                    ) : null}
                                </Karte>
                            </div>
                        </div>
                    </div>
                </>
            )}
        </>
    );
}
