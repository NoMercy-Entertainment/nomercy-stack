// Passkey sign-in ceremony using the native WebAuthn JSON serialization
// (PublicKeyCredential.parseRequestOptionsFromJSON / credential.toJSON).
// Requires a secure context, which we always have — the login is served over HTTPS.
// Keycloak hands us base64url strings and expects base64url back, exactly what the
// native JSON helpers produce, so there is no manual encoding to do.

export async function authenticateByWebAuthn(input) {
    if (!window.PublicKeyCredential) {
        returnFailure(input.errmsg);
        return;
    }
    try {
        const options = { challenge: input.challenge, rpId: input.rpId };
        if (input.createTimeout !== 0) options.timeout = input.createTimeout * 1000;
        if (input.userVerification !== "not specified") options.userVerification = input.userVerification;

        const allowCredentials = input.isUserIdentified ? collectAllowCredentials() : [];
        if (allowCredentials.length) options.allowCredentials = allowCredentials;

        const publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(options);
        const credential = await navigator.credentials.get({ publicKey });
        returnSuccess(credential);
    } catch (error) {
        returnFailure(error);
    }
}

function collectAllowCredentials() {
    const form = document.forms["authn_select"];
    if (!form || form.authn_use_chk === undefined) return [];
    const fields = form.authn_use_chk.length === undefined ? [form.authn_use_chk] : [...form.authn_use_chk];
    return fields.map((field) => ({ id: field.value, type: "public-key" }));
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
