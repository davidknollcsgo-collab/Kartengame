import { useEffect, useState, type FormEvent } from "react";
import { euro } from "../../fachlogik/formate.ts";
import { api, type Fehler, type Mandant } from "../api.ts";
import type { Werkzeug } from "../App.tsx";

export function Verwaltung({ werkzeug, mandanten }: { werkzeug: Werkzeug; mandanten: Mandant[] }) {
    const darfAendern = werkzeug.anmeldung.benutzer.rolle === "inhaber";
    const [benutzer, setBenutzer] = useState<
        { id: string; name: string; email: string; rolle: string }[]
    >([]);
    const [verlauf, setVerlauf] = useState<
        { id: string; aktion: string; beschreibung: string; zeitpunkt: string }[]
    >([]);
    const [meldung, setMeldung] = useState<string | null>(null);
    const [fehler, setFehler] = useState<string | null>(null);
    const [felder, setFelder] = useState<Record<string, string>>({});

    async function laden() {
        const [b, v] = await Promise.all([api.benutzer(), api.verlauf()]);
        setBenutzer(b.benutzer);
        setVerlauf(v.verlauf);
    }

    useEffect(() => {
        void laden();
    }, []);

    async function mandantAnlegen(ereignis: FormEvent<HTMLFormElement>) {
        ereignis.preventDefault();
        const formular = new FormData(ereignis.currentTarget);
        setFehler(null);
        try {
            await api.mandantAnlegen(String(formular.get("name") ?? ""), String(formular.get("notiz") ?? ""));
            await werkzeug.mandantenNeuLaden();
            ereignis.currentTarget.reset();
            setMeldung("Mandant angelegt.");
        } catch (problem) {
            setFehler((problem as Fehler).message);
        }
    }

    async function benutzerAnlegen(ereignis: FormEvent<HTMLFormElement>) {
        ereignis.preventDefault();
        const formular = new FormData(ereignis.currentTarget);
        setFehler(null);
        setFelder({});
        try {
            await api.benutzerAnlegen({
                name: String(formular.get("name") ?? ""),
                email: String(formular.get("email") ?? ""),
                kennwort: String(formular.get("kennwort") ?? ""),
                rolle: String(formular.get("rolle") ?? "mitglied"),
            });
            ereignis.currentTarget.reset();
            await laden();
            setMeldung("Konto angelegt. Das Kennwort bitte persönlich weitergeben.");
        } catch (problem) {
            const f = problem as Fehler;
            setFehler(f.message);
            setFelder(f.felder ?? {});
        }
    }

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Verwaltung</h1>
                    <p>Mandanten, Zugänge und was im Konto geschehen ist.</p>
                </div>
            </header>

            {meldung ? (
                <div className="hinweisleiste">
                    <p>{meldung}</p>
                </div>
            ) : null}
            {fehler ? <p className="fehlerleiste">{fehler}</p> : null}

            <div className="stapel">
                <section className="karte">
                    <div className="karte-kopf">
                        <h2>Mandanten</h2>
                        <span style={{ color: "var(--gedaempft)", fontSize: 13.5 }}>
                            {mandanten.length} verwaltet
                        </span>
                    </div>
                    <div className="tabellenrahmen">
                        <table className="liste">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Letzte Auswertung</th>
                                    <th style={{ textAlign: "right" }}>Lizenzkosten/Monat</th>
                                    <th style={{ textAlign: "right" }}>Potenzial/Monat</th>
                                </tr>
                            </thead>
                            <tbody>
                                {mandanten.map((mandant) => (
                                    <tr key={mandant.id}>
                                        <td>
                                            <strong>{mandant.name}</strong>
                                            {mandant.notiz ? (
                                                <div style={{ color: "var(--gedaempft)", fontSize: 12.5 }}>
                                                    {mandant.notiz}
                                                </div>
                                            ) : null}
                                        </td>
                                        <td style={{ color: "var(--gedaempft)" }}>
                                            {mandant.letzte_auswertung
                                                ? new Date(mandant.letzte_auswertung).toLocaleDateString("de-DE")
                                                : "noch keine"}
                                        </td>
                                        <td className="betrag" style={{ color: "var(--gedaempft)" }}>
                                            {mandant.lizenzkosten_cent ? euro(mandant.lizenzkosten_cent) : "–"}
                                        </td>
                                        <td className="betrag">
                                            {mandant.ersparnis_cent ? euro(mandant.ersparnis_cent) : "–"}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                    {darfAendern ? (
                        <div className="karte-koerper" style={{ borderTop: "1px solid var(--linie)" }}>
                            <form onSubmit={mandantAnlegen} className="feldgruppe" style={{ alignItems: "end" }}>
                                <div className="feld">
                                    <label htmlFor="m-name">Neuer Mandant</label>
                                    <input id="m-name" name="name" required placeholder="Kundenname" />
                                </div>
                                <div className="feld">
                                    <label htmlFor="m-notiz">Notiz</label>
                                    <input id="m-notiz" name="notiz" placeholder="optional" />
                                </div>
                                <button type="submit" className="knopf haupt">
                                    Anlegen
                                </button>
                            </form>
                        </div>
                    ) : null}
                </section>

                <section className="karte">
                    <div className="karte-kopf">
                        <h2>Zugänge</h2>
                    </div>
                    <div className="tabellenrahmen">
                        <table className="liste">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>E-Mail</th>
                                    <th>Rolle</th>
                                </tr>
                            </thead>
                            <tbody>
                                {benutzer.map((person) => (
                                    <tr key={person.id}>
                                        <td>{person.name}</td>
                                        <td style={{ color: "var(--gedaempft)" }}>{person.email}</td>
                                        <td>
                                            <span className="marke">
                                                {person.rolle === "inhaber" ? "Inhaber" : "Mitglied"}
                                            </span>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                    {darfAendern ? (
                        <div className="karte-koerper" style={{ borderTop: "1px solid var(--linie)" }}>
                            <p style={{ marginTop: 0, color: "var(--gedaempft)", fontSize: 13.5 }}>
                                Mitglieder dürfen Auswertungen ansehen und Befunde abhaken, aber keine
                                Preise, Mandanten oder Zugänge ändern.
                            </p>
                            <form onSubmit={benutzerAnlegen} className="feldgruppe" style={{ alignItems: "end" }}>
                                <div className={`feld${felder["name"] ? " falsch" : ""}`}>
                                    <label htmlFor="b-name">Name</label>
                                    <input id="b-name" name="name" required />
                                </div>
                                <div className={`feld${felder["email"] ? " falsch" : ""}`}>
                                    <label htmlFor="b-email">E-Mail</label>
                                    <input id="b-email" name="email" type="email" required />
                                    {felder["email"] ? <span className="meldung">{felder["email"]}</span> : null}
                                </div>
                                <div className={`feld${felder["kennwort"] ? " falsch" : ""}`}>
                                    <label htmlFor="b-kennwort">Erstes Kennwort</label>
                                    <input id="b-kennwort" name="kennwort" type="password" required />
                                    {felder["kennwort"] ? (
                                        <span className="meldung">{felder["kennwort"]}</span>
                                    ) : (
                                        <span className="hilfe">Mindestens 12 Zeichen.</span>
                                    )}
                                </div>
                                <div className="feld">
                                    <label htmlFor="b-rolle">Rolle</label>
                                    <select id="b-rolle" name="rolle" defaultValue="mitglied">
                                        <option value="mitglied">Mitglied</option>
                                        <option value="inhaber">Inhaber</option>
                                    </select>
                                </div>
                                <button type="submit" className="knopf haupt">
                                    Zugang anlegen
                                </button>
                            </form>
                        </div>
                    ) : null}
                </section>

                <section className="karte">
                    <div className="karte-kopf">
                        <h2>Verlauf</h2>
                        <span style={{ color: "var(--gedaempft)", fontSize: 13.5 }}>
                            Wer hat was geändert
                        </span>
                    </div>
                    <div className="tabellenrahmen">
                        <table className="liste">
                            <tbody>
                                {verlauf.slice(0, 30).map((eintrag) => (
                                    <tr key={eintrag.id}>
                                        <td
                                            style={{
                                                width: 150,
                                                fontFamily: "var(--schrift-daten)",
                                                fontSize: 12.5,
                                                color: "var(--gedaempft)",
                                                whiteSpace: "nowrap",
                                            }}
                                        >
                                            {new Date(eintrag.zeitpunkt).toLocaleString("de-DE", {
                                                dateStyle: "short",
                                                timeStyle: "short",
                                            })}
                                        </td>
                                        <td>{eintrag.beschreibung}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </section>
            </div>
        </>
    );
}
