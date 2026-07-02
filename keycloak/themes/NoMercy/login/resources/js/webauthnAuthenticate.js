// Passkey sign-in ceremony using the native WebAuthn JSON serialization
// (PublicKeyCredential.parseRequestOptionsFromJSON / credential.toJSON).
// Requires a secure context, which the HTTPS login always provides. Keycloak
// hands us base64url strings and expects base64url back — exactly what the
// native JSON helpers produce — so there is no manual encoding to do.

// A single AbortController shared with the conditional-mediation autofill in
// passkeysConditionalAuth.js. WebAuthn forbids two concurrent get() calls, so
// each new ceremony aborts the pending one before it starts its own.
let abortController;

export function signal() {
    if (abortController) {
        const abortError = new Error("Cancelling pending WebAuthn call");
        abortError.name = "AbortError";
        abortController.abort(abortError);
    }
    abortController = new AbortController();
    return abortController.signal;
}

export async function authenticateByWebAuthn(input) {
    if (!window.PublicKeyCredential) {
        returnFailure(input.errmsg);
        return;
    }
    try {
        const credential = await doAuthenticate(input);
        returnSuccess(credential);
    } catch (error) {
        returnFailure(error);
    }
}

export function doAuthenticate(input) {
    const options = {
        challenge: input.challenge,
        rpId: input.rpId,
        allowCredentials: input.isUserIdentified ? collectAllowCredentials() : [],
    };
    if (input.createTimeout !== 0) options.timeout = input.createTimeout * 1000;
    if (input.userVerification !== "not specified") options.userVerification = input.userVerification;

    const publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(options);
    return navigator.credentials.get({ publicKey, signal: signal(), ...input.additionalOptions });
}

function collectAllowCredentials() {
    const form = document.forms["authn_select"];
    if (!form || form.authn_use_chk === undefined) return [];
    const fields = form.authn_use_chk.length === undefined ? [form.authn_use_chk] : [...form.authn_use_chk];
    return fields.map((field) => ({ id: toBase64Url(field.value), type: "public-key" }));
}

function toBase64Url(value) {
    return value.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function returnSuccess(credential) {
    const json = credential.toJSON();
    document.getElementById("clientDataJSON").value = json.response.clientDataJSON;
    document.getElementById("authenticatorData").value = json.response.authenticatorData;
    document.getElementById("signature").value = json.response.signature;
    document.getElementById("credentialId").value = json.id;
    if (json.response.userHandle) {
        document.getElementById("userHandle").value = json.response.userHandle;
    }
    document.getElementById("webauth").requestSubmit();
}

export function returnFailure(error) {
    document.getElementById("error").value = error;
    document.getElementById("webauth").requestSubmit();
}
