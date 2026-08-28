import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { datumKurz, euro, kuendigungsregel, monateInWorten } from "../../fachlogik/formate.ts";
import {
    KATEGORIE_TEXT,
    LAUFZEITMODELL_TEXT,
    VERTRAGSSTATUS_TEXT,
    ZAHLUNGSINTERVALL_TEXT,
} from "../../fachlogik/typen.ts";
import { api } from "../api.ts";
import { Fristkarte, Karte, Laedt, Plakette } from "../teile/bausteine.tsx";
import type { Erinnerung, Verlaufseintrag, VertragMitFristen } from "../typen.ts";

export function Vertragsseite() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const [vertrag, setVertrag] = useState<VertragMitFristen | null>(null);
    const [verlauf, setVerlauf] = useState<Verlaufseintrag[]>([]);
    const [erinnerungen, setErinnerungen] = useState<Erinnerung[]>([]);
    const [dialog, setDialog] = useState<"kuendigen" | "loeschen" | null>(null);

    async function laden() {
        if (!id) return;
        const antwort = await api.vertrag(id);
        setVertrag(antwort.vertrag);
        setVerlauf(antwort.verlauf);
        setErinnerungen(antwort.erinnerungen);
    }

    useEffect(() => {
        void laden();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [id]);

    if (!vertrag || !id) return <Laedt />;

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <p className="nebenzeile" style={{ margin: 0 }}>
                        <Link to="/vertraege">Verträge</Link> ·{" "}
                        {KATEGORIE_TEXT[vertrag.kategorie]}
                    </p>
                    <h1>{vertrag.bezeichnung}</h1>
                    <p>
                        {[vertrag.anbieter, vertrag.vertragsnummer, vertrag.abteilung]
                            .filter(Boolean)
                            .join(" · ") || "Ohne weitere Angaben"}
                    </p>
                </div>
                <div className="knopfreihe">
                    {vertrag.status === "aktiv" ? (
                        <button type="button" className="knopf" onClick={() => setDialog("kuendigen")}>
                            Kündigung eintragen
                        </button>
                    ) : (
                        <button
                            type="button"
                            className="knopf"
                            onClick={async () => {
                                await api.reaktivieren(id);
                                void laden();
                            }}
                        >
                            Kündigung zurücknehmen
                        </button>
                    )}
                    <Link className="knopf haupt" to={`/vertraege/${id}/bearbeiten`}>
                        Bearbeiten
                    </Link>
                </div>
            </header>

            <div className="zweispaltig">
                <div className="stapel">
                    <Karte titel="Vertragsdaten">
                        <dl
                            style={{
                                margin: 0,
                                display: "grid",
                                gridTemplateColumns: "minmax(160px, auto) 1fr",
                                gap: "8px 20px",
                                fontSize: 14,
                            }}
                        >
                            <Zeile name="Status">
                                <Plakette ampel={vertrag.ampel} text={VERTRAGSSTATUS_TEXT[vertrag.status]} />
                            </Zeile>
                            <Zeile name="Beginn">{datumKurz(vertrag.beginn)}</Zeile>
                            <Zeile name="Laufzeit">
                                {LAUFZEITMODELL_TEXT[vertrag.laufzeitmodell]}
                                {vertrag.erstlaufzeitMonate > 0
                                    ? `, ${monateInWorten(vertrag.erstlaufzeitMonate)}`
                                    : ""}
                                {vertrag.verlaengerungMonate > 0
                                    ? ` (+${monateInWorten(vertrag.verlaengerungMonate)})`
                                    : ""}
                            </Zeile>
                            <Zeile name="Kündigungsfrist">
                                {kuendigungsregel(vertrag)}
                            </Zeile>
                            <Zeile name="Kosten">
                                {vertrag.betragCent > 0
                                    ? `${euro(vertrag.betragCent)} ${ZAHLUNGSINTERVALL_TEXT[vertrag.zahlungsintervall]} · ${euro(vertrag.jahreskostenCent)} im Jahr`
                                    : "nicht erfasst"}
                            </Zeile>
                            {vertrag.ansprechpartner ? (
                                <Zeile name="Ansprechpartner">{vertrag.ansprechpartner}</Zeile>
                            ) : null}
                            {vertrag.dokumentLink ? (
                                <Zeile name="Dokument">
                                    <a href={vertrag.dokumentLink} target="_blank" rel="noreferrer">
                                        {vertrag.dokumentLink}
                                    </a>
                                </Zeile>
                            ) : null}
                        </dl>
                        {vertrag.notizen ? (
                            <p style={{ whiteSpace: "pre-wrap", marginBottom: 0, marginTop: 16 }}>
                                {vertrag.notizen}
                            </p>
                        ) : null}
                    </Karte>

                    {erinnerungen.length > 0 ? (
                        <Karte titel="Erinnerungen zu diesem Vertrag">
                            <ul className="zeitleiste">
                                {erinnerungen.map((erinnerung) => (
                                    <li key={erinnerung.id}>
                                        <time>{datumKurz(erinnerung.faellig_am)}</time>
                                        <span>
                                            {erinnerung.vorlauf_tage} Tage vor dem Stichtag{" "}
                                            {datumKurz(erinnerung.stichtag)}
                                            {erinnerung.erledigt_am ? " · erledigt" : ""}
                                        </span>
                                    </li>
                                ))}
                            </ul>
                        </Karte>
                    ) : null}

                    {verlauf.length > 0 ? (
                        <Karte titel="Verlauf">
                            <ul className="zeitleiste">
                                {verlauf.map((eintrag) => (
                                    <li key={eintrag.id}>
                                        <time>{datumKurz(eintrag.zeitpunkt.slice(0, 10))}</time>
                                        <span>{eintrag.beschreibung}</span>
                                    </li>
                                ))}
                            </ul>
                        </Karte>
                    ) : null}
                </div>

                <div className="stapel">
                    <Fristkarte fristen={vertrag.fristen} ampel={vertrag.ampel} />
                    <div className="karte">
                        <div className="karte-koerper">
                            <button
                                type="button"
                                className="knopf gefahr"
                                onClick={() => setDialog("loeschen")}
                            >
                                Vertrag löschen
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            {dialog === "kuendigen" ? (
                <Kuendigungsdialog
                    vertrag={vertrag}
                    schliessen={() => setDialog(null)}
                    fertig={() => {
                        setDialog(null);
                        void laden();
                    }}
                />
            ) : null}

            {dialog === "loeschen" ? (
                <div className="schleier" onClick={() => setDialog(null)}>
                    <div className="dialog" onClick={(e) => e.stopPropagation()}>
                        <h2>Vertrag löschen?</h2>
                        <p style={{ margin: 0 }}>
                            „{vertrag.bezeichnung}“ und alle zugehörigen Erinnerungen werden
                            entfernt. Das lässt sich nicht rückgängig machen. Soll der Vertrag nur
                            aus der Überwachung fallen, tragen Sie stattdessen die Kündigung ein.
                        </p>
                        <div className="knopfreihe">
                            <button
                                type="button"
                                className="knopf gefahr"
                                onClick={async () => {
                                    await api.loeschen(id);
                                    navigate("/vertraege");
                                }}
                            >
                                Endgültig löschen
                            </button>
                            <button type="button" className="knopf leise" onClick={() => setDialog(null)}>
                                Abbrechen
                            </button>
                        </div>
                    </div>
                </div>
            ) : null}
        </>
    );
}

function Zeile({ name, children }: { name: string; children: React.ReactNode }) {
    return (
        <>
            <dt style={{ color: "var(--gedaempft)" }}>{name}</dt>
            <dd style={{ margin: 0 }}>{children}</dd>
        </>
    );
}

function Kuendigungsdialog({
    vertrag,
    schliessen,
    fertig,
}: {
    vertrag: VertragMitFristen;
    schliessen: () => void;
    fertig: () => void;
}) {
    const [datum, setDatum] = useState(vertrag.fristen.wirksamesVertragsende ?? "");
    const [notiz, setNotiz] = useState("");
    const [laeuft, setLaeuft] = useState(false);

    return (
        <div className="schleier" onClick={schliessen}>
            <form
                className="dialog"
                onClick={(e) => e.stopPropagation()}
                onSubmit={async (e) => {
                    e.preventDefault();
                    setLaeuft(true);
                    await api.kuendigen(vertrag.id, { gekuendigtZum: datum || null, notiz });
                    fertig();
                }}
            >
                <h2>Kündigung eintragen</h2>
                <p style={{ margin: 0, fontSize: 13.5, color: "var(--gedaempft)" }}>
                    Der Vertrag bleibt bis zum Ende sichtbar, löst aber keine Erinnerung mehr aus.
                    Vorbelegt ist das Ende, das sich bei fristgerechter Kündigung ergibt.
                </p>
                <div className="feld">
                    <label htmlFor="kuendigung-datum">Vertrag endet zum</label>
                    <input
                        id="kuendigung-datum"
                        type="date"
                        value={datum}
                        onChange={(e) => setDatum(e.target.value)}
                        required
                    />
                </div>
                <div className="feld">
                    <label htmlFor="kuendigung-notiz">Notiz (optional)</label>
                    <input
                        id="kuendigung-notiz"
                        value={notiz}
                        onChange={(e) => setNotiz(e.target.value)}
                        placeholder="z. B. per Einschreiben am 12.09. verschickt"
                    />
                </div>
                <div className="knopfreihe">
                    <button type="submit" className="knopf haupt" disabled={laeuft}>
                        Kündigung eintragen
                    </button>
                    <button type="button" className="knopf leise" onClick={schliessen}>
                        Abbrechen
                    </button>
                </div>
            </form>
        </div>
    );
}
