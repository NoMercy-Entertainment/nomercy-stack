// Conditional-UI passkey autofill: surfaces a discoverable passkey in the email
// field's autocomplete when the browser supports it. Native WebAuthn JSON API,
// no external dependency. The explicit grey button (webauthnAuthenticate.js) is
// the fallback, and aborts this pending request before its own ceremony.
import { returnSuccess, conditional } from "./webauthnAuthenticate.js";

export async function initAuthenticate(input) {
    if (!window.PublicKeyCredential) return;

    const conditionalAvailable = typeof PublicKeyCredential.isConditionalMediationAvailable === "function"
        && await PublicKeyCredential.isConditionalMediationAvailable();
    if (input.isUserIdentified || !conditionalAvailable) return;

    try {
        const options = { challenge: input.challenge, rpId: input.rpId };
        if (input.createTimeout !== 0) options.timeout = input.createTimeout * 1000;
        if (input.userVerification !== "not specified") options.userVerification = input.userVerification;

        const publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(options);
        conditional.controller = new AbortController();
        const credential = await navigator.credentials.get({
            publicKey,
            mediation: "conditional",
            signal: conditional.controller.signal,
        });
        returnSuccess(credential);
    } catch {
        // aborted by the button, or no discoverable passkey — best-effort either way
    }
}
