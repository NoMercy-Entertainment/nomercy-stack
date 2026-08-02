// The account-console SPA shows a PatternFly danger modal ("something went wrong")
// when its API returns 401 — e.g. accounts without manage-account (the locked test
// account). That modal only offers "retry", trapping the user. Inject a logout escape.
const LABELS = {
    en: "Sign out", nl: "Uitloggen", de: "Abmelden", fr: "Se déconnecter",
    es: "Cerrar sesión", it: "Esci", pt: "Sair", ru: "Выйти", ja: "ログアウト",
    zh: "退出登录", pl: "Wyloguj", cs: "Odhlásit se", sk: "Odhlásiť sa",
    da: "Log ud", no: "Logg ut", sv: "Logga ut", fi: "Kirjaudu ulos",
    hu: "Kijelentkezés", ca: "Tanca la sessió", lt: "Atsijungti", tr: "Çıkış yap",
};

function logoutLabel() {
    const lang = (document.documentElement.lang || "en").toLowerCase();
    return LABELS[lang] || LABELS[lang.split("-")[0]] || LABELS.en;
}

function logoutUrl() {
    const match = window.location.pathname.match(/\/realms\/([^/]+)\//);
    const realm = match ? match[1] : "NoMercyTV";
    const account = window.location.origin + "/realms/" + realm + "/account/";
    return window.location.origin + "/realms/" + realm
        + "/protocol/openid-connect/logout?client_id=account-console"
        + "&post_logout_redirect_uri=" + encodeURIComponent(account);
}

function injectLogout() {
    const footers = document.querySelectorAll(".pf-v5-c-modal-box.pf-m-danger .pf-v5-c-modal-box__footer");
    footers.forEach((footer) => {
        if (footer.querySelector(".nm-error-logout")) {
            return;
        }
        const link = document.createElement("a");
        link.className = "pf-v5-c-button pf-m-secondary nm-error-logout";
        link.setAttribute("role", "button");
        link.href = logoutUrl();
        link.textContent = logoutLabel();
        footer.appendChild(link);
    });
}

new MutationObserver(injectLogout).observe(document.documentElement, { childList: true, subtree: true });
injectLogout();
