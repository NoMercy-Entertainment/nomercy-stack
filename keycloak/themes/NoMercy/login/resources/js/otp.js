// Turns a single Keycloak code field into the designer's segmented boxes.
// Progressive enhancement: the real <input> still submits the value, so the
// page stays usable if this script never runs.
(() => {
    const build = (wrap) => {
        const target = document.querySelector(wrap.getAttribute("data-target"));
        if (!target) return;

        let length = parseInt(wrap.getAttribute("data-length") || "6", 10);
        if (!length || length < 1) length = 6;
        const dashRaw = wrap.getAttribute("data-dash") || "0";
        const dashAfter = dashRaw === "auto" ? Math.floor(length / 2) : parseInt(dashRaw, 10);

        const realWrapper = target.closest(".nm-input");
        const boxes = [];

        for (let index = 0; index < length; index += 1) {
            if (dashAfter && index === dashAfter) {
                const dash = document.createElement("span");
                dash.className = "nm-code__dash";
                dash.setAttribute("aria-hidden", "true");
                wrap.appendChild(dash);
            }
            const box = document.createElement("input");
            box.className = "nm-code__box";
            box.type = "text";
            box.inputMode = "numeric";
            box.autocomplete = index === 0 ? "one-time-code" : "off";
            box.maxLength = 1;
            box.setAttribute("aria-label", String(index + 1));
            boxes.push(box);
            wrap.appendChild(box);
        }

        // inline style beats the .nm-input{display:flex} class rule that an attribute hide can't
        if (realWrapper) realWrapper.style.display = "none";
        else target.style.display = "none";

        const sync = () => {
            target.value = boxes.map((box) => box.value).join("");
        };

        boxes.forEach((box, index) => {
            box.addEventListener("input", () => {
                box.value = box.value.replace(/\D/g, "").slice(0, 1);
                if (box.value && index < length - 1) boxes[index + 1].focus();
                sync();
            });
            box.addEventListener("keydown", (event) => {
                if (event.key === "Backspace" && !box.value && index > 0) {
                    boxes[index - 1].focus();
                }
            });
            box.addEventListener("paste", (event) => {
                event.preventDefault();
                const clip = (event.clipboardData || window.clipboardData).getData("text") || "";
                const digits = clip.replace(/\D/g, "").slice(0, length);
                boxes.forEach((target_box, position) => { target_box.value = digits[position] || ""; });
                sync();
                (boxes[Math.min(digits.length, length - 1)] || box).focus();
            });
        });

        if (target.value) {
            [...target.value].slice(0, length).forEach((char, index) => {
                if (boxes[index]) boxes[index].value = char;
            });
        }
        if (boxes[0]) boxes[0].focus();
    };

    document.addEventListener("DOMContentLoaded", () => {
        document.querySelectorAll("[data-nm-otp]").forEach(build);
    });
})();
