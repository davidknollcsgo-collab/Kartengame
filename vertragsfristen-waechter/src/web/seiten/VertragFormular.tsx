import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { heute } from "../../fachlogik/datum.ts";
import { berechneFristen, bestimmeAmpel } from "../../fachlogik/fristen.ts";
import { euro, monateInWorten } from "../../fachlogik/formate.ts";
import {
    FRISTBEZUEGE,
    FRISTBEZUG_TEXT,
    FRISTEINHEITEN,
    FRISTEINHEIT_TEXT,
    KATEGORIEN,
    KATEGORIE_TEXT,
    LAUFZEITMODELLE,
    LAUFZEITMODELL_TEXT,
    VERTRAGSSTATUS,
    VERTRAGSSTATUS_TEXT,
    ZAHLUNGSINTERVALLE,
    ZAHLUNGSINTERVALL_TEXT,
    type Fristbezug,
    type Fristeinheit,
    type Kategorie,
    type Laufzeitmodell,
    type Vertragsstatus,
    type Zahlungsintervall,
} from "../../fachlogik/typen.ts";
import { VORLAGEN } from "../../fachlogik/vorlagen.ts";
import { api } from "../api.ts";
import { Fristkarte, Laedt } from "../teile/bausteine.tsx";
import type { Fehler, VertragEingabe } from "../typen.ts";

function leererVertrag(): VertragEingabe {
    return {
        bezeichnung: "",
        anbieter: "",
        kategorie: "software",
        vertragsnummer: "",
        abteilung: "",
        ansprechpartner: "",
        beginn: heute(),
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 3,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        betragCent: 0,
        zahlungsintervall: "jaehrlich",
        status: "aktiv",
        gekuendigtZum: null,
        dokumentLink: "",
        notizen: "",
    };
}

export function VertragNeu() {
    return <Formular ueberschrift="Vertrag anlegen" anfang={leererVertrag()} vorlagenZeigen />;
}

export function VertragBearbeiten() {
    const { id } = useParams<{ id: string }>();
    const [anfang, setAnfang] = useState<VertragEingabe | null>(null);

    useEffect(() => {
        if (!id) return;
        void api.vertrag(id).then(({ vertrag }) => {
            const { fristen, ampel, jahreskostenCent, id: _id, organisationId, erstelltAm, geaendertAm, ...rest } =
                vertrag;
            void fristen;
            void ampel;
            void jahreskostenCent;
            void _id;
            void organisationId;
            void erstelltAm;
            void geaendertAm;
            setAnfang(rest);
        });
    }, [id]);

    if (!anfang || !id) return <Laedt />;
    return <Formular ueberschrift="Vertrag bearbeiten" anfang={anfang} id={id} />;
}

function Formular({
    ueberschrift,
    anfang,
    id,
    vorlagenZeigen = false,
}: {
    ueberschrift: string;
    anfang: VertragEingabe;
    id?: string;
    vorlagenZeigen?: boolean;
}) {
    const navigate = useNavigate();
    const [wert, setWert] = useState<VertragEingabe>(anfang);
    const [felder, setFelder] = useState<Record<string, string>>({});
    const [fehler, setFehler] = useState<string | null>(null);
    const [laeuft, setLaeuft] = useState(false);
    const heuteTag = heute();

    function aendere<K extends keyof VertragEingabe>(feld: K, neu: VertragEingabe[K]) {
        setWert((bisher) => ({ ...bisher, [feld]: neu }));
    }

    // Die Vorschau rechnet mit derselben Fachlogik wie der Server — was hier
    // steht, steht nach dem Speichern auch in der Liste.
    const vorschau = useMemo(() => {
        try {
            const fristen = berechneFristen(wert, heuteTag);
            return { fristen, ampel: bestimmeAmpel(fristen, wert.status) };
        } catch {
            return null;
        }
    }, [wert, heuteTag]);

    const zeigtLaufzeit = wert.laufzeitmodell !== "unbefristet";
    const zeigtVerlaengerung = wert.laufzeitmodell === "befristet_mit_verlaengerung";
    const zeigtBezug = wert.laufzeitmodell === "unbefristet";

    async function absenden(ereignis: FormEvent) {
        ereignis.preventDefault();
        setLaeuft(true);
        setFehler(null);
        setFelder({});
        try {
            const gespeichert = id ? await api.aendern(id, wert) : await api.anlegen(wert);
            navigate(`/vertraege/${gespeichert.id}`);
        } catch (problem) {
            const f = problem as Fehler;
            setFehler(f.message);
            setFelder(f.felder ?? {});
            setLaeuft(false);
        }
    }

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>{ueberschrift}</h1>
                    <p>
                        Laufzeit und Frist stehen im Vertrag, meist unter „Vertragsdauer“ oder
                        „Kündigung“. Rechts sehen Sie sofort, was daraus folgt.
                    </p>
                </div>
                <Link className="knopf leise" to={id ? `/vertraege/${id}` : "/vertraege"}>
                    Abbrechen
                </Link>
            </header>

            {vorlagenZeigen ? (
                <div className="hinweisleiste">
                    <div>
                        <p style={{ marginBottom: 8 }}>
                            <strong>Vorlage übernehmen</strong> — belegt Laufzeit und Frist mit den
                            üblichen Werten vor:
                        </p>
                        <div className="knopfreihe">
                            {VORLAGEN.map((vorlage) => (
                                <button
                                    key={vorlage.schluessel}
                                    type="button"
                                    className="knopf"
                                    title={vorlage.beschreibung}
                                    onClick={() =>
                                        setWert((bisher) => ({
                                            ...bisher,
                                            ...vorlage.bedingungen,
                                            kategorie: vorlage.kategorie,
                                            zahlungsintervall: vorlage.zahlungsintervall,
                                        }))
                                    }
                                >
                                    {vorlage.name}
                                </button>
                            ))}
                        </div>
                    </div>
                </div>
            ) : null}

            {fehler ? <p className="fehlerleiste">{fehler}</p> : null}

            <form onSubmit={absenden}>
                <div className="zweispaltig">
                    <div className="karte">
                        <div className="karte-koerper stapel">
                            <div className="feldgruppe">
                                <Feld beschriftung="Bezeichnung" meldung={felder["bezeichnung"]} weit>
                                    <input
                                        value={wert.bezeichnung}
                                        onChange={(e) => aendere("bezeichnung", e.target.value)}
                                        placeholder="z. B. Betriebshaftpflicht"
                                        required
                                        autoFocus
                                    />
                                </Feld>
                                <Feld beschriftung="Anbieter" meldung={felder["anbieter"]}>
                                    <input
                                        value={wert.anbieter}
                                        onChange={(e) => aendere("anbieter", e.target.value)}
                                        placeholder="z. B. Allianz"
                                    />
                                </Feld>
                                <Feld beschriftung="Kategorie">
                                    <select
                                        value={wert.kategorie}
                                        onChange={(e) => aendere("kategorie", e.target.value as Kategorie)}
                                    >
                                        {KATEGORIEN.map((k) => (
                                            <option key={k} value={k}>
                                                {KATEGORIE_TEXT[k]}
                                            </option>
                                        ))}
                                    </select>
                                </Feld>
                                <Feld beschriftung="Vertragsnummer">
                                    <input
                                        value={wert.vertragsnummer}
                                        onChange={(e) => aendere("vertragsnummer", e.target.value)}
                                    />
                                </Feld>
                                <Feld beschriftung="Abteilung / Kostenstelle">
                                    <input
                                        value={wert.abteilung}
                                        onChange={(e) => aendere("abteilung", e.target.value)}
                                    />
                                </Feld>
                                <Feld beschriftung="Ansprechpartner">
                                    <input
                                        value={wert.ansprechpartner}
                                        onChange={(e) => aendere("ansprechpartner", e.target.value)}
                                    />
                                </Feld>
                            </div>

                            <fieldset>
                                <legend>Laufzeit und Kündigung</legend>
                                <div className="feldgruppe">
                                    <Feld beschriftung="Vertragsbeginn" meldung={felder["beginn"]}>
                                        <input
                                            type="date"
                                            value={wert.beginn}
                                            onChange={(e) => aendere("beginn", e.target.value)}
                                            required
                                        />
                                    </Feld>
                                    <Feld beschriftung="Laufzeitmodell" weit>
                                        <select
                                            value={wert.laufzeitmodell}
                                            onChange={(e) => {
                                                const modell = e.target.value as Laufzeitmodell;
                                                setWert((bisher) => ({
                                                    ...bisher,
                                                    laufzeitmodell: modell,
                                                    kuendigungsfristBezug:
                                                        modell === "unbefristet"
                                                            ? bisher.kuendigungsfristBezug === "zum_laufzeitende"
                                                                ? "zum_monatsende"
                                                                : bisher.kuendigungsfristBezug
                                                            : "zum_laufzeitende",
                                                    verlaengerungMonate:
                                                        modell === "befristet_mit_verlaengerung"
                                                            ? bisher.verlaengerungMonate || 12
                                                            : 0,
                                                }));
                                            }}
                                        >
                                            {LAUFZEITMODELLE.map((m) => (
                                                <option key={m} value={m}>
                                                    {LAUFZEITMODELL_TEXT[m]}
                                                </option>
                                            ))}
                                        </select>
                                    </Feld>
                                    <Feld
                                        beschriftung={
                                            wert.laufzeitmodell === "unbefristet"
                                                ? "Mindestlaufzeit (Monate)"
                                                : "Erstlaufzeit (Monate)"
                                        }
                                        meldung={felder["erstlaufzeitMonate"]}
                                        hilfe={
                                            wert.erstlaufzeitMonate > 0
                                                ? monateInWorten(wert.erstlaufzeitMonate)
                                                : wert.laufzeitmodell === "unbefristet"
                                                  ? "0 = keine Bindung"
                                                  : undefined
                                        }
                                    >
                                        <input
                                            type="number"
                                            min={0}
                                            max={600}
                                            value={wert.erstlaufzeitMonate}
                                            onChange={(e) =>
                                                aendere("erstlaufzeitMonate", Number(e.target.value))
                                            }
                                            required={zeigtLaufzeit}
                                        />
                                    </Feld>
                                    {zeigtVerlaengerung ? (
                                        <Feld
                                            beschriftung="Verlängert sich um (Monate)"
                                            meldung={felder["verlaengerungMonate"]}
                                            hilfe={monateInWorten(wert.verlaengerungMonate)}
                                        >
                                            <input
                                                type="number"
                                                min={0}
                                                max={600}
                                                value={wert.verlaengerungMonate}
                                                onChange={(e) =>
                                                    aendere("verlaengerungMonate", Number(e.target.value))
                                                }
                                            />
                                        </Feld>
                                    ) : null}
                                    <Feld beschriftung="Kündigungsfrist">
                                        <input
                                            type="number"
                                            min={0}
                                            max={999}
                                            value={wert.kuendigungsfristWert}
                                            onChange={(e) =>
                                                aendere("kuendigungsfristWert", Number(e.target.value))
                                            }
                                        />
                                    </Feld>
                                    <Feld beschriftung="Einheit">
                                        <select
                                            value={wert.kuendigungsfristEinheit}
                                            onChange={(e) =>
                                                aendere("kuendigungsfristEinheit", e.target.value as Fristeinheit)
                                            }
                                        >
                                            {FRISTEINHEITEN.map((e) => (
                                                <option key={e} value={e}>
                                                    {FRISTEINHEIT_TEXT[e]}
                                                </option>
                                            ))}
                                        </select>
                                    </Feld>
                                    <Feld
                                        beschriftung="Kündigung wirkt"
                                        weit
                                        hilfe={
                                            zeigtBezug
                                                ? undefined
                                                : "Bei fester Laufzeit gilt der Termin des Laufzeitendes."
                                        }
                                    >
                                        <select
                                            value={wert.kuendigungsfristBezug}
                                            onChange={(e) =>
                                                aendere("kuendigungsfristBezug", e.target.value as Fristbezug)
                                            }
                                        >
                                            {FRISTBEZUEGE.filter(
                                                (b) => zeigtBezug || b === "zum_laufzeitende" || b === "jederzeit",
                                            ).map((b) => (
                                                <option key={b} value={b}>
                                                    {FRISTBEZUG_TEXT[b]}
                                                </option>
                                            ))}
                                        </select>
                                    </Feld>
                                </div>
                            </fieldset>

                            <fieldset>
                                <legend>Kosten</legend>
                                <div className="feldgruppe">
                                    <Feld
                                        beschriftung="Betrag je Zahlung (€)"
                                        hilfe={
                                            wert.betragCent > 0 && wert.zahlungsintervall !== "einmalig"
                                                ? `entspricht ${euro(
                                                      wert.betragCent *
                                                          { monatlich: 12, vierteljaehrlich: 4, halbjaehrlich: 2, jaehrlich: 1, einmalig: 0 }[
                                                              wert.zahlungsintervall
                                                          ],
                                                  )} im Jahr`
                                                : undefined
                                        }
                                    >
                                        <input
                                            type="number"
                                            min={0}
                                            step="0.01"
                                            value={wert.betragCent === 0 ? "" : (wert.betragCent / 100).toFixed(2)}
                                            onChange={(e) =>
                                                aendere(
                                                    "betragCent",
                                                    Math.round(Number(e.target.value || 0) * 100),
                                                )
                                            }
                                        />
                                    </Feld>
                                    <Feld beschriftung="Zahlungsintervall">
                                        <select
                                            value={wert.zahlungsintervall}
                                            onChange={(e) =>
                                                aendere("zahlungsintervall", e.target.value as Zahlungsintervall)
                                            }
                                        >
                                            {ZAHLUNGSINTERVALLE.map((z) => (
                                                <option key={z} value={z}>
                                                    {ZAHLUNGSINTERVALL_TEXT[z]}
                                                </option>
                                            ))}
                                        </select>
                                    </Feld>
                                </div>
                            </fieldset>

                            <fieldset>
                                <legend>Ablage</legend>
                                <div className="feldgruppe">
                                    <Feld beschriftung="Status">
                                        <select
                                            value={wert.status}
                                            onChange={(e) => aendere("status", e.target.value as Vertragsstatus)}
                                        >
                                            {VERTRAGSSTATUS.map((s) => (
                                                <option key={s} value={s}>
                                                    {VERTRAGSSTATUS_TEXT[s]}
                                                </option>
                                            ))}
                                        </select>
                                    </Feld>
                                    {wert.status !== "aktiv" ? (
                                        <Feld beschriftung="Endet zum" meldung={felder["gekuendigtZum"]}>
                                            <input
                                                type="date"
                                                value={wert.gekuendigtZum ?? ""}
                                                onChange={(e) =>
                                                    aendere("gekuendigtZum", e.target.value || null)
                                                }
                                            />
                                        </Feld>
                                    ) : null}
                                    <Feld beschriftung="Link zum Dokument" weit>
                                        <input
                                            type="url"
                                            value={wert.dokumentLink}
                                            onChange={(e) => aendere("dokumentLink", e.target.value)}
                                            placeholder="https://…"
                                        />
                                    </Feld>
                                </div>
                                <Feld beschriftung="Notizen">
                                    <textarea
                                        value={wert.notizen}
                                        onChange={(e) => aendere("notizen", e.target.value)}
                                        placeholder="Kündigungsanschrift, Ansprechpartner beim Anbieter, offene Punkte …"
                                    />
                                </Feld>
                            </fieldset>

                            <div className="knopfreihe">
                                <button type="submit" className="knopf haupt" disabled={laeuft}>
                                    {laeuft ? "Wird gespeichert …" : "Speichern"}
                                </button>
                                <Link className="knopf leise" to={id ? `/vertraege/${id}` : "/vertraege"}>
                                    Abbrechen
                                </Link>
                            </div>
                        </div>
                    </div>

                    <div className="stapel">
                        {vorschau ? (
                            <Fristkarte fristen={vorschau.fristen} ampel={vorschau.ampel} />
                        ) : (
                            <div className="karte">
                                <div className="karte-koerper nebenzeile">
                                    Sobald Beginn und Laufzeit stimmen, steht hier der Stichtag.
                                </div>
                            </div>
                        )}
                        <div className="karte">
                            <div className="karte-koerper" style={{ fontSize: 13.5 }}>
                                <h3 style={{ marginBottom: 8 }}>Woran man die Angaben erkennt</h3>
                                <p style={{ marginTop: 0, color: "var(--gedaempft)" }}>
                                    „Der Vertrag verlängert sich um jeweils ein Jahr, sofern er nicht
                                    drei Monate vor Ablauf gekündigt wird“ heißt: feste Laufzeit,
                                    Verlängerung 12 Monate, Frist 3 Monate zum Laufzeitende.
                                </p>
                                <p style={{ marginBottom: 0, color: "var(--gedaempft)" }}>
                                    Für Verträge zwischen Unternehmen sind lange Verlängerungen
                                    zulässig; die seit 2022 für Verbraucher geltende Monatsfrist
                                    greift dort nicht. Im Zweifel gilt, was im Vertrag steht.
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </form>
        </>
    );
}

function Feld({
    beschriftung,
    children,
    hilfe,
    meldung,
    weit = false,
}: {
    beschriftung: string;
    children: React.ReactNode;
    hilfe?: string;
    meldung?: string;
    weit?: boolean;
}) {
    return (
        <div
            className={`feld${meldung ? " falsch" : ""}`}
            style={weit ? { gridColumn: "1 / -1" } : undefined}
        >
            <label>{beschriftung}</label>
            {children}
            {hilfe && !meldung ? <span className="hilfe">{hilfe}</span> : null}
            {meldung ? <span className="meldung">{meldung}</span> : null}
        </div>
    );
}
