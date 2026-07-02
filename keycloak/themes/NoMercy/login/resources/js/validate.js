// Greys out + disables the submit button until every field on the form is valid,
// so the user gets immediate feedback before submitting. Password rules mirror
// the realm password policy and are passed in as data attributes on the field,
// so the policy lives in one place (the template) rather than duplicated here.

function gateSubmitButton() {
    const button = document.getElementById("kc-login") || document.getElementById("kc-register");
    if (!button) {
        return;
    }

    const email = document.getElementById("email") || document.querySelector('#username[data-validate="email"]');
    const password = document.getElementById("password");
    const confirm = document.getElementById("password-confirm");
    const fields = [email, password, confirm].filter(Boolean);
    if (fields.length === 0) {
        return;
    }

    const isValid = () => {
        if (email && !isEmail(email.value)) {
            return false;
        }
        if (password && !passwordMeetsPolicy(password)) {
            return false;
        }
        if (confirm && confirm.value !== (password ? password.value : "")) {
            return false;
        }
        return true;
    };

    const apply = () => {
        const valid = isValid();
        button.classList.toggle("is-disabled", !valid);
        button.disabled = !valid;
    };

    fields.forEach((field) => field.addEventListener("input", apply));
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

document.addEventListener("DOMContentLoaded", gateSubmitButton);
