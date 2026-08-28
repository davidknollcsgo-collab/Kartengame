import { useCallback, useEffect, useState } from "react";
import { NavLink, Route, Routes, useNavigate } from "react-router-dom";
import { api } from "./api.ts";
import { Anmeldung } from "./seiten/Anmeldung.tsx";
import { Einstellungen } from "./seiten/Einstellungen.tsx";
import { Erinnerungen } from "./seiten/Erinnerungen.tsx";
import { Uebersicht } from "./seiten/Uebersicht.tsx";
import { VertragBearbeiten, VertragNeu } from "./seiten/VertragFormular.tsx";
import { Vertragsliste } from "./seiten/Vertragsliste.tsx";
import { Vertragsseite } from "./seiten/Vertragsseite.tsx";
import { Laedt } from "./teile/bausteine.tsx";
import type { Anmeldedaten } from "./typen.ts";

function Zeichen() {
    // Ein Kalenderblatt mit Knick: das Blatt, auf dem die Frist steht.
    return (
        <svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true">
            <rect x="2.5" y="4.5" width="21" height="19" rx="2.5" fill="none" stroke="var(--akzent)" strokeWidth="1.6" />
            <path d="M2.5 9.5h21" stroke="var(--akzent)" strokeWidth="1.6" />
            <path d="M8 2.5v4M18 2.5v4" stroke="var(--akzent)" strokeWidth="1.6" strokeLinecap="round" />
            <path d="M9 16.5l3 3 5.5-6.5" fill="none" stroke="var(--akzent)" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
    );
}

export function App() {
    const [anmeldung, setAnmeldung] = useState<Anmeldedaten | null>(null);
    const [geprueft, setGeprueft] = useState(false);
    const [offeneErinnerungen, setOffeneErinnerungen] = useState(0);

    const pruefen = useCallback(async () => {
        setAnmeldung(await api.ich());
        setGeprueft(true);
    }, []);

    useEffect(() => {
        void pruefen();
    }, [pruefen]);

    const zaehleErinnerungen = useCallback(async () => {
        if (!anmeldung) return;
        const { erinnerungen } = await api.erinnerungen();
        setOffeneErinnerungen(erinnerungen.filter((e) => !e.erledigt_am).length);
    }, [anmeldung]);

    useEffect(() => {
        void zaehleErinnerungen();
    }, [zaehleErinnerungen]);

    if (!geprueft) return <Laedt was="Wächter startet" />;
    if (!anmeldung) return <Anmeldung fertig={pruefen} />;

    return (
        <div className="rahmen">
            <Seitenleiste
                anmeldung={anmeldung}
                offeneErinnerungen={offeneErinnerungen}
                abmelden={async () => {
                    await api.abmelden();
                    setAnmeldung(null);
                    if (api.demo) window.location.reload();
                }}
            />
            <main className="inhalt">
                <Routes>
                    <Route path="/" element={<Uebersicht anmeldung={anmeldung} />} />
                    <Route path="/vertraege" element={<Vertragsliste />} />
                    <Route path="/vertraege/neu" element={<VertragNeu />} />
                    <Route path="/vertraege/:id" element={<Vertragsseite />} />
                    <Route path="/vertraege/:id/bearbeiten" element={<VertragBearbeiten />} />
                    <Route
                        path="/erinnerungen"
                        element={<Erinnerungen aktualisiert={zaehleErinnerungen} />}
                    />
                    <Route
                        path="/einstellungen"
                        element={<Einstellungen anmeldung={anmeldung} neuLaden={pruefen} />}
                    />
                    <Route path="*" element={<NichtGefunden />} />
                </Routes>
            </main>
        </div>
    );
}

function Seitenleiste({
    anmeldung,
    offeneErinnerungen,
    abmelden,
}: {
    anmeldung: Anmeldedaten;
    offeneErinnerungen: number;
    abmelden: () => Promise<void>;
}) {
    return (
        <aside className="schrank">
            <div className="marke-kopf">
                <Zeichen />
                <div>
                    <strong>Vertragsfristen</strong>
                    <span>Wächter</span>
                </div>
            </div>
            <nav className="navigation">
                <NavLink to="/" end>
                    Übersicht
                </NavLink>
                <NavLink to="/vertraege">Verträge</NavLink>
                <NavLink to="/erinnerungen">
                    Erinnerungen
                    {offeneErinnerungen > 0 ? <span className="zahl">{offeneErinnerungen}</span> : null}
                </NavLink>
                <NavLink to="/einstellungen">Einstellungen</NavLink>
            </nav>
            <div className="schrank-fuss">
                <div>
                    <strong style={{ display: "block", color: "var(--tinte)" }}>
                        {anmeldung.organisation.name}
                    </strong>
                    {anmeldung.benutzer.name}
                </div>
                <button type="button" className="knopf leise" onClick={() => void abmelden()}>
                    {api.demo ? "Demo zurücksetzen" : "Abmelden"}
                </button>
            </div>
        </aside>
    );
}

function NichtGefunden() {
    const navigate = useNavigate();
    return (
        <div className="leerzustand">
            <h3>Diese Seite gibt es nicht</h3>
            <button type="button" className="knopf" onClick={() => navigate("/")}>
                Zur Übersicht
            </button>
        </div>
    );
}
