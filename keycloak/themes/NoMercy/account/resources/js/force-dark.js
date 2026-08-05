// MUST load after Keycloak's own dark-mode script (declared via scripts= so it is
// injected last): Keycloak toggles pf-v5-theme-dark from prefers-color-scheme, and
// we re-assert it so the NoMercy palette never drops to PatternFly light. Unlike the
// login theme, which follows the app's scheme, the account console is dark-only —
// PatternFly's light palette has never been skinned to match the brand.
const NOMERCY_DARK_CLASS = "pf-v5-theme-dark";

document.documentElement.classList.add(NOMERCY_DARK_CLASS);

window
    .matchMedia("(prefers-color-scheme: dark)")
    .addEventListener("change", () => document.documentElement.classList.add(NOMERCY_DARK_CLASS));
