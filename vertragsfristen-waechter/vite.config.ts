import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Die Oberfläche wird nach bau/web gebaut; im Entwicklungsbetrieb reicht Vite
// alle /api- und /kalender-Aufrufe an den Fastify-Server durch.
export default defineConfig(({ mode }) => ({
    plugins: [react()],
    root: "src/web",
    // Der Demo-Modus kommt ohne Server aus und legt alles im Browser ab.
    define: { __DEMO__: JSON.stringify(mode === "demo") },
    build: {
        outDir: mode === "demo" ? "../../bau/demo" : "../../bau/web",
        emptyOutDir: true,
        assetsInlineLimit: mode === "demo" ? 100_000_000 : 4096,
        cssCodeSplit: mode !== "demo",
        rollupOptions: mode === "demo" ? { output: { inlineDynamicImports: true } } : {},
    },
    server: {
        port: 5173,
        proxy: {
            "/api": "http://127.0.0.1:4000",
            "/kalender": "http://127.0.0.1:4000",
        },
    },
}));
