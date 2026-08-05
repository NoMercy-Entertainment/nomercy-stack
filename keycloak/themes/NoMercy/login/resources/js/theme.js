// One-colour theming for the login.
// The app redirects to Keycloak with ?theme=<hex> (the accent the user picked)
// and ?scheme=dark|light (the scheme they are looking at). Both are advisory:
// this file decides what is safe to honour, so a wrong or hostile value can
// tint the page but can never make it illegible.
//
// From --primary the whole accent palette derives in CSS via relative colour.
//
// The values are stashed because Keycloak drops query params on the POST
// redirects between steps. sessionStorage, not localStorage: a sign-in flow is
// one tab, and that is exactly how long these should live. A value kept past the
// flow outlives the app that sent it — a stored scheme would then keep winning
// over the browser's own preference on every later visit, which is the bug this
// file is here to prevent, not cause.
(() => {
    const THEME_KEY = "nm-theme";
    const SCHEME_KEY = "nm-scheme";
    const store = window.sessionStorage;

    // The NoMercy purple. Every fallback path lands here.
    const DEFAULT_ACCENT = "#6e56cf";
    // Below this much separation between the RGB channels a colour carries no
    // hue intent — it is a grey, and a grey accent is what turned the whole
    // login monochrome. Treat it as "no colour sent" rather than tinting to it.
    const MIN_CHANNEL_SPREAD = 16;
    // WCAG AA for the 16px button label.
    const MIN_INK_CONTRAST = 4.5;
    const INK_LIGHT = "#ffffff";
    const INK_DARK = "#101114";

    const readStored = (key) => {
        try { return store.getItem(key); } catch { return null; }
    };
    const writeStored = (key, value) => {
        try { store.setItem(key, value); } catch { /* storage blocked */ }
    };

    const queryParam = (name) => {
        try { return new URLSearchParams(window.location.search).get(name); } catch { return null; }
    };

    // ---- colour ----

    const normalizeHex = (value) => {
        if (!value) return null;
        let hex = String(value).trim().replace(/^#/, "");
        if (/^[0-9a-fA-F]{3}$/.test(hex)) {
            hex = [...hex].map((char) => char + char).join("");
        }
        return /^[0-9a-fA-F]{6}$/.test(hex) ? `#${hex.toLowerCase()}` : null;
    };

    const channels = (hex) => [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16));

    const toHex = (rgb) => `#${rgb.map((c) => Math.round(Math.min(255, Math.max(0, c))).toString(16).padStart(2, "0")).join("")}`;

    const luminance = (rgb) => {
        const [r, g, b] = rgb.map((channel) => {
            const v = channel / 255;
            return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
        });
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };

    const contrast = (a, b) => {
        const [hi, lo] = a > b ? [a, b] : [b, a];
        return (hi + 0.05) / (lo + 0.05);
    };

    const bestInk = (rgb) => {
        const own = luminance(rgb);
        const onLight = contrast(own, luminance(channels(INK_LIGHT)));
        const onDark = contrast(own, luminance(channels(INK_DARK)));
        return onLight >= onDark
            ? { ink: INK_LIGHT, ratio: onLight }
            : { ink: INK_DARK, ratio: onDark };
    };

    // Nudge the accent along its own hue until the button label clears AA. Only
    // ever moves the colour toward black or toward white, so the hue survives.
    const withLegibleInk = (rgb) => {
        let current = rgb;
        let best = bestInk(current);

        for (let step = 0; step < 24 && best.ratio < MIN_INK_CONTRAST; step += 1) {
            const towardBlack = best.ink === INK_LIGHT;
            current = current.map((channel) => (towardBlack ? channel * 0.94 : channel + (255 - channel) * 0.06));
            best = bestInk(current);
        }

        return { accent: toHex(current), ink: best.ink };
    };

    const acceptAccent = (value) => {
        const hex = normalizeHex(value);
        if (!hex) return null;

        const rgb = channels(hex);
        if (Math.max(...rgb) - Math.min(...rgb) < MIN_CHANNEL_SPREAD) return null;

        return hex;
    };

    // ---- scheme ----

    const acceptScheme = (value) => (value === "dark" || value === "light" ? value : null);

    // ---- apply ----

    const requestedAccent = queryParam("theme");
    if (requestedAccent !== null) {
        // An explicit param always replaces what is stored, including when it is
        // rejected — otherwise a bad accent sent once would outlive every later
        // redirect that sent a good one.
        const accepted = acceptAccent(requestedAccent);
        if (accepted) writeStored(THEME_KEY, accepted);
        else writeStored(THEME_KEY, DEFAULT_ACCENT);
    }

    const requestedScheme = acceptScheme(queryParam("scheme"));
    if (requestedScheme) writeStored(SCHEME_KEY, requestedScheme);

    const accent = acceptAccent(readStored(THEME_KEY)) ?? DEFAULT_ACCENT;
    const { accent: safeAccent, ink } = withLegibleInk(channels(accent));

    const root = document.documentElement;
    root.style.setProperty("--primary", safeAccent);
    root.style.setProperty("--primary-ink", ink);

    // The scheme is resolved here rather than by a @media block so there is
    // exactly one answer at any moment: an explicit scheme from the app if we
    // have one, the browser's preference otherwise. styles.css keys off the
    // attribute alone. This runs in <head>, before first paint, so the page
    // never flashes the wrong scheme; without JS the dark :root default stands.
    const preference = window.matchMedia("(prefers-color-scheme: light)");
    const applyScheme = () => {
        const stored = acceptScheme(readStored(SCHEME_KEY));
        root.setAttribute("data-scheme", stored ?? (preference.matches ? "light" : "dark"));
    };

    applyScheme();
    preference.addEventListener("change", applyScheme);
})();
