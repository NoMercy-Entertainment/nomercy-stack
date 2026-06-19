// Conditional-mediation passkey autofill for the username screen. Surfaces
// discoverable passkeys in the browser's autofill UI without a button press.
// Shares doAuthenticate / the AbortController with webauthnAuthenticate.js, so
// clicking the explicit passkey button cleanly aborts this background request.

import { doAuthenticate, returnSuccess } from "./webauthnAuthenticate.js";

export async function initAuthenticate(input) {
    if (!window.PublicKeyCredential || typeof PublicKeyCredential.isConditionalMediationAvailable === "undefined") {
        return;
    }
    if (input.isUserIdentified) {
        return;
    }
    if (!(await PublicKeyCredential.isConditionalMediationAvailable())) {
        return;
    }
    try {
        const credential = await doAuthenticate({ ...input, additionalOptions: { mediation: "conditional" } });
        returnSuccess(credential);
    } catch (error) {
        // Fail silently — conditional UI is best-effort and is routinely
        // aborted when the user picks the explicit button or another method.
    }
}
