import { useState, type DragEvent } from "react";
import { useNavigate } from "react-router-dom";
import { api, type Fehler } from "../api.ts";
import type { Werkzeug } from "../App.tsx";

const ART_TEXT: Record<string, string> = {
    konten: "Benutzerliste",
    nutzung: "Nutzungsbericht",
    abonnements: "Abonnements",
    unbekannt: "nicht erkannt",
};

export function Import({ werkzeug }: { werkzeug: Werkzeug }) {
    const navigate = useNavigate();
    const [dateien, setDateien] = useState<File[]>([]);
    const [bereit, setBereit] = useState(false);
    const [laeuft, setLaeuft] = useState(false);
    const [fehler, setFehler] = useState<string | null>(null);
    const [warnungen, setWarnungen] = useState<string[]>([]);

    function nimm(neue: FileList | null) {
        if (!neue) return;
        const csv = [...neue].filter((datei) => /\.(csv|txt)$/i.test(datei.name));
        setFehler(csv.length < neue.length ? "Es werden nur CSV-Dateien gelesen." : null);
        setDateien((bisher) => [...bisher, ...csv].slice(0, 6));
    }

    async function auswerten() {
        setLaeuft(true);
        setFehler(null);
        setWarnungen([]);
        try {
            const ergebnis = await api.auswerten(werkzeug.mandant.id, dateien);
            await werkzeug.mandantenNeuLaden();
            if (ergebnis.warnungen.length > 0) {
                setWarnungen(ergebnis.warnungen);
                setLaeuft(false);
                return;
            }
            navigate("/");
        } catch (problem) {
            const f = problem as Fehler;
            setFehler(f.message);
            const daten = f.daten as { dateien?: { name: string; art: string }[] } | undefined;
            if (daten?.dateien) {
                setWarnungen(
                    daten.dateien.map((d) => `${d.name}: ${ART_TEXT[d.art] ?? d.art}`),
                );
            }
            setLaeuft(false);
        }
    }

    function ablegen(ereignis: DragEvent) {
        ereignis.preventDefault();
        setBereit(false);
        nimm(ereignis.dataTransfer.files);
    }

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Daten einlesen</h1>
                    <p>
                        Drei Ausgaben aus dem Microsoft-365-Adminportal genügen. Der Lotse braucht
                        keinen Zugriff auf Ihren Mandanten — die Dateien verlassen Ihren Rechner
                        nur auf dem Weg zu Ihrem eigenen Lotsen.
                    </p>
                </div>
            </header>

            <div className="stapel">
                <section className="karte">
                    <div className="karte-kopf">
                        <h2>Woher die Dateien kommen</h2>
                    </div>
                    <div className="karte-koerper">
                        <ol className="schritte">
                            <li>
                                <div>
                                    <strong>Benutzerliste</strong> — Adminportal →{" "}
                                    <code>Benutzer → Aktive Benutzer</code> → Schaltfläche{" "}
                                    <code>Benutzer exportieren</code>. Enthält Anmeldenamen,
                                    Sperrstatus und zugewiesene Lizenzen. Ohne diese Datei geht es nicht.
                                </div>
                            </li>
                            <li>
                                <div>
                                    <strong>Nutzungsbericht</strong> — Adminportal →{" "}
                                    <code>Berichte → Nutzung → Microsoft 365 → Aktive Benutzer</code>{" "}
                                    → <code>Exportieren</code>. Liefert das letzte Aktivitätsdatum je
                                    Dienst. Ohne ihn erkennt der Lotse keine ungenutzten Lizenzen.
                                </div>
                            </li>
                            <li>
                                <div>
                                    <strong>Abonnements</strong> — Adminportal →{" "}
                                    <code>Abrechnung → Ihre Produkte</code>. Zeigt gekaufte gegen
                                    zugewiesene Plätze und damit die Lizenzen, die im Regal liegen.
                                </div>
                            </li>
                        </ol>
                    </div>
                </section>

                {fehler ? <p className="fehlerleiste">{fehler}</p> : null}
                {warnungen.length > 0 ? (
                    <div className="hinweisleiste warnend">
                        <div>
                            <p><strong>Der Lotse hat etwas zu bemängeln:</strong></p>
                            <ul>
                                {warnungen.map((warnung) => (
                                    <li key={warnung}>{warnung}</li>
                                ))}
                            </ul>
                            <p style={{ marginTop: 8 }}>
                                Die Auswertung wurde trotzdem gespeichert — sie ist nur
                                unvollständig.
                            </p>
                        </div>
                    </div>
                ) : null}

                <section className="karte">
                    <div className="karte-kopf">
                        <h2>Dateien</h2>
                        {dateien.length > 0 ? (
                            <button type="button" className="knopf leise klein" onClick={() => setDateien([])}>
                                Alle entfernen
                            </button>
                        ) : null}
                    </div>
                    <div className="karte-koerper stapel">
                        <label
                            className={`ablagefeld${bereit ? " bereit" : ""}`}
                            onDragOver={(e) => {
                                e.preventDefault();
                                setBereit(true);
                            }}
                            onDragLeave={() => setBereit(false)}
                            onDrop={ablegen}
                        >
                            <strong>Dateien hierher ziehen</strong>
                            <span style={{ color: "var(--gedaempft)", fontSize: 13.5 }}>
                                oder klicken, um sie auszuwählen — CSV, bis zu sechs Stück
                            </span>
                            <input
                                type="file"
                                accept=".csv,text/csv"
                                multiple
                                style={{ display: "none" }}
                                onChange={(e) => nimm(e.target.files)}
                            />
                        </label>

                        {dateien.length > 0 ? (
                            <ul className="dateiliste">
                                {dateien.map((datei, nummer) => (
                                    <li key={`${datei.name}-${nummer}`}>
                                        <span>
                                            {datei.name}{" "}
                                            <span style={{ color: "var(--gedaempft)" }}>
                                                ({Math.max(1, Math.round(datei.size / 1024))} kB)
                                            </span>
                                        </span>
                                        <button
                                            type="button"
                                            className="knopf leise klein"
                                            onClick={() =>
                                                setDateien((bisher) => bisher.filter((_, i) => i !== nummer))
                                            }
                                        >
                                            Entfernen
                                        </button>
                                    </li>
                                ))}
                            </ul>
                        ) : null}

                        <div className="knopfreihe">
                            <button
                                type="button"
                                className="knopf haupt"
                                disabled={dateien.length === 0 || laeuft}
                                onClick={() => void auswerten()}
                            >
                                {laeuft ? "Wird ausgewertet …" : "Auswerten"}
                            </button>
                            <button
                                type="button"
                                className="knopf"
                                disabled={laeuft}
                                onClick={async () => {
                                    setLaeuft(true);
                                    await api.demodaten(werkzeug.mandant.id);
                                    await werkzeug.mandantenNeuLaden();
                                    navigate("/");
                                }}
                            >
                                Stattdessen Beispielbestand
                            </button>
                        </div>
                    </div>
                </section>
            </div>
        </>
    );
}
