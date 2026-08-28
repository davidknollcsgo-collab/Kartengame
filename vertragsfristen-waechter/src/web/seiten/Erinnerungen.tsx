import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { datumKurz, tageInWorten } from "../../fachlogik/formate.ts";
import { tageBis } from "../../fachlogik/datum.ts";
import { api } from "../api.ts";
import { Karte, Laedt, Leerzustand } from "../teile/bausteine.tsx";
import type { Erinnerung, Nachricht } from "../typen.ts";

export function Erinnerungen({ aktualisiert }: { aktualisiert: () => Promise<void> }) {
    const [erinnerungen, setErinnerungen] = useState<Erinnerung[] | null>(null);
    const [nachrichten, setNachrichten] = useState<Nachricht[]>([]);
    const [smtp, setSmtp] = useState(true);
    const [heute, setHeute] = useState("");
    const [offen, setOffen] = useState<Nachricht | null>(null);

    async function laden() {
        const [liste, post] = await Promise.all([api.erinnerungen(), api.postausgang()]);
        setErinnerungen(liste.erinnerungen);
        setHeute(liste.heute);
        setNachrichten(post.nachrichten);
        setSmtp(post.smtpEingerichtet);
        await aktualisiert();
    }

    useEffect(() => {
        void laden();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    if (!erinnerungen) return <Laedt />;

    const offeneErinnerungen = erinnerungen.filter((e) => !e.erledigt_am);
    const erledigte = erinnerungen.filter((e) => e.erledigt_am);

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Erinnerungen</h1>
                    <p>
                        Der Fristenlauf prüft täglich alle aktiven Verträge und meldet jede Frist,
                        die in den eingestellten Vorlauf rutscht.
                    </p>
                </div>
                <button
                    type="button"
                    className="knopf"
                    onClick={async () => {
                        await api.fristenlauf();
                        void laden();
                    }}
                >
                    Fristenlauf jetzt ausführen
                </button>
            </header>

            {!smtp ? (
                <div className="hinweisleiste warnend">
                    <p>
                        Es ist kein Mailversand eingerichtet. Erinnerungen werden erzeugt und unten
                        im Postausgang abgelegt, aber nicht verschickt — dafür{" "}
                        <code>SMTP_URL</code> setzen.
                    </p>
                </div>
            ) : null}

            <div className="stapel">
                <Karte titel={`Offen (${offeneErinnerungen.length})`} ohnePolster>
                    {offeneErinnerungen.length === 0 ? (
                        <Leerzustand
                            titel="Nichts zu tun"
                            text="Keine Frist ist derzeit im Vorlauf. Sobald sich das ändert, steht sie hier."
                        />
                    ) : (
                        <div className="tabellenrahmen blank">
                            <table className="liste">
                                <thead>
                                    <tr>
                                        <th>Vertrag</th>
                                        <th>Stichtag</th>
                                        <th>Verbleibend</th>
                                        <th>Ausgelöst</th>
                                        <th />
                                    </tr>
                                </thead>
                                <tbody>
                                    {offeneErinnerungen.map((erinnerung) => {
                                        const rest = heute ? tageBis(heute, erinnerung.stichtag) : null;
                                        const stufe =
                                            rest === null ? "hinweis" : rest <= 14 ? "kritisch" : rest <= 45 ? "warnung" : "hinweis";
                                        return (
                                            <tr key={erinnerung.id} className={`ampel-${stufe}`}>
                                                <td>
                                                    <Link
                                                        className="vertragsname"
                                                        to={`/vertraege/${erinnerung.vertrag_id}`}
                                                    >
                                                        {erinnerung.bezeichnung}
                                                    </Link>
                                                    <div className="nebenzeile">{erinnerung.anbieter}</div>
                                                </td>
                                                <td className="datum">{datumKurz(erinnerung.stichtag)}</td>
                                                <td className="datum">
                                                    <span className="rest">{tageInWorten(rest)}</span>
                                                </td>
                                                <td className="datum nebenzeile">
                                                    {datumKurz(erinnerung.faellig_am)} ·{" "}
                                                    {erinnerung.vorlauf_tage} Tage Vorlauf
                                                </td>
                                                <td>
                                                    <button
                                                        type="button"
                                                        className="knopf leise"
                                                        onClick={async () => {
                                                            await api.erinnerungErledigt(erinnerung.id);
                                                            void laden();
                                                        }}
                                                    >
                                                        Erledigt
                                                    </button>
                                                </td>
                                            </tr>
                                        );
                                    })}
                                </tbody>
                            </table>
                        </div>
                    )}
                </Karte>

                <Karte titel={`Postausgang (${nachrichten.length})`}>
                    {nachrichten.length === 0 ? (
                        <p className="nebenzeile" style={{ margin: 0 }}>
                            Noch keine Erinnerungsmail erzeugt.
                        </p>
                    ) : (
                        <ul className="zeitleiste">
                            {nachrichten.map((nachricht) => (
                                <li key={nachricht.id}>
                                    <time>{datumKurz(nachricht.erzeugt_am.slice(0, 10))}</time>
                                    <span>
                                        <button
                                            type="button"
                                            className="knopf leise"
                                            style={{ padding: 0, textAlign: "left" }}
                                            onClick={() => setOffen(nachricht)}
                                        >
                                            {nachricht.betreff}
                                        </button>
                                        <div className="nebenzeile">
                                            an {nachricht.empfaenger} ·{" "}
                                            {nachricht.fehler
                                                ? `Fehler: ${nachricht.fehler}`
                                                : nachricht.versendet_am
                                                  ? "versendet"
                                                  : "nicht versendet"}
                                        </div>
                                    </span>
                                </li>
                            ))}
                        </ul>
                    )}
                </Karte>

                {erledigte.length > 0 ? (
                    <Karte titel={`Erledigt (${erledigte.length})`}>
                        <ul className="zeitleiste">
                            {erledigte.slice(0, 20).map((erinnerung) => (
                                <li key={erinnerung.id}>
                                    <time>{datumKurz(erinnerung.stichtag)}</time>
                                    <span>
                                        <Link to={`/vertraege/${erinnerung.vertrag_id}`}>
                                            {erinnerung.bezeichnung}
                                        </Link>
                                        <span className="nebenzeile"> · {erinnerung.vorlauf_tage} Tage Vorlauf</span>
                                    </span>
                                </li>
                            ))}
                        </ul>
                    </Karte>
                ) : null}
            </div>

            {offen ? (
                <div className="schleier" onClick={() => setOffen(null)}>
                    <div className="dialog" onClick={(e) => e.stopPropagation()}>
                        <h2>{offen.betreff}</h2>
                        <p className="nebenzeile" style={{ margin: 0 }}>an {offen.empfaenger}</p>
                        <pre>{offen.inhalt}</pre>
                        <button type="button" className="knopf leise" onClick={() => setOffen(null)}>
                            Schließen
                        </button>
                    </div>
                </div>
            ) : null}
        </>
    );
}
