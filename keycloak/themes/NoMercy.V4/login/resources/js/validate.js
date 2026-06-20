// Greys out the login button until the field satisfies its rule set, so the
// user gets immediate feedback before submitting. The password rules mirror the
// realm password policy; they are passed in as data attributes on the field so
// the policy lives in one place (the template) rather than being duplicated here.

function gateLoginButton() {
    const button = document.getElementById("kc-login");
    if (!button) {
        return;
    }
    const password = document.getElementById("password");
    const email = document.querySelector('#username[data-validate="email"]');
    const field = password || email;
    if (!field) {
        return;
    }

    const isValid = () => (password ? passwordMeetsPolicy(password) : isEmail(email.value));
    const apply = () => {
        const valid = isValid();
        button.classList.toggle("is-disabled", !valid);
        button.disabled = !valid;
    };

    field.addEventListener("input", apply);
    apply();
}

function passwordMeetsPolicy(input) {
    const value = input.value;
    const minLength = Number(input.dataset.pwLength || 0);
    const minDigits = Number(input.dataset.pwDigits || 0);
    const minSpecial = Number(input.dataset.pwSpecial || 0);
    const digitCount = (value.match(/\d/g) || []).length;
    const specialCount = (value.match(/[^A-Za-z0-9]/g) || []).length;
    return value.length >= minLength && digitCount >= minDigits && specialCount >= minSpecial;
}

function isEmail(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
}

document.addEventListener("DOMContentLoaded", gateLoginButton);
