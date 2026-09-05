import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { euro, euroKurz } from "../../fachlogik/formate.ts";
import { BEFUNDART_TEXT, type Befundart } from "../../fachlogik/typen.ts";
import { api, type Befundzeile, type Uebersicht as Daten } from "../api.ts";
import type { Werkzeug } from "../App.tsx";

export function Uebersicht({ werkzeug }: { werkzeug: Werkzeug }) {
    const [daten, setDaten] = useState<Daten | null>(null);
    const [suche, setSuche] = useState("");
    const [art, setArt] = useState("");
    const [sicherheit, setSicherheit] = useState("");
    const [status, setStatus] = useState("offen");
    const [offenerBefund, setOffenerBefund] = useState<string | null>(null);
    const [laeuft, setLaeuft] = useState(false);

    const mandantId = werkzeug.mandant.id;

    async function laden() {
        setDaten(await api.uebersicht(mandantId));
    }

    useEffect(() => {
        setDaten(null);
        void api.uebersicht(mandantId).then(setDaten);
    }, [mandantId]);

    const gefiltert = useMemo(() => {
        if (!daten) return [];
        const text = suche.trim().toLowerCase();
        return daten.befunde.filter((b) => {
            if (art && b.art !== art) return false;
            if (sicherheit && b.sicherheit !== sicherheit) return false;
            if (status && b.status !== status) return false;
            if (text && ![b.titel, b.upn ?? "", b.begruendung].join(" ").toLowerCase().includes(text)) {
                return false;
            }
            return true;
        });
    }, [daten, suche, art, sicherheit, status]);

    if (!daten) return <p className="lade">Auswertung wird geladen …</p>;

    if (!daten.auswertung) {
        return (
            <div className="karte">
                <div className="leerzustand">
                    <h3>Für {werkzeug.mandant.name} liegt noch keine Auswertung vor</h3>
                    <p>
                        Lesen Sie die drei Ausgaben aus dem Microsoft-365-Adminportal ein — oder
                        sehen Sie sich zuerst an einem Beispielbestand an, was der Lotse findet.
                    </p>
                    <div className="knopfreihe">
                        <Link className="knopf haupt" to="/import">
                            Daten einlesen
                        </Link>
                        <button
                            type="button"
                            className="knopf"
                            disabled={laeuft}
                            onClick={async () => {
                                setLaeuft(true);
                                await api.demodaten(mandantId);
                                await laden();
                                await werkzeug.mandantenNeuLaden();
                                setLaeuft(false);
                            }}
                        >
                            Beispielbestand auswerten
                        </button>
                    </div>
                </div>
            </div>
        );
    }

    const { auswertung, kennzahlen } = daten;
    const offenCent = kennzahlen?.offenCent ?? auswertung.ersparnis_cent;
    const sicherAnteil = auswertung.ersparnis_cent
        ? (auswertung.ersparnis_sicher_cent / auswertung.ersparnis_cent) * 100
        : 0;

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>{werkzeug.mandant.name}</h1>
                    <p>
                        Auswertung vom {new Date(auswertung.erstellt_am).toLocaleDateString("de-DE")} ·{" "}
                        {auswertung.anzahl_konten} Konten · {auswertung.anzahl_zuweisungen} Lizenzzuweisungen
                        {auswertung.quelle === "demo" ? " · Beispielbestand" : ""}
                    </p>
                </div>
                <div className="knopfreihe">
                    <a className="knopf" href={`/api/mandanten/${mandantId}/export.csv`}>
                        Bericht als CSV
                    </a>
                    <Link className="knopf haupt" to="/import">
                        Neu einlesen
                    </Link>
                </div>
            </header>

            {auswertung.warnungen.length > 0 ? (
                <div className="hinweisleiste warnend">
                    <div>
                        <p>
                            <strong>Der Bestand ist unvollständig</strong> — die Zahlen unten sind
                            damit eher zu niedrig als zu hoch:
                        </p>
                        <ul>
                            {auswertung.warnungen.map((warnung) => (
                                <li key={warnung}>{warnung}</li>
                            ))}
                        </ul>
                    </div>
                </div>
            ) : null}

            <section className="befundtafel">
                <div>
                    <span className="beschriftung">Offenes Einsparpotenzial je Monat</span>
                    <div className="grossbetrag">{euro(offenCent)}</div>
                    <p style={{ margin: "6px 0 0", color: "var(--gedaempft)", fontSize: 14 }}>
                        {euro(offenCent * 12)} im Jahr · bei laufenden Lizenzkosten von{" "}
                        {euro(auswertung.lizenzkosten_cent)} je Monat
                    </p>
                </div>
                <div className="aufteilung">
                    <div className="zeile">
                        <span>
                            <strong>Ohne Rückfrage zu heben</strong>
                            <span style={{ color: "var(--gedaempft)" }}>
                                {" "}
                                — gesperrte Konten, doppelte und ungenutzte Lizenzen
                            </span>
                        </span>
                        <span className="betrag" style={{ color: "var(--geld)" }}>
                            {euro(auswertung.ersparnis_sicher_cent)}
                        </span>
                        <span className="schiene">
                            <span style={{ width: `${sicherAnteil}%`, background: "var(--geld)" }} />
                        </span>
                    </div>
                    <div className="zeile">
                        <span>
                            <strong>Erst zu prüfen</strong>
                            <span style={{ color: "var(--gedaempft)" }}>
                                {" "}
                                — Inaktivität kann Elternzeit sein, kleinere Pläne können Funktionen kosten
                            </span>
                        </span>
                        <span className="betrag" style={{ color: "var(--pruefen)" }}>
                            {euro(auswertung.ersparnis_pruefen_cent)}
                        </span>
                        <span className="schiene">
                            <span
                                style={{ width: `${100 - sicherAnteil}%`, background: "var(--pruefen)" }}
                            />
                        </span>
                    </div>
                </div>
            </section>

            <div className="kennzahlen">
                <Kennzahl
                    beschriftung="Anteil am Lizenzbudget"
                    wert={
                        auswertung.lizenzkosten_cent
                            ? `${Math.round((auswertung.ersparnis_cent / auswertung.lizenzkosten_cent) * 100)} %`
                            : "–"
                    }
                    fussnote="der monatlichen Kosten sind heute ohne Gegenwert"
                />
                <Kennzahl
                    beschriftung="Offene Befunde"
                    wert={String(kennzahlen?.anzahlOffen ?? daten.befunde.length)}
                    fussnote={`${kennzahlen?.anzahlErledigt ?? 0} bereits erledigt`}
                />
                <Kennzahl
                    beschriftung="Bereits gehoben"
                    wert={euroKurz(kennzahlen?.erledigtCent ?? 0)}
                    geld
                    fussnote="je Monat, aus erledigten Befunden"
                />
                <Kennzahl
                    beschriftung="Je Konto und Monat"
                    wert={
                        auswertung.anzahl_konten
                            ? euro(Math.round(auswertung.lizenzkosten_cent / auswertung.anzahl_konten))
                            : "–"
                    }
                    fussnote="durchschnittliche Lizenzkosten"
                />
            </div>

            <section className="karte">
                <div className="karte-kopf">
                    <h2>Befunde</h2>
                    <span style={{ color: "var(--gedaempft)", fontSize: 13.5 }}>
                        {gefiltert.length} von {daten.befunde.length} angezeigt
                    </span>
                </div>
                <div className="karte-koerper" style={{ paddingBottom: 0 }}>
                    <div className="werkzeugleiste">
                        <input
                            type="search"
                            placeholder="Suchen in Titel, Konto, Begründung"
                            value={suche}
                            onChange={(e) => setSuche(e.target.value)}
                        />
                        <select value={status} onChange={(e) => setStatus(e.target.value)}>
                            <option value="offen">Offen</option>
                            <option value="erledigt">Erledigt</option>
                            <option value="ignoriert">Ignoriert</option>
                            <option value="">Jeder Stand</option>
                        </select>
                        <select value={art} onChange={(e) => setArt(e.target.value)}>
                            <option value="">Jede Art</option>
                            {Object.entries(BEFUNDART_TEXT).map(([schluessel, text]) => (
                                <option key={schluessel} value={schluessel}>
                                    {text}
                                </option>
                            ))}
                        </select>
                        <select value={sicherheit} onChange={(e) => setSicherheit(e.target.value)}>
                            <option value="">Sicher und zu prüfen</option>
                            <option value="sicher">Nur sichere</option>
                            <option value="pruefen">Nur zu prüfende</option>
                        </select>
                    </div>
                </div>
                {gefiltert.length === 0 ? (
                    <div className="leerzustand">
                        <h3>Hier ist nichts offen</h3>
                        <p>Kein Befund passt zu diesen Filtern.</p>
                    </div>
                ) : (
                    <div className="tabellenrahmen">
                        <table className="liste">
                            <thead>
                                <tr>
                                    <th>Befund</th>
                                    <th>Art</th>
                                    <th>Sicherheit</th>
                                    <th style={{ textAlign: "right" }}>€ / Monat</th>
                                    <th style={{ textAlign: "right" }}>€ / Jahr</th>
                                </tr>
                            </thead>
                            <tbody>
                                {gefiltert.map((befund) => (
                                    <BefundZeile
                                        key={befund.schluessel}
                                        befund={befund}
                                        offen={offenerBefund === befund.schluessel}
                                        umschalten={() =>
                                            setOffenerBefund(
                                                offenerBefund === befund.schluessel ? null : befund.schluessel,
                                            )
                                        }
                                        setzeStand={async (neu, notiz) => {
                                            await api.standSetzen(mandantId, befund.schluessel, neu, notiz);
                                            await laden();
                                        }}
                                    />
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </section>
        </>
    );
}

function Kennzahl({
    beschriftung, wert, fussnote, geld = false,
}: {
    beschriftung: string; wert: string; fussnote: string; geld?: boolean;
}) {
    return (
        <div className="kennzahl">
            <span className="beschriftung">{beschriftung}</span>
            <span className={`wert${geld ? " geld" : ""}`}>{wert}</span>
            <span className="fussnote">{fussnote}</span>
        </div>
    );
}

function BefundZeile({
    befund, offen, umschalten, setzeStand,
}: {
    befund: Befundzeile;
    offen: boolean;
    umschalten: () => void;
    setzeStand: (status: string, notiz?: string) => Promise<void>;
}) {
    const [notiz, setNotiz] = useState(befund.stand_notiz);
    return (
        <>
            <tr className={`anklickbar ${befund.status}`} onClick={umschalten}>
                <td>
                    <strong>{befund.titel}</strong>
                    {befund.upn ? <div style={{ color: "var(--gedaempft)", fontSize: 12.5 }}>{befund.upn}</div> : null}
                </td>
                <td>
                    <span className="marke art">{BEFUNDART_TEXT[befund.art as Befundart] ?? befund.art}</span>
                </td>
                <td>
                    <span className={`marke ${befund.sicherheit}`}>
                        {befund.sicherheit === "sicher" ? "Sicher" : "Prüfen"}
                    </span>
                </td>
                <td className="betrag">{euro(befund.ersparnis_cent)}</td>
                <td className="betrag">{euro(befund.ersparnis_cent * 12)}</td>
            </tr>
            {offen ? (
                <tr className="aufklappung">
                    <td colSpan={5}>
                        <div className="inhalt-innen">
                            <dl>
                                <dt>Warum</dt>
                                <dd>{befund.begruendung}</dd>
                                <dt>Empfehlung</dt>
                                <dd>{befund.empfehlung}</dd>
                                {befund.stand_geaendert_am ? (
                                    <>
                                        <dt>Stand</dt>
                                        <dd>
                                            {befund.status} seit{" "}
                                            {new Date(befund.stand_geaendert_am).toLocaleDateString("de-DE")}
                                        </dd>
                                    </>
                                ) : null}
                            </dl>
                            <div className="feld">
                                <label htmlFor={`notiz-${befund.schluessel}`}>Notiz</label>
                                <input
                                    id={`notiz-${befund.schluessel}`}
                                    value={notiz}
                                    onChange={(e) => setNotiz(e.target.value)}
                                    onClick={(e) => e.stopPropagation()}
                                    placeholder="z. B. Elternzeit bis März, Lizenz bleibt"
                                />
                            </div>
                            <div className="knopfreihe">
                                <button
                                    type="button"
                                    className="knopf haupt klein"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        void setzeStand("erledigt", notiz);
                                    }}
                                >
                                    Erledigt
                                </button>
                                <button
                                    type="button"
                                    className="knopf klein"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        void setzeStand("ignoriert", notiz);
                                    }}
                                >
                                    Bewusst behalten
                                </button>
                                {befund.status !== "offen" ? (
                                    <button
                                        type="button"
                                        className="knopf leise klein"
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            void setzeStand("offen", notiz);
                                        }}
                                    >
                                        Wieder öffnen
                                    </button>
                                ) : null}
                            </div>
                        </div>
                    </td>
                </tr>
            ) : null}
        </>
    );
}
