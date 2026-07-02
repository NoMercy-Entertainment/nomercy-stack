// One-colour theming for the login.
// The app redirects to Keycloak with ?theme=<hex> (the colour the user picked).
// All we do here is set --primary; the whole accent palette derives from it in
// CSS via relative colour, and light/dark is left to the browser's
// prefers-color-scheme. The value is persisted in localStorage so it survives
// the multi-step flow (Keycloak drops query params on the POST-redirects between
// steps; localStorage on this origin does not).
(() => {
    const STORAGE_KEY = "nm-theme";

    const normalizeHex = (value) => {
        if (!value) return null;
        let hex = String(value).trim().replace(/^#/, "");
        if (/^[0-9a-fA-F]{3}$/.test(hex)) {
            hex = [...hex].map((char) => char + char).join("");
        }
        return /^[0-9a-fA-F]{6}$/.test(hex) ? `#${hex.toLowerCase()}` : null;
    };

    const requestedColour = () => {
        let fromQuery = null;
        try {
            fromQuery = new URLSearchParams(window.location.search).get("theme");
        } catch { /* malformed search string */ }
        if (fromQuery) return fromQuery;
        // a caller passing ?theme=#abc123 turns "#abc123" into the URL fragment, so look there too
        const fromHash = (window.location.hash || "").match(/[0-9a-fA-F]{6}|[0-9a-fA-F]{3}/);
        return fromHash ? fromHash[0] : null;
    };

    const requested = normalizeHex(requestedColour());
    if (requested) {
        try { localStorage.setItem(STORAGE_KEY, requested); } catch { /* storage blocked */ }
    }

    let theme = requested;
    if (!theme) {
        try { theme = normalizeHex(localStorage.getItem(STORAGE_KEY)); } catch { /* storage blocked */ }
    }
    if (theme) {
        document.documentElement.style.setProperty("--primary", theme);
    }
})();
