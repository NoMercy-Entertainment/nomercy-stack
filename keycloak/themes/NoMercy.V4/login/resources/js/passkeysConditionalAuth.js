// Conditional-UI passkey autofill: surfaces a discoverable passkey in the email
// field's autocomplete when the browser supports it. Native WebAuthn JSON API,
// no external dependency. The explicit grey button (webauthnAuthenticate.js) is
// the fallback for browsers without conditional mediation.
import { returnSuccess } from "./webauthnAuthenticate.js";

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
        const credential = await navigator.credentials.get({ publicKey, mediation: "conditional" });
        returnSuccess(credential);
    } catch {
        // conditional UI is best-effort — the user can still use the button or another method
    }
}
