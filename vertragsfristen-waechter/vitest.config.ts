import { defineConfig } from "vitest/config";

// Eigene Datei, weil vite.config.ts als Wurzel src/web hat — die Tests liegen
// aber im ganzen Projekt.
export default defineConfig({
    test: {
        include: ["src/**/*.test.ts"],
        exclude: ["bau/**", "node_modules/**"],
    },
});
