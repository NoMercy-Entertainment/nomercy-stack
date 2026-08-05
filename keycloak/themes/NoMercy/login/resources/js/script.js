// Dismissal for the locale <details> menu. <details> gives us keyboard opening
// and expanded state for free, but nothing closes it again once it is open, so
// the panel would sit over the card until the user clicked the summary a second
// time. Escape and a click outside are what people already expect from a menu.
document.addEventListener("DOMContentLoaded", () => {
    const menu = document.getElementById("kc-locale-dropdown");
    if (!menu) return;

    const close = () => menu.removeAttribute("open");

    document.addEventListener("click", (event) => {
        if (menu.open && !menu.contains(event.target)) close();
    });

    document.addEventListener("keydown", (event) => {
        if (event.key !== "Escape" || !menu.open) return;
        close();
        menu.querySelector("summary")?.focus();
    });
});
