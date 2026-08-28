import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, HashRouter } from "react-router-dom";
import { App } from "./App.tsx";
import "./stil.css";

// Die Demo läuft als einzelne Datei ohne Server, der Pfade umschreiben
// könnte — dort adressiert die Navigation deshalb über den Anker.
const Router = __DEMO__ ? HashRouter : BrowserRouter;

createRoot(document.getElementById("wurzel")!).render(
    <StrictMode>
        <Router>
            <App />
        </Router>
    </StrictMode>,
);
